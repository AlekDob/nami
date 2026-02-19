import { detectRuntime, getPlatform, isBun } from '../utils/runtime.js';
import { Agent } from '../agent/agent.js';
import { loadConfig } from '../config/index.js';
import type { ModelMessage } from 'ai';
import { Scheduler } from '../scheduler/cron.js';
import { startDiscordBot, sendDiscordNotification } from '../channels/discord.js';
import { initAPNs, sendPushNotification } from '../channels/apns.js';
import { startApiServer } from '../api/server.js';
import { broadcastNotification } from '../api/websocket.js';
import { isApiEnabled } from '../api/auth.js';
import { SessionStore } from '../sessions/store.js';

async function isPortInUse(port: number): Promise<boolean> {
  try {
    const res = await fetch(`http://localhost:${port}/api/health`);
    return res.ok;
  } catch {
    return false;
  }
}
import {
  printSplash, printInfoBar, printInputBox, printInputBoxClose,
  printToolUse, startThinking, stopThinking,
  printBotMsg, printResponseEnd, printStats, c, PROMPT,
} from './ui.js';
import { handleCommand } from './commands.js';
import { existsSync, readFileSync } from 'fs';
import { pasteImageFromClipboard } from './clipboard.js';

function printJobOutput(name: string, result: string): void {
  console.log('');
  console.log('  ' + c.yellow + c.bold + '=^.^= SCHEDULED TASK: ' + name + c.reset);
  console.log('');
  printBotMsg(result);
  console.log('');
  process.stdout.write(PROMPT);
}

const IMG_EXTS = /\.(png|jpg|jpeg|gif|webp|bmp)$/i;
const IMG_URL = /^https?:\/\/.+\.(png|jpg|jpeg|gif|webp)(\?.*)?$/i;

function imageToBase64(filePath: string): string {
  const buf = readFileSync(filePath);
  const ext = filePath.split('.').pop()?.toLowerCase() || 'png';
  const mime = ext === 'jpg' ? 'jpeg' : ext;
  return `data:image/${mime};base64,${buf.toString('base64')}`;
}

function parseImageInput(
  msg: string,
  pastedImages: string[] = [],
): ModelMessage {
  const words = msg.split(/\s+/);
  const textParts: string[] = [];
  const images: Array<{ type: 'image'; image: URL | string }> = [];

  for (const word of words) {
    if (IMG_URL.test(word)) {
      images.push({ type: 'image', image: new URL(word) });
    } else if (IMG_EXTS.test(word) && existsSync(word)) {
      images.push({ type: 'image', image: imageToBase64(word) });
      textParts.push(`[attached: ${word.split('/').pop()}]`);
    } else {
      textParts.push(word);
    }
  }

  // Add clipboard-pasted images
  for (const imgPath of pastedImages) {
    if (existsSync(imgPath)) {
      images.push({ type: 'image', image: imageToBase64(imgPath) });
    }
  }

  if (images.length === 0) {
    return { role: 'user', content: msg };
  }

  const parts: Array<
    | { type: 'text'; text: string }
    | { type: 'image'; image: URL | string }
  > = [];
  const text = textParts.join(' ').trim();
  if (text) parts.push({ type: 'text', text });
  parts.push(...images);
  return { role: 'user', content: parts };
}

async function processMessage(
  agent: Agent,
  msg: string,
  history: ModelMessage[],
  pastedImages: string[] = [],
) {
  printInputBoxClose();
  console.log('');
  console.log('');
  const userMsg = parseImageInput(msg, pastedImages);

  // Strip images if model lacks vision support
  const hasImages = pastedImages.length > 0 ||
    (Array.isArray(userMsg.content) && userMsg.content.some(p => p.type === 'image'));
  if (hasImages && !agent.supportsVision()) {
    console.log(`  ${c.yellow}Warning: current model does not support images. Use /model gpt-4o-mini${c.reset}`);
    if (typeof userMsg.content !== 'string' && Array.isArray(userMsg.content)) {
      const texts = userMsg.content
        .filter((p): p is { type: 'text'; text: string } => p.type === 'text')
        .map(p => p.text);
      userMsg.content = texts.join(' ').trim() || msg;
    }
  }

  history.push(userMsg);

  startThinking();
  const response = await agent.run(history);
  stopThinking();

  history.push({ role: 'assistant', content: response });
  printBotMsg(response);
  printResponseEnd();
  if (agent.lastRunStats) {
    printStats(agent.lastRunStats);
  }
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
    '  ' + c.magenta + 'First time? Let us set up your cat!' + c.reset,
  );
  console.log('');
  await processMessage(agent, 'ciao!', history);
}

function showPrompt() {
  printInputBox();
  process.stdout.write(PROMPT);
  // Bottom border drawn after user submits (printInputBoxClose)
}

function printImageTag(id: number): void {
  process.stdout.write(
    `${c.dim}[ ${c.cyan}Image ${id}${c.dim} ]${c.reset} `,
  );
}

