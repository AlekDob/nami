export const c = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  cyan: '\x1b[36m',
  yellow: '\x1b[33m',
  green: '\x1b[32m',
  magenta: '\x1b[35m',
  white: '\x1b[37m',
};

const CAT_FACES = ['o.o', '-.o', 'o.-', '^.^'];

const CAT_TEMPLATE = (face: string) => `
   /\\_/\\
  ( ${face} )
   > ^ <
  /|   |\\
 (_)   (_)`;

const catFrames = CAT_FACES.map(f => CAT_TEMPLATE(f));

export function animateCat(): Promise<void> {
  return new Promise((resolve) => {
    const lineCount = catFrames[0].split('\n').length;
    let frame = 0;
    let count = 0;
    const interval = setInterval(() => {
      if (count > 0) process.stdout.write(`\x1b[${lineCount}A`);
      const colored = catFrames[frame % catFrames.length]
        .split('\n')
        .map(l => `  ${c.yellow}${l}${c.reset}`)
        .join('\n');
      console.log(colored);
      frame++;
      count++;
      if (count >= 8) {
        clearInterval(interval);
        resolve();
      }
    }, 200);
  });
}

export function printHeader(model: string, runtime: string, platform: string) {
  const sep = `${c.dim}  ${'━'.repeat(44)}${c.reset}`;
  const lines = [
    sep,
    `  ${c.bold}${c.cyan}Meow${c.reset} ${c.dim}— AI Personal Assistant${c.reset}`,
    sep,
    `  ${c.dim}Runtime:${c.reset} ${runtime} (${platform})`,
    `  ${c.dim}Model:${c.reset}   ${c.green}${model}${c.reset}`,
    sep,
    `  ${c.dim}Commands:${c.reset}`,
    `    ${c.cyan}/model${c.reset} [name]  Change model`,
    `    ${c.cyan}/clear${c.reset}         Clear history`,
    `    ${c.cyan}/exit${c.reset}          Quit`,
    sep,
    '',
  ];
  lines.forEach(l => console.log(l));
}

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

export function printUserMsg(msg: string) {
  console.log(`  ${c.bold}${c.cyan}You >${c.reset} ${c.white}${msg}${c.reset}`);
}

export function printBotMsg(msg: string) {
  const lines = msg.split('\n');
  console.log(`  ${c.bold}${c.yellow}Meow >${c.reset} ${lines[0]}`);
  for (let i = 1; i < lines.length; i++) {
    console.log(`  ${c.dim}      |${c.reset} ${lines[i]}`);
  }
}

export const PROMPT = `  ${c.cyan}${c.bold}>${c.reset} `;
