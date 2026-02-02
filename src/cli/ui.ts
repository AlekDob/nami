export const c = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  cyan: '\x1b[36m',
  yellow: '\x1b[33m',
  green: '\x1b[32m',
  magenta: '\x1b[35m',
  white: '\x1b[37m',
  gray: '\x1b[90m',
};

/* ── Terminal width helper ─────────────────────────────── */

function cols(): number {
  return process.stdout.columns || 80;
}

/* ── Big ASCII splash ──────────────────────────────────── */

const LOGO = [
  ' ███╗   ███╗███████╗ ██████╗ ██╗    ██╗',
  ' ████╗ ████║██╔════╝██╔═══██╗██║    ██║',
  ' ██╔████╔██║█████╗  ██║   ██║██║ █╗ ██║',
  ' ██║╚██╔╝██║██╔══╝  ██║   ██║██║███╗██║',
  ' ██║ ╚═╝ ██║███████╗╚██████╔╝╚███╔███╔╝',
  ' ╚═╝     ╚═╝╚══════╝ ╚═════╝  ╚══╝╚══╝ ',
];

const CAT_SIDE = [
  '   /\\_/\\  ',
  '  ( ^.^ ) ',
  '   > ^ <  ',
  '  /|   |\\ ',
  ' (_)   (_)',
  '           ',
];

export function printSplash() {
  console.log('');
  const w = cols();
  for (let i = 0; i < LOGO.length; i++) {
    const cat = CAT_SIDE[i] || '';
    const row = LOGO[i] + '  ' + cat;
    const pad = Math.max(0, Math.floor((w - row.length) / 2));
    console.log(' '.repeat(pad) + c.cyan + LOGO[i] + c.reset + c.yellow + '  ' + (CAT_SIDE[i] || '') + c.reset);
  }
  const tagline = 'AI Personal Assistant';
  const tagPad = Math.max(0, Math.floor((w - tagline.length) / 2));
  console.log('');
  console.log(' '.repeat(tagPad) + c.dim + tagline + c.reset);
  console.log('');
}

/* ── Info bar ──────────────────────────────────────────── */

const strip = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '');

export function printInfoBar(model: string, discord = false) {
  const w = cols();
  const left = ` ${c.green}${model}${c.reset}`
    + (discord ? `  ${c.magenta}Discord${c.reset}` : '');
  const right = `${c.dim}/models · /clear · /exit${c.reset} `;
  const gap = Math.max(1, w - strip(left).length - strip(right).length);
  console.log(left + ' '.repeat(gap) + right);
  console.log(c.dim + '─'.repeat(w) + c.reset);
}

/* ── Input box ─────────────────────────────────────────── */

export function printInputBox() {
  const w = cols();
  console.log(c.dim + '┌' + '─'.repeat(w - 2) + '┐' + c.reset);
}

export function printInputBoxClose() {
  const w = cols();
  console.log(c.dim + '└' + '─'.repeat(w - 2) + '┘' + c.reset);
}

export const PROMPT = `${c.dim}│${c.reset} ${c.cyan}${c.bold}>${c.reset} `;

/* ── Tool use animation ────────────────────────────────── */

export function printToolUse(toolName: string) {
  const label = toolName
    .replace(/([A-Z])/g, ' $1')
    .trim()
    .toLowerCase();
  const face = toolName.includes('Write') ? '=^w^='
    : toolName.includes('Search') ? '=^.^='
    : '=^o^=';
  process.stdout.write(`\r  ${c.magenta}~{${face}} ${label}${c.reset}\n`);
}

/* ── Thinking animation ────────────────────────────────── */

let thinkingInterval: ReturnType<typeof setInterval> | null = null;

export function startThinking() {
  const faces = ['^.^', '^o^'];
  const dots = ['.  ', '.. ', '...'];
  let tick = 0;
  const render = () => {
    const face = faces[Math.floor(tick / 3) % faces.length];
    const dot = dots[tick % dots.length];
    return `${c.yellow}  (=${face}=) ${c.dim}thinking${dot}${c.reset}`;
  };
  process.stdout.write(render());
  thinkingInterval = setInterval(() => {
    tick++;
    process.stdout.write('\r' + render());
  }, 300);
}

export function stopThinking() {
  if (thinkingInterval) {
    clearInterval(thinkingInterval);
    thinkingInterval = null;
    process.stdout.write('\r' + ' '.repeat(40) + '\r');
  }
}

/* ── Messages ──────────────────────────────────────────── */

export function printBotMsg(msg: string) {
  const lines = msg.split('\n');
  console.log(`  ${c.bold}${c.yellow}Meow >${c.reset} ${lines[0]}`);
  for (let i = 1; i < lines.length; i++) {
    console.log(`         ${lines[i]}`);
  }
}

/* ── Response footer ───────────────────────────────────── */

export function printResponseEnd() {
  console.log('');
  console.log(c.dim + '  ' + '─'.repeat(Math.min(cols() - 4, 116)) + c.reset);
}

export function printStats(stats: {
  model: string;
  inputTokens: number;
  outputTokens: number;
  durationMs: number;
}) {
  const dur = (stats.durationMs / 1000).toFixed(1);
  const total = stats.inputTokens + stats.outputTokens;
  const line = [
    `${c.gray}  ─`,
    `${stats.model}`,
    `│ ${stats.inputTokens}in ${stats.outputTokens}out (${total} tok)`,
    `│ ${dur}s`,
    `─${c.reset}`,
  ].join(' ');
  console.log(line);
}
