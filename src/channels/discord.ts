import {
  Client,
  GatewayIntentBits,
  Events,
  Partials,
  REST,
  Routes,
  SlashCommandBuilder,
  type ChatInputCommandInteraction,
  type Message,
} from 'discord.js';
import type { ModelMessage } from 'ai';
import type { Agent } from '../agent/agent.js';
import type { Scheduler } from '../scheduler/cron.js';

interface DiscordBotConfig {
  token: string;
  clientId: string;
  agent: Agent;
  scheduler: Scheduler;
}

const commands = [
  new SlashCommandBuilder()
    .setName('ask')
    .setDescription('Send a message to Meow')
    .addStringOption(o =>
      o.setName('message').setDescription('Your message').setRequired(true),
    ),
  new SlashCommandBuilder()
    .setName('new')
    .setDescription('Start a new conversation (clear history)'),
  new SlashCommandBuilder()
    .setName('clear')
    .setDescription('Clear conversation history'),
  new SlashCommandBuilder()
    .setName('status')
    .setDescription('Show agent status'),
  new SlashCommandBuilder()
    .setName('jobs')
    .setDescription('List scheduled jobs'),
  new SlashCommandBuilder()
    .setName('memory')
    .setDescription('Search agent memory')
    .addStringOption(o =>
      o.setName('query').setDescription('Search query').setRequired(true),
    ),
];

/** Per-user conversation history for Discord */
const userHistories = new Map<string, ModelMessage[]>();

function getUserHistory(userId: string): ModelMessage[] {
  if (!userHistories.has(userId)) {
    userHistories.set(userId, []);
  }
  return userHistories.get(userId)!;
}

function clearUserHistory(userId: string): number {
  const history = userHistories.get(userId);
  const count = history?.length ?? 0;
  userHistories.set(userId, []);
  return count;
}

/** Store last DM user ID so we can send notifications */
let lastDmUserId: string | null = null;
let discordClient: Client | null = null;

/** Send a notification to the last DM user via Discord */
export async function sendDiscordNotification(text: string): Promise<boolean> {
  if (!discordClient || !lastDmUserId) return false;
  try {
    const user = await discordClient.users.fetch(lastDmUserId);
    const chunks = splitMessage(text, 2000);
    for (const chunk of chunks) {
      await user.send(chunk);
    }
    return true;
  } catch {
    return false;
  }
}

export async function startDiscordBot(config: DiscordBotConfig): Promise<Client> {
  const { token, clientId, agent, scheduler } = config;

  await registerCommands(token, clientId);

  const client = new Client({
    intents: [
      GatewayIntentBits.Guilds,
      GatewayIntentBits.DirectMessages,
    ],
    partials: [Partials.Channel],
  });
  discordClient = client;

  client.once(Events.ClientReady, () => {
    // Ready — silent (avoids polluting CLI input box)
  });

  client.on(Events.InteractionCreate, async (interaction) => {
    if (!interaction.isChatInputCommand()) return;

    lastDmUserId = interaction.user.id;
    try {
      await handleCommand(interaction, agent, scheduler);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      const reply = { content: `Error: ${msg}`, ephemeral: true };
      if (interaction.replied || interaction.deferred) {
        await interaction.followUp(reply);
      } else {
        await interaction.reply(reply);
      }
    }
  });

  client.on(Events.MessageCreate, async (message: Message) => {
    if (message.author.bot) return;
    if (message.guild) return; // Only handle DMs

    const hasText = message.content.trim().length > 0;
    const hasImages = message.attachments.some(a => isImageType(a.contentType));
    if (!hasText && !hasImages) return;

    lastDmUserId = message.author.id;
    try {
      if ("sendTyping" in message.channel) await message.channel.sendTyping();
      const history = getUserHistory(message.author.id);
      const userMsg = await buildUserMessage(message);

      // Strip images if model doesn't support vision
      let visionWarning = '';
      if (hasImages && !agent.supportsVision()) {
        visionWarning = '\n\n-# ⚠️ Current model does not support images. Use `/model gpt-4o-mini` for vision.';
        // Convert multimodal message to text-only
        if (typeof userMsg.content !== 'string' && Array.isArray(userMsg.content)) {
          const textParts = userMsg.content
            .filter((p): p is { type: 'text'; text: string } => p.type === 'text')
            .map(p => p.text);
          const imgCount = userMsg.content.filter(p => p.type === 'image').length;
          const label = imgCount === 1 ? '1 image attached' : `${imgCount} images attached`;
          userMsg.content = (textParts.join(' ') + ` [${label} — not sent, model lacks vision]`).trim();
        }
      }

      history.push(userMsg);
      const response = await agent.run(history);
      history.push({ role: 'assistant', content: response });
      const footer = formatModelFooter(agent);
      await sendLongMessage(message, response + footer + visionWarning);
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : String(err);
      await message.reply(`Error: ${errMsg}`);
    }
  });

  await client.login(token);
  return client;
}

