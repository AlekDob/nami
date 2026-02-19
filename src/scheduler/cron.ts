import { resolve } from 'path';
import { readFile, writeFile, mkdir } from 'fs/promises';
import type { Job, JobStore } from './types.js';

export type NotifyCallback = (job: Job, message: string) => void;

const MIN_INTERVAL_MS = 60_000; // 1 minute minimum

export class Scheduler {
  private jobs: Job[] = [];
  private timers: Map<string, ReturnType<typeof setTimeout>> = new Map();
  private running: Set<string> = new Set();
  private jobsPath: string;
  private onTrigger: (job: Job) => Promise<void>;
  onNotify: NotifyCallback | null = null;

  constructor(
    dataDir: string,
    onTrigger: (job: Job) => Promise<void>,
  ) {
    this.jobsPath = resolve(dataDir, 'jobs', 'jobs.json');
    this.onTrigger = onTrigger;
  }

  async init(): Promise<void> {
    await mkdir(resolve(this.jobsPath, '..'), { recursive: true });
    await this.loadJobs();
    this.startAll();
  }

  async addJob(job: Omit<Job, 'id'>): Promise<Job> {
    const id = crypto.randomUUID().slice(0, 8);
    const newJob: Job = { ...job, id };
    this.jobs.push(newJob);
    await this.saveJobs();
    this.scheduleJob(newJob);
    return newJob;
  }

  async removeJob(id: string): Promise<boolean> {
    const idx = this.jobs.findIndex(j => j.id === id);
    if (idx === -1) return false;
    this.stopJob(id);
    this.jobs.splice(idx, 1);
    await this.saveJobs();
    return true;
  }

  async updateAndEnable(
    id: string,
    updates: Partial<Pick<Job, 'cron' | 'task' | 'repeat' | 'name'>>,
  ): Promise<Job | null> {
    const job = this.jobs.find(j => j.id === id);
    if (!job) return null;
    if (updates.cron !== undefined) job.cron = updates.cron;
    if (updates.task !== undefined) job.task = updates.task;
    if (updates.repeat !== undefined) job.repeat = updates.repeat;
    if (updates.name !== undefined) job.name = updates.name;
    job.enabled = true;
    this.scheduleJob(job);
    await this.saveJobs();
    return job;
  }

  async toggleJob(id: string): Promise<Job | null> {
    const job = this.jobs.find(j => j.id === id);
    if (!job) return null;
    job.enabled = !job.enabled;
    if (job.enabled) {
      this.scheduleJob(job);
    } else {
      this.stopJob(id);
    }
    await this.saveJobs();
    return job;
  }

  listJobs(userId?: string): Job[] {
    if (userId) return this.jobs.filter(j => j.userId === userId);
    return [...this.jobs];
  }

  stopAll(): void {
    for (const [id] of this.timers) {
      this.stopJob(id);
    }
  }

  private startAll(): void {
    for (const job of this.jobs) {
      if (job.enabled) this.scheduleJob(job);
    }
  }

  private scheduleJob(job: Job): void {
    if (this.timers.has(job.id)) this.stopJob(job.id);
    this.scheduleNext(job);
  }

  private scheduleNext(job: Job): void {
    const ms = this.msUntilNext(job.cron);
    if (ms === null || !Number.isFinite(ms) || ms < 0) return;

    const safeMs = Math.max(ms, MIN_INTERVAL_MS);

    const timer = setTimeout(async () => {
      if (this.running.has(job.id)) return;
      this.running.add(job.id);

      try {
        job.lastRun = new Date().toISOString();
        await this.saveJobs();

        if (this.onNotify && job.notify) {
          this.onNotify(job, job.task);
        }

        await this.onTrigger(job);
      } finally {
        this.running.delete(job.id);
      }

      if (job.repeat && job.enabled) {
        this.scheduleNext(job);
      } else if (!job.repeat) {
        job.enabled = false;
        await this.saveJobs();
      }
    }, safeMs);

    this.timers.set(job.id, timer);
  }

  private stopJob(id: string): void {
    const timer = this.timers.get(id);
    if (timer) {
      clearTimeout(timer);
      this.timers.delete(id);
    }
  }

