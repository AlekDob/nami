import { webFetch } from './web-fetch.js';
import { fileRead } from './file-read.js';
import { fileWrite } from './file-write.js';
import { emailRead } from './email-read.js';
import { xGetTimeline, xSearchTweets, xGetMentions } from './x-api.js';
import {
  xBrowseTimeline,
  xBrowseProfile,
  xBrowseSearch,
  xBrowseNotifications,
  xBrowsePost,
  xBrowseReply,
} from './x-browser.js';
import { createMemorySearch } from './memory-search.js';
import { createMemoryGet } from './memory-get.js';
import {
  createScheduleTask,
  createListTasks,
  createCancelTask,
} from './schedule-reminder.js';
import type { MemoryStore } from '../memory/store.js';
import type { Scheduler } from '../scheduler/cron.js';

export const coreTools = {
  webFetch,
  fileRead,
  fileWrite,
  emailRead,
  xGetTimeline,
  xSearchTweets,
  xGetMentions,
  xBrowseTimeline,
  xBrowseProfile,
  xBrowseSearch,
  xBrowseNotifications,
  xBrowsePost,
  xBrowseReply,
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyTool = any;

export function buildTools(memory: MemoryStore, scheduler?: Scheduler) {
  const tools: Record<string, AnyTool> = {
    ...coreTools,
    memorySearch: createMemorySearch(memory),
    memoryGet: createMemoryGet(memory),
  };

  if (scheduler) {
    tools.scheduleTask = createScheduleTask(scheduler);
    tools.listTasks = createListTasks(scheduler);
    tools.cancelTask = createCancelTask(scheduler);
  }

  return tools;
}
