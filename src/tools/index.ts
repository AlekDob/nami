import { webFetch } from './web-fetch.js';
import { fileRead } from './file-read.js';
import { fileWrite } from './file-write.js';
import { emailRead } from './email-read.js';
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
import {
  planterGetPlan,
  planterGetRecipeCategories,
} from './planter-api.js';
import { planWeeklyMeals } from './meal-planner.js';
import { generateShoppingList } from './shopping-list.js';
import { macFileRead, macExec } from './mac-remote.js';
import { createAppleReminder } from './apple-reminder.js';
import { createLocalCommand, createAICommand } from './local-command.js';
import {
  redditFeed,
  redditSubreddit,
  redditSearch,
  redditUser,
  redditPostComments,
} from './reddit-json.js';
import {
  redditPost,
  redditComment,
  redditMessages,
} from './reddit-browser.js';
import type { MemoryStore } from '../memory/store.js';
import type { Scheduler } from '../scheduler/cron.js';

export const coreTools = {
  webFetch,
  fileRead,
  fileWrite,
  emailRead,
  xBrowseTimeline,
  xBrowseProfile,
  xBrowseSearch,
  xBrowseNotifications,
  xBrowsePost,
  xBrowseReply,
  planterGetPlan,
  planterGetRecipeCategories,
  planWeeklyMeals,
  generateShoppingList,
  redditFeed,
  redditSubreddit,
  redditSearch,
  redditUser,
  redditPostComments,
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

  if (process.env.MAC_AGENT_URL && process.env.MAC_AGENT_TOKEN) {
    tools.macFileRead = macFileRead;
    tools.macExec = macExec;
    tools.createAppleReminder = createAppleReminder;
  }

  // Command creation tools (always available)
  tools.createLocalCommand = createLocalCommand;
  tools.createAICommand = createAICommand;

  if (process.env.REDDIT_USERNAME && process.env.REDDIT_PASSWORD) {
    tools.redditPost = redditPost;
    tools.redditComment = redditComment;
    tools.redditMessages = redditMessages;
  }

  return tools;
}