  /**
   * Parse a cron field into a sorted array of valid values.
   * Supports: *, N, N-M (range), N,M,O (list), *​/N (step).
   */
  private parseField(
    field: string,
    min: number,
    max: number,
  ): number[] | null {
    if (field === '*') return null; // null = wildcard (all values)

    const values = new Set<number>();

    for (const part of field.split(',')) {
      const stepMatch = part.match(/^(?:(\d+)-(\d+)|\*)\/(\d+)$/);
      const rangeMatch = part.match(/^(\d+)-(\d+)$/);

      if (stepMatch && stepMatch[3]) {
        const step = parseInt(stepMatch[3], 10);
        const start = stepMatch[1] ? parseInt(stepMatch[1], 10) : min;
        const end = stepMatch[2] ? parseInt(stepMatch[2], 10) : max;
        if (!step || step <= 0) return null;
        for (let i = start; i <= end; i += step) values.add(i);
      } else if (rangeMatch) {
        const start = parseInt(rangeMatch[1], 10);
        const end = parseInt(rangeMatch[2], 10);
        if (isNaN(start) || isNaN(end)) return null;
        for (let i = start; i <= end; i++) values.add(i);
      } else {
        const n = parseInt(part, 10);
        if (isNaN(n)) return null;
        values.add(n);
      }
    }

    return [...values].sort((a, b) => a - b);
  }

  /** Calculate ms until next cron trigger */
  msUntilNext(cron: string): number | null {
    const presets: Record<string, number> = {
      '@hourly': 3_600_000,
      '@daily': 86_400_000,
      '@weekly': 604_800_000,
    };
    if (presets[cron]) return presets[cron];

    const parts = cron.split(' ');
    if (parts.length !== 5) return null;
    const [minStr, hourStr, , , dayOfWeekStr] = parts;

    const minutes = this.parseField(minStr, 0, 59);
    const hours = this.parseField(hourStr, 0, 23);
    const daysOfWeek = this.parseField(dayOfWeekStr, 0, 6);

    const now = new Date();
    const curMin = now.getMinutes();
    const curHour = now.getHours();
    const curDow = now.getDay();

    // Find next matching minute >= current context
    const nextMin = (validMins: number[], afterMin: number) =>
      validMins.find(m => m > afterMin) ?? null;

    // Search up to 8 days ahead to find the next valid trigger
    for (let dayOffset = 0; dayOffset <= 7; dayOffset++) {
      const candidate = new Date(now);
      candidate.setDate(candidate.getDate() + dayOffset);
      candidate.setSeconds(0, 0);

      const dow = (curDow + dayOffset) % 7;
      if (daysOfWeek && !daysOfWeek.includes(dow)) continue;

      const validHours = hours ?? Array.from({ length: 24 }, (_, i) => i);
      const validMins = minutes ?? Array.from({ length: 60 }, (_, i) => i);

      for (const h of validHours) {
        if (dayOffset === 0 && h < curHour) continue;
        if (dayOffset === 0 && h === curHour) {
          const m = nextMin(validMins, curMin);
          if (m !== null) {
            candidate.setHours(h, m, 0, 0);
            return Math.max(
              candidate.getTime() - now.getTime(),
              MIN_INTERVAL_MS,
            );
          }
          continue;
        }
        // First valid minute in this hour
        candidate.setHours(h, validMins[0], 0, 0);
        return Math.max(
          candidate.getTime() - now.getTime(),
          MIN_INTERVAL_MS,
        );
      }
    }

    return null;
  }

  private async loadJobs(): Promise<void> {
    try {
      const raw = await readFile(this.jobsPath, 'utf-8');
      const store: JobStore = JSON.parse(raw);
      this.jobs = store.jobs;
    } catch {
      this.jobs = [];
    }
  }

  private async saveJobs(): Promise<void> {
    const store: JobStore = { jobs: this.jobs, version: 1 };
    await writeFile(
      this.jobsPath,
      JSON.stringify(store, null, 2),
      'utf-8',
    );
  }
}
