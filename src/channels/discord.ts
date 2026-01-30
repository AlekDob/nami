import {
  Client,
  GatewayIntentBits,
  Events,
  REST,
  Routes,
  SlashCommandBuilder,
  type ChatInputCommandInteraction,
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

export async function startDiscordBot(config: DiscordBotConfig): Promise<Client> {
  const { token, clientId, agent, scheduler } = config;

  await registerCommands(token, clientId);

  const client = new Client({
    intents: [GatewayIntentBits.Guilds],
  });

  client.once(Events.ClientReady, (c) => {
    console.log(`Discord bot ready as ${c.user.tag}`);
  });

  client.on(Events.InteractionCreate, async (interaction) => {
    if (!interaction.isChatInputCommand()) return;

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

  const userId = interaction.user.id;
  const messages: ModelMessage[] = [{ role: 'user', content: message }];
  const response = await agent.run(messages);

  const trimmed = response.length > 2000
    ? response.slice(0, 1997) + '...'
    : response;
  await interaction.editReply(trimmed);
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

async function registerCommands(
  token: string,
  clientId: string,
): Promise<void> {
  const rest = new REST({ version: '10' }).setToken(token);
  const body = commands.map(c => c.toJSON());
  await rest.put(Routes.applicationCommands(clientId), { body });
}

function formatUptime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return `${h}h ${m}m ${s}s`;
}
