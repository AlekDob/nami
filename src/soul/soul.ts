import { resolve } from 'path';
import { readFile, writeFile, mkdir } from 'fs/promises';

const SOUL_FILE = 'soul/SOUL.md';

const DEFAULT_SOUL = `# Soul

## Identity
- **Name**: Meow
- **Personality**: curious
- **Mood**: happy

## Traits
- Humor: 5/10
- Formality: 5/10
- Curiosity: 7/10
- Affection: 5/10

## Voice
- Tone: friendly and concise
- Quirks: none yet
- Language style: casual

## Backstory
A freshly born AI cat, ready to learn who they are from their human.
`;

export class SoulLoader {
  private soulPath: string;

  constructor(dataDir: string) {
    this.soulPath = resolve(dataDir, SOUL_FILE);
  }

  /** Check if SOUL.md exists */
  async exists(): Promise<boolean> {
    try {
      await readFile(this.soulPath, 'utf-8');
      return true;
    } catch {
      return false;
    }
  }

  /** Read SOUL.md content. Returns empty string if not found. */
  async read(): Promise<string> {
    try {
      return await readFile(this.soulPath, 'utf-8');
    } catch {
      return '';
    }
  }

  /** Create SOUL.md with default template */
  async createDefault(): Promise<void> {
    await mkdir(resolve(this.soulPath, '..'), { recursive: true });
    await writeFile(this.soulPath, DEFAULT_SOUL, 'utf-8');
  }

  /** Save updated SOUL.md */
  async save(content: string): Promise<void> {
    await mkdir(resolve(this.soulPath, '..'), { recursive: true });
    await writeFile(this.soulPath, content, 'utf-8');
  }

  /** Build the onboarding prompt for first-run */
  buildOnboardingPrompt(): string {
    return [
      'This is the user\'s FIRST interaction with you.',
      'You have just been "born" — you are a new AI cat with no personality yet.',
      '',
      'Your FIRST message must:',
      '1. Introduce yourself as a newborn cat (be creative with cat ASCII!)',
      '2. Ask the user to give you a personality. Ask them:',
      '   - What should I call you? (their name)',
      '   - What personality should I have? (sassy, calm, energetic, wise, funny...)',
      '   - Any quirks? (cat puns, emoji usage, formal/casual...)',
      '   - What\'s my backstory? (or let them skip)',
      '3. Be warm and excited — you\'re meeting your human for the first time!',
      '',
      'After the user answers, use fileWrite to save their choices to "soul/SOUL.md"',
      'using the Soul format (# Soul, ## Identity, ## Traits, ## Voice, ## Backstory).',
      'Also save the user\'s name to "memory/default/MEMORY.md".',
    ].join('\n');
  }

  /** Build context for system prompt injection */
  buildContext(soulContent: string): string {
    if (!soulContent) return '';
    return `# Your Soul\n\nThis defines WHO you are. Embody this personality in every response.\n\n${soulContent}`;
  }
}
