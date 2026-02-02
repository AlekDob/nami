import type { ModelMessage } from 'ai';
import type { Agent } from '../agent/agent.js';
import { c, printSplash, printInfoBar } from './ui.js';

type CommandHandler = (
  args: string,
  agent: Agent,
  history: ModelMessage[],
) => Promise<boolean>;

const commands: Record<string, CommandHandler> = {
  '/exit': async () => {
    console.log(`\n  ${c.yellow}(=^.^=)${c.reset} Bye bye! Meow~\n`);
    process.exit(0);
  },

  '/clear': async (_args, agent, history) => {
    history.length = 0;
    console.clear?.();
    printSplash();
    printInfoBar(agent.getModelInfo());
    console.log(`  ${c.green}History cleared!${c.reset}\n`);
    return true;
  },

  '/model': async (args, agent) => {
    if (!args) {
      console.log(`\n  ${c.dim}Current:${c.reset} ${c.green}${agent.getModelInfo()}${c.reset}\n`);
      return true;
    }
    const result = agent.setModel(args);
    console.log(`\n  ${c.green}${result}${c.reset}\n`);
    return true;
  },

  '/models': async (_args, agent) => {
    console.log(`\n${agent.listModels()}\n`);
    return true;
  },
};

commands['exit'] = commands['/exit'];
commands['clear'] = commands['/clear'];

export async function handleCommand(
  input: string,
  agent: Agent,
  history: ModelMessage[],
): Promise<boolean> {
  const lower = input.toLowerCase();
  const spaceIdx = lower.indexOf(' ');
  const cmd = spaceIdx === -1 ? lower : lower.substring(0, spaceIdx);
  const args = spaceIdx === -1 ? '' : input.substring(spaceIdx + 1).trim();

  const handler = commands[cmd];
  if (!handler) return false;
  return handler(args, agent, history);
}
