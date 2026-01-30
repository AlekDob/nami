import type { Config } from "./types.js";

export async function loadConfig(): Promise<Config> {
  const discordToken = process.env.DISCORD_TOKEN;
  const discordClientId = process.env.DISCORD_CLIENT_ID;
  
  return {
    agent: {
      openaiApiKey: process.env.OPENAI_API_KEY,
      anthropicApiKey: process.env.ANTHROPIC_API_KEY,
      modelName: process.env.MODEL_NAME || "openai/gpt-4o",
      modelEndpoint: process.env.MODEL_ENDPOINT,
      useOpenRouter: process.env.USE_OPENROUTER === "true",
      provider: process.env.PROVIDER as "openrouter" | "moonshot" | "together" | undefined,
    },
    discord: discordToken && discordClientId ? {
      token: discordToken,
      clientId: discordClientId,
      guildId: process.env.DISCORD_GUILD_ID,
    } : undefined,
    scheduler: {
      dataDir: process.env.DATA_DIR || "./data",
      persistFile: process.env.SCHEDULER_PERSIST || "./data/jobs.json",
    },
  };
}
