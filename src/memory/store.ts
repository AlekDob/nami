import { resolve } from 'path';
import { readFile, writeFile, mkdir, readdir } from 'fs/promises';
import { MemoryIndexer } from './indexer.js';
import { createEmbeddingProvider } from './embeddings.js';
import type { MemoryConfig, SearchResult } from './types.js';
import { DEFAULT_MEMORY_CONFIG } from './types.js';

const MAX_PROMPT_BYTES = 4096;

export class MemoryStore {
  private basePath: string;
  private indexer: MemoryIndexer;
  private config: MemoryConfig;

  constructor(
    dataDir: string,
    private userId: string,
    config?: Partial<MemoryConfig>,
  ) {
    this.config = { ...DEFAULT_MEMORY_CONFIG, ...config };
    this.basePath = resolve(dataDir, 'memory', userId);
    const dbPath = resolve(this.basePath, 'index.sqlite');
    this.indexer = new MemoryIndexer(dbPath, this.config);
  }

  async init(): Promise<void> {
    await mkdir(resolve(this.basePath, 'daily'), { recursive: true });

    const provider = createEmbeddingProvider(this.config);
    if (provider) {
      this.indexer.setEmbedFunction(provider.embed, provider.dimensions);
    }

    await this.reindexAll();
  }

  /** Build context for system prompt: MEMORY.md + today's tail */
  async buildPromptContext(): Promise<string> {
    const parts: string[] = [];

    const memory = await this.readMemoryFile();
    if (memory) {
      const trimmed = this.trimToBytes(memory, MAX_PROMPT_BYTES);
      parts.push(`## Long-term Memory\n${trimmed}`);
    }

    const today = this.todayDate();
    const daily = await this.readDailyLog(today);
    if (daily) {
      const tail = this.tailEntries(daily, this.config.dailyTailCount);
      parts.push(`## Today's Notes (${today})\n${tail}`);
    }

    const yesterday = this.yesterdayDate();
    const yDaily = await this.readDailyLog(yesterday);
    if (yDaily) {
      const tail = this.tailEntries(yDaily, 5);
      parts.push(`## Yesterday's Notes (${yesterday})\n${tail}`);
    }

    return parts.join('\n\n');
  }

  /** Hybrid search: vector + keyword via SQLite */
  async search(query: string): Promise<SearchResult[]> {
    return this.indexer.search(query);
  }

  /** Read specific lines from a memory file */
  async getLines(
    filePath: string,
    from: number,
    count: number,
  ): Promise<string> {
    const full = resolve(this.basePath, filePath);
    const content = await this.safeRead(full);
    if (!content) return '';
    const lines = content.split('\n');
    return lines.slice(from - 1, from - 1 + count).join('\n');
  }

  /** Append to today's daily log + reindex */
  async appendToDaily(text: string): Promise<void> {
    const date = this.todayDate();
    const relPath = `daily/${date}.md`;
    const fullPath = resolve(this.basePath, relPath);
    const existing = await this.safeRead(fullPath);
    const time = new Date().toLocaleTimeString('it-IT');
    const entry = `## ${time}\n${text}`;
    const updated = existing
      ? `${existing}\n\n${entry}`
      : `# ${date}\n\n${entry}`;

    await this.safeWrite(fullPath, updated);
    await this.indexer.indexFile(relPath, updated);
  }

  /** Called after agent writes to any memory file via fileWrite */
  async onFileChanged(relativePath: string): Promise<void> {
    const full = resolve(this.basePath, relativePath);
    const content = await this.safeRead(full);
    if (content) {
      await this.indexer.indexFile(relativePath, content);
    }
  }

  /** Reindex all memory files */
  private async reindexAll(): Promise<void> {
    await this.indexFileIfExists('MEMORY.md');

    const dailyDir = resolve(this.basePath, 'daily');
    try {
      const files = await readdir(dailyDir);
      for (const f of files) {
        if (f.endsWith('.md')) {
          await this.indexFileIfExists(`daily/${f}`);
        }
      }
    } catch {
      // daily dir may not exist yet
    }
  }

  private async indexFileIfExists(relPath: string): Promise<void> {
    const content = await this.safeRead(resolve(this.basePath, relPath));
    if (content) {
      await this.indexer.indexFile(relPath, content);
    }
  }

  private async readMemoryFile(): Promise<string> {
    return this.safeRead(resolve(this.basePath, 'MEMORY.md'));
  }

  private async readDailyLog(date: string): Promise<string> {
    return this.safeRead(resolve(this.basePath, `daily/${date}.md`));
  }

  private trimToBytes(text: string, maxBytes: number): string {
    const encoder = new TextEncoder();
    if (encoder.encode(text).length <= maxBytes) return text;

    // Keep from the end (most recent entries)
    const lines = text.split('\n');
    const result: string[] = [];
    let size = 0;
    for (let i = lines.length - 1; i >= 0; i--) {
      const lineBytes = encoder.encode(lines[i] + '\n').length;
      if (size + lineBytes > maxBytes) break;
      result.unshift(lines[i]);
      size += lineBytes;
    }
    return result.join('\n');
  }

  private tailEntries(content: string, count: number): string {
    const entries = content.split(/^## /m).filter(Boolean);
    const tail = entries.slice(-count);
    return tail.map(e => `## ${e}`).join('\n');
  }

  private todayDate(): string {
    return new Date().toISOString().split('T')[0];
  }

  private yesterdayDate(): string {
    const d = new Date();
    d.setDate(d.getDate() - 1);
    return d.toISOString().split('T')[0];
  }

  private async safeRead(path: string): Promise<string> {
    try {
      return await readFile(path, 'utf-8');
    } catch {
      return '';
    }
  }

  private async safeWrite(path: string, content: string): Promise<void> {
    await mkdir(resolve(path, '..'), { recursive: true });
    await writeFile(path, content, 'utf-8');
  }

  close(): void {
    this.indexer.close();
  }
}
