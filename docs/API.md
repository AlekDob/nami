# API Reference

## Agent Class

```ts
import { Agent } from './agent/agent';

const agent = new Agent(config);
```

### Constructor

```ts
constructor(config: AgentConfig)
```

### AgentConfig

```ts
interface AgentConfig {
  openaiApiKey?: string;
  anthropicApiKey?: string;
  modelName?: string;
  modelEndpoint?: string;
  useOpenRouter?: boolean;
  provider?: "openrouter" | "moonshot" | "together";
}
```

### Methods

#### run(input: string): Promise<string>

Execute a prompt with tool-use enabled. The agent may call
multiple tools before returning the final response.

```ts
const response = await agent.run('Summarize my latest emails');
```

#### getApiKey(): string | undefined

Returns the correct API key based on the configured provider.

#### getModel(): LanguageModel

Returns the AI SDK model instance. Uses `.chat()` for
non-OpenAI providers to force Chat Completions endpoint.

## Tool Definition Pattern

Each tool follows this pattern:

```ts
import { z } from 'zod';
import { tool } from 'ai';

export const webFetch = tool({
  description: 'Fetch and read content from a URL',
  parameters: z.object({
    url: z.string().url(),
    prompt: z.string().optional(),
  }),
  execute: async ({ url, prompt }) => {
    const response = await fetch(url);
    const text = await response.text();
    return { content: text.slice(0, 10000) };
  },
});
```

## Memory Store

```ts
import { MemoryStore } from './memory/store';

const memory = new MemoryStore('data/memory');

// Read
const context = await memory.getContext();
const learnings = await memory.getLearnings();

// Write
await memory.saveEntry({
  type: 'learning',
  content: 'User prefers Italian responses',
  tags: ['preferences'],
});

// Search
const results = await memory.search('email workflow');
```

## Skill Loader

```ts
import { loadSkills } from './skills/loader';

const skills = await loadSkills('data/skills');
// Returns array of { name, systemPrompt, requiredTools }
```

## Scheduler

```ts
import { Scheduler } from './scheduler/cron';

const scheduler = new Scheduler(agent);
scheduler.add({
  name: 'email-digest',
  cron: '0 8 * * *',
  task: 'Read my unread emails and create a summary',
});
scheduler.start();
```

## Runtime Utilities

```ts
import { detectRuntime, isBun, getPlatform } from './utils/runtime';

const runtime = detectRuntime(); // 'bun' | 'node'
const platform = getPlatform();
// { os: 'linux', arch: 'x64', runtime: 'bun' }
```

## Config Loader

```ts
import { loadConfig } from './config';

const config = await loadConfig();
// { agent: AgentConfig, discord?: DiscordConfig, scheduler?: SchedulerConfig }
```
