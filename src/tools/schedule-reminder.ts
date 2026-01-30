import { tool } from 'ai';
import { z } from 'zod';
import type { Scheduler } from '../scheduler/cron.js';

function parseToCron(time: string): string | null {
  const clockMatch = time.match(/^(\d{1,2}):(\d{2})$/);
  if (clockMatch) {
    const h = parseInt(clockMatch[1], 10);
    const m = parseInt(clockMatch[2], 10);
    if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
      return m + ' ' + h + ' * * *';
    }
  }

  const relMatch = time.match(/^in\s+(\d+)\s*(m|min|h|hr|hour)s?$/i);
  if (relMatch) {
    const val = parseInt(relMatch[1], 10);
    const unit = relMatch[2].toLowerCase();
    const mins = unit.startsWith('h') ? val * 60 : val;
    const target = new Date(Date.now() + mins * 60_000);
    return target.getMinutes() + ' ' + target.getHours() + ' * * *';
  }

  if (time.split(' ').length === 5) return time;
  return null;
}

function describeNext(cron: string, scheduler: Scheduler): string {
  const ms = scheduler.msUntilNext(cron);
  if (!ms) return 'unknown';
  const mins = Math.round(ms / 60_000);
  if (mins < 60) return 'in ' + mins + ' minutes';
  const hrs = Math.floor(mins / 60);
  const remainMins = mins % 60;
  if (hrs < 24) {
    return remainMins > 0
      ? 'in ' + hrs + 'h ' + remainMins + 'm'
      : 'in ' + hrs + ' hours';
  }
  return 'in ' + Math.floor(hrs / 24) + ' days';
}

export function createScheduleTask(scheduler: Scheduler) {
  return tool({
    description:
      'Schedule a task to run at a specific time. Can be a simple reminder ' +
      '(just notify the user) OR an autonomous action (fetch a website, ' +
      'check email, search X/Twitter, run any tool). When the task fires, ' +
      'the agent executes the task description using all available tools.',
    inputSchema: z.object({
      task: z
        .string()
        .describe(
          'What to do when the job fires. For reminders: "Remind user to buy milk". ' +
          'For actions: "Fetch ansa.it and summarize the top news", ' +
          '"Check email inbox for unread messages", ' +
          '"Search X for mentions of @username"',
        ),
      time: z
        .string()
        .describe(
          'When to trigger. Formats: "17:00" (at 5pm), ' +
          '"in 30m" (30 minutes from now), "in 2h", ' +
          'or cron "0 9 * * 1" (Mondays 9am)',
        ),
      repeat: z
        .boolean()
        .default(false)
        .describe('If true, repeats on schedule. If false, fires once'),
      name: z
        .string()
        .optional()
        .describe('Short label for this task'),
    }),
    execute: async ({ task, time, repeat, name }) => {
      const cron = parseToCron(time);
      if (!cron) {
        return {
          success: false,
          error: 'Cannot parse time "' + time + '". Use "HH:MM", "in Xm", "in Xh", or cron format.',
        };
      }

      const job = await scheduler.addJob({
        name: name || task.slice(0, 40),
        cron,
        task,
        userId: 'default',
        enabled: true,
        notify: true,
        repeat,
      });

      const next = describeNext(cron, scheduler);

      return {
        success: true,
        jobId: job.id,
        message: 'Task scheduled: "' + task + '"',
        nextTrigger: next,
        repeats: repeat,
      };
    },
  });
}

export function createListTasks(scheduler: Scheduler) {
  return tool({
    description: 'List all scheduled tasks (reminders and actions)',
    inputSchema: z.object({}),
    execute: async () => {
      const jobs = scheduler.listJobs();
      if (jobs.length === 0) {
        return { jobs: [], message: 'No scheduled tasks' };
      }
      return {
        jobs: jobs.map(j => ({
          id: j.id,
          name: j.name,
          task: j.task,
          cron: j.cron,
          enabled: j.enabled,
          repeat: j.repeat ?? false,
          lastRun: j.lastRun ?? 'never',
        })),
      };
    },
  });
}

export function createCancelTask(scheduler: Scheduler) {
  return tool({
    description: 'Cancel/remove a scheduled task by its ID',
    inputSchema: z.object({
      jobId: z.string().describe('The job ID to cancel'),
    }),
    execute: async ({ jobId }) => {
      const removed = await scheduler.removeJob(jobId);
      return removed
        ? { success: true, message: 'Task ' + jobId + ' cancelled' }
        : { success: false, error: 'No task found with ID ' + jobId };
    },
  });
}