async function inputLoop(agent: Agent, history: ModelMessage[]) {
  let line = '';
  let pendingImages: string[] = [];
  let imageIdCounter = 1000;
  let busy = false;

  const submit = async () => {
    const trimmed = line.trim();
    const images = [...pendingImages];
    line = '';
    pendingImages = [];
    if (!trimmed && images.length === 0) return;
    busy = true;
    const handled = await handleCommand(trimmed, agent, history);
    if (!handled) {
      await processMessage(agent, trimmed || 'describe this image', history, images);
    }
    busy = false;
    showPrompt();
  };

  const handlePaste = () => {
    const imgPath = pasteImageFromClipboard();
    if (imgPath) {
      imageIdCounter++;
      pendingImages.push(imgPath);
      printImageTag(imageIdCounter);
      line += `[image:${imageIdCounter}] `;
    }
  };

  const redrawLine = () => {
    process.stdout.write('\r' + PROMPT + line);
    // Clear any trailing chars from previous longer line
    process.stdout.write('\x1b[K');
  };

  if (process.stdin.isTTY) {
    process.stdin.setRawMode(true);
  }
  process.stdin.resume();

  showPrompt();

  process.stdin.setEncoding('utf-8');

  process.stdin.on('data', async (raw: string) => {
    if (busy) return;

    for (let i = 0; i < raw.length; i++) {
      const code = raw.charCodeAt(i);

      // Ctrl+C → exit
      if (code === 0x03) {
        process.stdout.write('\n');
        process.exit(0);
      }

      // Ctrl+V (0x16) → clipboard paste
      if (code === 0x16) {
        handlePaste();
        continue;
      }

      // Enter
      if (code === 0x0d || code === 0x0a) {
        process.stdout.write('\n');
        await submit();
        return;
      }

      // Backspace (0x7f) or Ctrl+H (0x08)
      if (code === 0x7f || code === 0x08) {
        if (line.length > 0) {
          line = line.slice(0, -1);
          process.stdout.write('\b \b');
        }
        continue;
      }

      // Ctrl+U → clear line
      if (code === 0x15) {
        line = '';
        pendingImages = [];
        redrawLine();
        continue;
      }

      // Ctrl+D → exit (on empty line)
      if (code === 0x04) {
        if (line.length === 0) {
          process.stdout.write('\n');
          process.exit(0);
        }
        continue;
      }

      // Escape sequences (arrows, etc) — skip
      if (code === 0x1b) {
        if (i + 1 < raw.length && raw.charCodeAt(i + 1) === 0x5b) {
          i += 2;
        }
        continue;
      }

      // Printable characters
      if (code >= 0x20) {
        const ch = raw[i];
        line += ch;
        process.stdout.write(ch);
      }
    }
  });
}

async function main() {
  const config = await loadConfig();
  const dataDir = config.scheduler?.dataDir || '/root/meow/data';
  const agent = new Agent(config.agent, dataDir);
  await agent.init();

  agent.onToolUse = (toolName: string) => {
    stopThinking();
    printToolUse(toolName);
    startThinking();
  };

  const JOB_PREFIX =
    '[SCHEDULED JOB EXECUTION] You are executing a scheduled task. ' +
    'DO NOT call scheduleTask, listTasks, or cancelTask. ' +
    'Just execute the task directly using your other tools and reply.\n\n';

  const sessions = new SessionStore(dataDir);
  await sessions.init();

  const scheduler = new Scheduler(dataDir, async (job) => {
    const jobMessages: ModelMessage[] = [
      { role: 'user', content: JOB_PREFIX + job.task },
    ];
    const result = await agent.run(jobMessages);
    printJobOutput(job.name, result);
    const discordMsg = `**=^.^= SCHEDULED TASK: ${job.name}**\n\n${result}`;
    await sendDiscordNotification(discordMsg);
    // Persist to session so push tap can deep-link
    const session = await sessions.createSession('job', job.name);
    await sessions.appendMessage(session.id, 'user', job.task);
    await sessions.appendMessage(session.id, 'assistant', result);
    await sendPushNotification('Task: ' + job.name, result.slice(0, 200), session.id);
  });
  scheduler.onNotify = (job) => {
    const alert = `⏰ **Task firing:** ${job.name}\n_${job.task}_`;
    sendDiscordNotification(alert);
    broadcastNotification(job.name, job.task);
    // No push here — only send push when result is ready (onTrigger)
  };
  await scheduler.init();

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


  // Start APNs push notifications
  const apnsKeyPath = process.env.APNS_KEY_PATH;
  if (apnsKeyPath) {
    await initAPNs({
      keyPath: apnsKeyPath,
      keyId: process.env.APNS_KEY_ID || '',
      teamId: process.env.APNS_TEAM_ID || '',
      bundleId: process.env.APNS_BUNDLE_ID || '',
      production: process.env.APNS_PRODUCTION === 'true',
      dataDir,
    });
  }

  // Start REST API + WebSocket server (skip if daemon already running)
  let daemonRunning = false;
  if (isApiEnabled()) {
    const apiPort = parseInt(process.env.API_PORT || "3000", 10);
    daemonRunning = await isPortInUse(apiPort);
    if (daemonRunning) {
      console.log(`  ${c.dim}API server already running on port ${apiPort} (daemon)${c.reset}`);
    } else {
      startApiServer({
        agent,
        scheduler,
        soul: agent.getSoulLoader(),
        port: apiPort,
        dataDir,
      });
    }
  }

  const history: ModelMessage[] = [];

  console.clear?.();
  printSplash();
  printInfoBar(agent.getModelInfo(), Boolean(discordToken), daemonRunning);
  console.log('');

  if (agent.needsOnboarding) {
    await runOnboarding(agent, history);
  }

  await inputLoop(agent, history);
}

main().catch(console.error);
