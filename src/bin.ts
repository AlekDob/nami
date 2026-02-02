#!/usr/bin/env bun
/**
 * Meow CLI entry point with subcommands.
 *
 * meow          interactive chat (default)
 * meow start    start daemon (systemd)
 * meow stop     stop daemon
 * meow restart  restart daemon
 * meow status   show daemon status
 * meow logs     tail live logs
 * meow help     show this help
 */

import { execSync } from 'child_process';

const SERVICE = 'meow';

const HELP = [
  '',
  '  Meow - AI Personal Assistant',
  '',
  '  Usage:',
  '    meow              Start interactive chat (default)',
  '    meow chat         Start interactive chat',
  '    meow start        Start daemon (background)',
  '    meow stop         Stop daemon',
  '    meow restart      Restart daemon',
  '    meow status       Show daemon status',
  '    meow logs         Tail live logs (Ctrl+C to exit)',
  '    meow logs -n 50   Show last N log lines',
  '    meow help         Show this help',
  '',
].join('\n');

function run(cmd: string, inherit = false): string {
  try {
    if (inherit) {
      execSync(cmd, { stdio: 'inherit' });
      return '';
    }
    return execSync(cmd, { encoding: 'utf-8' }).trim();
  } catch {
    return '';
  }
}

function serviceAction(action: string): void {
  run('systemctl ' + action + ' ' + SERVICE, true);
}

async function startChat(): Promise<void> {
  await import('./cli/index.js');
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const cmd = args[0] || 'chat';

  switch (cmd) {
    case 'chat':
      await startChat();
      break;

    case 'start':
      serviceAction('start');
      console.log('  Meow daemon started.');
      break;

    case 'stop':
      serviceAction('stop');
      console.log('  Meow daemon stopped.');
      break;

    case 'restart':
      serviceAction('restart');
      console.log('  Meow daemon restarted.');
      break;

    case 'status':
      run('systemctl status ' + SERVICE, true);
      break;

    case 'logs': {
      const nIdx = args.indexOf('-n');
      if (nIdx !== -1 && args[nIdx + 1]) {
        run('journalctl -u ' + SERVICE + ' -n ' + args[nIdx + 1] + ' --no-pager', true);
      } else {
        run('journalctl -u ' + SERVICE + ' -f', true);
      }
      break;
    }

    case 'help':
    case '--help':
    case '-h':
      console.log(HELP);
      break;

    default:
      await startChat();
      break;
  }
}

main().catch(console.error);