async function handleCommand(
  interaction: ChatInputCommandInteraction,
  agent: Agent,
  scheduler: Scheduler,
): Promise<void> {
  switch (interaction.commandName) {
    case 'ask':
      await handleAsk(interaction, agent);
      break;
    case 'new':
    case 'clear':
      await handleClear(interaction);
      break;
    case 'status':
      await handleStatus(interaction);
      break;
    case 'jobs':
      await handleJobs(interaction, scheduler);
      break;
    case 'memory':
      await handleMemory(interaction, agent);
      break;
  }
}

async function handleAsk(
  interaction: ChatInputCommandInteraction,
  agent: Agent,
): Promise<void> {
  const message = interaction.options.getString('message', true);
  await interaction.deferReply();

  const history = getUserHistory(interaction.user.id);
  history.push({ role: 'user', content: message });
  const response = await agent.run(history);
  history.push({ role: 'assistant', content: response });

  const footer = formatModelFooter(agent);
  const full = response + footer;
  const trimmed = full.length > 2000
    ? full.slice(0, 1997) + '...'
    : full;
  await interaction.editReply(trimmed);
}

async function handleClear(
  interaction: ChatInputCommandInteraction,
): Promise<void> {
  const count = clearUserHistory(interaction.user.id);
  const msgs = Math.floor(count / 2);
  await interaction.reply(
    `Conversation cleared! (${msgs} message${msgs !== 1 ? 's' : ''} removed)`,
  );
}

async function handleStatus(
  interaction: ChatInputCommandInteraction,
): Promise<void> {
  const uptime = Math.floor(process.uptime());
  const mem = process.memoryUsage();
  const mbUsed = Math.round(mem.heapUsed / 1024 / 1024);

  await interaction.reply([
    '**Meow Status**',
    `Uptime: ${formatUptime(uptime)}`,
    `Memory: ${mbUsed}MB`,
    `Runtime: Bun`,
  ].join('\n'));
}

async function handleJobs(
  interaction: ChatInputCommandInteraction,
  scheduler: Scheduler,
): Promise<void> {
  const jobs = scheduler.listJobs();
  if (jobs.length === 0) {
    await interaction.reply('No scheduled jobs.');
    return;
  }

  const lines = jobs.map(j =>
    `- **${j.name}** (${j.cron}) ${j.enabled ? 'ON' : 'OFF'}`,
  );
  await interaction.reply(`**Jobs (${jobs.length})**\n${lines.join('\n')}`);
}

async function handleMemory(
  interaction: ChatInputCommandInteraction,
  agent: Agent,
): Promise<void> {
  const query = interaction.options.getString('query', true);
  await interaction.deferReply();

  const store = agent.getMemoryStore();
  const results = await store.search(query);

  if (results.length === 0) {
    await interaction.editReply(`No results for "${query}".`);
    return;
  }

  const lines = results.slice(0, 5).map(r =>
    `- **${r.path}** (${r.score.toFixed(2)}): ${r.snippet.slice(0, 100)}`,
  );
  await interaction.editReply(
    `**Memory Search: "${query}"**\n${lines.join('\n')}`,
  );
}

function isImageType(contentType: string | null): boolean {
  if (!contentType) return false;
  return contentType.startsWith('image/');
}

async function buildUserMessage(message: Message): Promise<ModelMessage> {
  const parts: Array<{ type: 'text'; text: string } | { type: 'image'; image: URL }> = [];

  if (message.content.trim()) {
    parts.push({ type: 'text', text: message.content });
  }

  for (const [, attachment] of message.attachments) {
    if (!isImageType(attachment.contentType)) continue;
    parts.push({ type: 'image', image: new URL(attachment.url) });
  }

  if (parts.length === 1 && parts[0].type === 'text') {
    return { role: 'user', content: parts[0].text };
  }

  return { role: 'user', content: parts };
}

function formatModelFooter(agent: Agent): string {
  const stats = agent.lastRunStats;
  if (!stats) return '';
  const dur = (stats.durationMs / 1000).toFixed(1);
  const tok = stats.inputTokens + stats.outputTokens;
  return `\n\n-# ${stats.model} · ${tok} tok · ${dur}s`;
}

async function registerCommands(
  token: string,
  clientId: string,
): Promise<void> {
  const rest = new REST({ version: '10' }).setToken(token);
  const body = commands.map(c => c.toJSON());
  await rest.put(Routes.applicationCommands(clientId), { body });
}

async function sendLongMessage(
  original: Message,
  text: string,
): Promise<void> {
  const chunks = splitMessage(text, 2000);
  for (const chunk of chunks) {
    await original.reply(chunk);
  }
}

function splitMessage(text: string, maxLen: number): string[] {
  if (text.length <= maxLen) return [text];
  const chunks: string[] = [];
  let remaining = text;
  while (remaining.length > 0) {
    if (remaining.length <= maxLen) {
      chunks.push(remaining);
      break;
    }
    let splitAt = remaining.lastIndexOf('\n', maxLen);
    if (splitAt < maxLen / 2) splitAt = maxLen;
    chunks.push(remaining.slice(0, splitAt));
    remaining = remaining.slice(splitAt);
  }
  return chunks;
}

function formatUptime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return `${h}h ${m}m ${s}s`;
}
