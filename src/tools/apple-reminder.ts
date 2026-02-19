import { tool } from 'ai';
import { z } from 'zod';

const MAC_URL = process.env.MAC_AGENT_URL;
const MAC_TOKEN = process.env.MAC_AGENT_TOKEN;

function macAvailable(): boolean {
  return Boolean(MAC_URL && MAC_TOKEN);
}

async function macFetch(
  path: string,
  init?: RequestInit,
): Promise<Response> {
  return fetch(`${MAC_URL}${path}`, {
    ...init,
    headers: {
      ...init?.headers,
      Authorization: `Bearer ${MAC_TOKEN}`,
    },
    signal: AbortSignal.timeout(30_000),
  });
}

function buildAppleScript(
  title: string,
  listName: string,
  notes: string,
  dueDate: string,
): string {
  const escaped = (s: string) => s.replace(/"/g, '\\"');

  // Build date block if provided
  let dateBlock = '';
  if (dueDate) {
    const d = new Date(dueDate);
    if (!isNaN(d.getTime())) {
      dateBlock = [
        '  set dueD to current date',
        `  set year of dueD to ${d.getFullYear()}`,
        `  set month of dueD to ${d.getMonth() + 1}`,
        `  set day of dueD to ${d.getDate()}`,
        `  set hours of dueD to ${d.getHours()}`,
        `  set minutes of dueD to ${d.getMinutes()}`,
        '  set seconds of dueD to 0',
        '  set due date of newReminder to dueD',
      ].join('\n');
    }
  }

  // Try to get existing list, create if not found
  const lines: string[] = [
    'tell application "Reminders"',
    '  try',
    `    set targetList to list "${escaped(listName)}"`,
    '  on error',
    `    set targetList to make new list with properties {name:"${escaped(listName)}"}`,
    '  end try',
    '  set newReminder to make new reminder at end of targetList',
    `  set name of newReminder to "${escaped(title)}"`,
  ];

  if (notes) {
    lines.push(`  set body of newReminder to "${escaped(notes)}"`);
  }

  if (dateBlock) {
    lines.push(dateBlock);
  }

  lines.push('end tell');
  lines.push('"Reminder created"');
  return lines.join('\n');
}

// Brain: gotcha-openai-strict-tool-schema-validation
// All params are required strings to avoid z.string().optional() → "type: None" bug
export const createAppleReminder = tool({
  description:
    'Create a reminder in Apple Reminders on Alek\'s Mac. ' +
    'Syncs to iPhone via iCloud. ' +
    'Use ONLY when the user explicitly says "promemoria Apple", ' +
    '"metti nei promemoria", or "reminder Apple". ' +
    'Do NOT use for Nami internal jobs — use scheduleTask instead. ' +
    'Known iCloud lists: Spesa, Promemoria, Da Portare In Vacanza, Cose Da Fare. ' +
    'Exchange list: Tasks. ' +
    'IMPORTANT: If the user does not specify a list, ask which list to use. Do NOT default.',
  inputSchema: z.object({
    title: z.string().describe('The reminder title'),
    list: z.string().describe(
      'Reminders list name. Known iCloud: "Spesa", "Promemoria", ' +
      '"Da Portare In Vacanza", "Cose Da Fare". Exchange: "Tasks".',
    ),
    notes: z.string().describe(
      'Notes for the reminder. Pass empty string "" if none.',
    ),
    dueDate: z.string().describe(
      'Due date in ISO format (e.g. "2026-02-15T15:00:00"). ' +
      'Pass empty string "" if no due date. ' +
      'Calculate from relative expressions like "domani alle 15".',
    ),
  }),
  execute: async ({ title, list, notes, dueDate }) => {
    if (!macAvailable()) {
      return { error: 'Mac agent not configured or offline' };
    }

    // macOS default list shows as "Promemoria" in Italian UI
    // but is internally named "Reminders"
    const resolvedList = list === 'Promemoria' ? 'Reminders' : list;

    const scriptLines = buildAppleScript(title, resolvedList, notes, dueDate)
      .split('\n');
    const eArgs = scriptLines
      .map(line => `-e '${line.replace(/'/g, "'\\''")}'`)
      .join(' ');
    const command = `osascript ${eArgs}`;

    try {
      const res = await macFetch('/exec', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ command }),
      });

      const data = (await res.json()) as {
        success?: boolean;
        stdout?: string;
        stderr?: string;
        error?: string;
      };

      if (!res.ok || data.error) {
        return { error: data.error || 'Failed to create reminder' };
      }

      return {
        success: true,
        title,
        list,
        dueDate: dueDate || 'no due date',
      };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.includes('timeout') || msg.includes('ECONNREFUSED')) {
        return { error: 'Mac is offline or unreachable' };
      }
      return { error: msg };
    }
  },
});
