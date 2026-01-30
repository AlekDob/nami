export interface AgentConfig {
  openaiApiKey?: string;
  anthropicApiKey?: string;
  modelName?: string;
  modelEndpoint?: string;
  useOpenRouter?: boolean;
  provider?: "openrouter" | "moonshot" | "together";
}

export interface DiscordConfig {
  token: string;
  clientId: string;
  guildId?: string;
}

export interface SchedulerConfig {
  dataDir?: string;
  persistFile?: string;
}

export interface Config {
  agent: AgentConfig;
  discord?: DiscordConfig;
  scheduler?: SchedulerConfig;
}
