import { resolve } from 'path';
import { readFile, writeFile, mkdir } from 'fs/promises';
import type { Job, JobStore } from './types.js';

export type NotifyCallback = (job: Job, message: string) => void;

export class Scheduler {
  private jobs: Job[] = [];
  private timers: Map<string, ReturnType<typeof setTimeout>> = new Map();
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
    if (ms === null) return;

    const timer = setTimeout(async () => {
      job.lastRun = new Date().toISOString();
      await this.saveJobs();

      if (this.onNotify && job.notify) {
        this.onNotify(job, job.task);
      }

      await this.onTrigger(job);

      if (job.repeat) {
        this.scheduleNext(job);
      } else {
        job.enabled = false;
        await this.saveJobs();
      }
    }, ms);

    this.timers.set(job.id, timer);
  }

  private stopJob(id: string): void {
    const timer = this.timers.get(id);
    if (timer) {
      clearTimeout(timer);
      this.timers.delete(id);
    }
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

    const now = new Date();
    const target = new Date(now);

    if (hourStr !== '*' && minStr !== '*') {
      target.setHours(parseInt(hourStr, 10));
      target.setMinutes(parseInt(minStr, 10));
      target.setSeconds(0);
      target.setMilliseconds(0);

      if (dayOfWeekStr !== '*') {
        const targetDay = parseInt(dayOfWeekStr, 10);
        const currentDay = target.getDay();
        let daysAhead = targetDay - currentDay;
        if (daysAhead < 0) daysAhead += 7;
        if (daysAhead === 0 && target <= now) daysAhead = 7;
        target.setDate(target.getDate() + daysAhead);
      } else if (target <= now) {
        target.setDate(target.getDate() + 1);
      }

      return target.getTime() - now.getTime();
    }

    if (minStr !== '*') {
      const targetMin = parseInt(minStr, 10);
      target.setMinutes(targetMin);
      target.setSeconds(0);
      if (target <= now) target.setHours(target.getHours() + 1);
      return target.getTime() - now.getTime();
    }

    return 3_600_000;
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
