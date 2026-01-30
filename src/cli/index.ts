import { detectRuntime, getPlatform, isBun } from '../utils/runtime.js';
import { Agent } from '../agent/agent.js';
import { loadConfig } from '../config/index.js';
import type { ModelMessage } from 'ai';
import { Scheduler } from '../scheduler/cron.js';
import { startDiscordBot } from '../channels/discord.js';
import {
  animateCat, printHeader, printToolUse,
  startThinking, stopThinking,
  printBotMsg, c, PROMPT,
} from './ui.js';
import { handleCommand } from './commands.js';

function printJobOutput(name: string, result: string): void {
  console.log('');
  console.log('  ' + c.yellow + c.bold + '=^.^= SCHEDULED TASK: ' + name + c.reset);
  console.log('');
  printBotMsg(result);
  console.log('');
  process.stdout.write(PROMPT);
}

async function processMessage(
  agent: Agent,
  msg: string,
  history: ModelMessage[],
) {
  console.log('');
  history.push({ role: 'user', content: msg });

  startThinking();
  const response = await agent.run(history);
  stopThinking();

  history.push({ role: 'assistant', content: response });
  printBotMsg(response);
  console.log('');

  if (agent.needsOnboarding) {
    agent.completeOnboarding();
  }
}

async function runOnboarding(
  agent: Agent,
  history: ModelMessage[],
) {
  console.log(
    '\n  ' + c.magenta + 'First time? Let us set up your cat!' + c.reset + '\n',
  );
  await processMessage(agent, 'ciao!', history);
}

async function inputLoop(agent: Agent, history: ModelMessage[]) {
  const onLine = async (trimmed: string) => {
    if (!trimmed) return;
    const handled = await handleCommand(trimmed, agent, history);
    if (!handled) await processMessage(agent, trimmed, history);
  };

  if (isBun()) {
    process.stdout.write(PROMPT);
    for await (const line of console) {
      await onLine(line.trim());
      process.stdout.write(PROMPT);
    }
  } else {
    const readline = await import('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });
    rl.setPrompt(PROMPT);
    rl.prompt();
    rl.on('line', async (answer: string) => {
      await onLine(answer.trim());
      rl.prompt();
    });
  }
}

async function main() {
  const config = await loadConfig();
  const dataDir = config.scheduler?.dataDir || './data';
  const agent = new Agent(config.agent, dataDir);
  await agent.init();

  agent.onToolUse = (toolName: string) => {
    stopThinking();
    printToolUse(toolName);
    startThinking();
  };

  const scheduler = new Scheduler(dataDir, async (job) => {
    // Run agent with full tools — task is treated as a user message
    const jobMessages: ModelMessage[] = [
      { role: 'user', content: job.task },
    ];
    const result = await agent.run(jobMessages);
    printJobOutput(job.name, result);
  });
  await scheduler.init();

  // Give agent access to scheduler tools
  agent.attachScheduler(scheduler);

  const discordToken = process.env.DISCORD_TOKEN;
  const discordClientId = process.env.DISCORD_CLIENT_ID;
  if (discordToken && discordClientId) {
    await startDiscordBot({
      token: discordToken,
      clientId: discordClientId,
      agent,
      scheduler,
    });
  }

  const runtime = detectRuntime();
  const platform = getPlatform();
  const history: ModelMessage[] = [];

  console.clear?.();
  await animateCat();
  console.log('');
  printHeader(
    agent.getModelInfo(),
    runtime,
    runtime + '/' + platform.arch,
  );

  if (discordToken) {
    console.log(
      '  ' + c.magenta + 'Discord bot' + c.reset + ' connected!\n',
    );
  }

  if (agent.needsOnboarding) {
    await runOnboarding(agent, history);
  } else {
    console.log(
      '  ' + c.green + 'Agent ready!' + c.reset + ' Type /models to see available models.\n',
    );
  }

  await inputLoop(agent, history);
}

main().catch(console.error);
