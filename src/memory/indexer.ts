import { Database } from 'bun:sqlite';
import * as sqliteVec from 'sqlite-vec';
import { createHash } from 'crypto';
import { resolve } from 'path';
import type { Chunk, KnowledgeEntry, KnowledgeResult, MemoryConfig, SearchResult } from './types.js';

type EmbedFn = (text: string) => Promise<number[]>;

export class MemoryIndexer {
  private db: Database;
  private embedFn: EmbedFn | null = null;
  private dimensions = 0;

  constructor(
    dbPath: string,
    private config: MemoryConfig,
  ) {
    this.db = new Database(resolve(dbPath));
    sqliteVec.load(this.db);
    this.initSchema();
  }

  setEmbedFunction(fn: EmbedFn, dimensions: number): void {
    this.embedFn = fn;
    this.dimensions = dimensions;
    this.ensureVecTable();
  }

  private initSchema(): void {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS chunks (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        start_line INTEGER NOT NULL,
        end_line INTEGER NOT NULL,
        text TEXT NOT NULL,
        hash TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_chunks_path ON chunks(path);
      CREATE INDEX IF NOT EXISTS idx_chunks_hash ON chunks(hash);
    `);
    this.db.exec(`
      CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts
      USING fts5(text, content=chunks, content_rowid=rowid);
    `);
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS knowledge (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        summary TEXT NOT NULL,
        source_url TEXT,
        source_type TEXT NOT NULL DEFAULT 'note',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL
      );
      CREATE TABLE IF NOT EXISTS knowledge_tags (
        knowledge_id TEXT NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (knowledge_id, tag_id)
      );
      CREATE INDEX IF NOT EXISTS idx_kt_tag ON knowledge_tags(tag_id);
    `);
    this.db.exec(`
      CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts
      USING fts5(title, content, summary, content=knowledge, content_rowid=rowid);
    `);
  }

  private ensureVecTable(): void {
    if (!this.dimensions) return;
    try {
      this.db.exec(
        `CREATE VIRTUAL TABLE IF NOT EXISTS chunks_vec
         USING vec0(id TEXT PRIMARY KEY, embedding float[${this.dimensions}])`,
      );
    } catch {
      // table may already exist with different dimensions
    }
  }

  async indexFile(filePath: string, content: string): Promise<number> {
    const lines = content.split('\n');
    const chunks = this.chunkLines(lines, filePath);

    // Remove old chunks for this file
    this.removeFile(filePath);

    const insertChunk = this.db.prepare(
      `INSERT INTO chunks (id, path, start_line, end_line, text, hash)
       VALUES (?, ?, ?, ?, ?, ?)`,
    );
    const insertFts = this.db.prepare(
      `INSERT INTO chunks_fts (rowid, text)
       VALUES ((SELECT rowid FROM chunks WHERE id = ?), ?)`,
    );

    let indexed = 0;
    for (const chunk of chunks) {
      insertChunk.run(chunk.id, chunk.path, chunk.startLine, chunk.endLine, chunk.text, chunk.hash);
      insertFts.run(chunk.id, chunk.text);

      if (this.embedFn) {
        await this.indexVector(chunk);
      }
      indexed++;
    }
    return indexed;
  }

  private async indexVector(chunk: Chunk): Promise<void> {
    if (!this.embedFn || !this.dimensions) return;

    // Check cache
    const cached = this.db.query(
      `SELECT 1 FROM chunks_vec WHERE id = ?`,
    ).get(chunk.id);
    if (cached) return;

    const embedding = await this.embedFn(chunk.text);
    const vec = new Float32Array(embedding);

    this.db.prepare(
      `INSERT INTO chunks_vec (id, embedding) VALUES (?, ?)`,
    ).run(chunk.id, vec);
  }

  removeFile(filePath: string): void {
    const rows = this.db.query(
      `SELECT rowid FROM chunks WHERE path = ?`,
    ).all(filePath) as Array<{ rowid: number }>;

    for (const row of rows) {
      this.db.prepare(`DELETE FROM chunks_fts WHERE rowid = ?`).run(row.rowid);
    }
    this.db.prepare(`DELETE FROM chunks WHERE path = ?`).run(filePath);

    if (this.dimensions) {
      this.db.prepare(
        `DELETE FROM chunks_vec WHERE id IN (SELECT id FROM chunks WHERE path = ?)`,
      ).run(filePath);
    }
  }

  async search(query: string): Promise<SearchResult[]> {
    const keywordResults = this.searchKeyword(query);
    const vectorResults = this.embedFn
      ? await this.searchVector(query)
      : [];

    const chunkResults = this.mergeResults(keywordResults, vectorResults);

    // Also search knowledge entries and merge into unified results
    const knowledgeResults = this.searchKnowledgeKeyword(query, this.config.maxResults);
    const knowledgeAsSearch: SearchResult[] = knowledgeResults.map(k => ({
      path: `knowledge/${k.id}`,
      startLine: 0,
      endLine: 0,
      score: k.score,
      snippet: `**${k.title}** [${k.tags.join(', ')}]: ${k.summary}`,
      source: 'knowledge' as const,
      knowledgeId: k.id,
      tags: k.tags,
    }));

    return [...chunkResults, ...knowledgeAsSearch]
      .sort((a, b) => b.score - a.score)
      .slice(0, this.config.maxResults);
  }

  private searchKeyword(query: string): Array<SearchResult & { _rawScore: number }> {
    const escaped = query.replace(/"/g, '""');
    try {
      const rows = this.db.query(`
        SELECT c.path, c.start_line, c.end_line, c.text,
               bm25(chunks_fts) as score
        FROM chunks_fts f
        JOIN chunks c ON c.rowid = f.rowid
        WHERE chunks_fts MATCH ?
        ORDER BY score
        LIMIT ?
      `).all(`"${escaped}"`, this.config.maxResults * 2) as Array<{
        path: string;
        start_line: number;
        end_line: number;
        text: string;
        score: number;
      }>;

      return rows.map(r => ({
        path: r.path,
        startLine: r.start_line,
        endLine: r.end_line,
        snippet: r.text.slice(0, 500),
        score: Math.abs(r.score),
        _rawScore: Math.abs(r.score),
        source: r.path.includes('daily/') ? 'daily' as const : 'memory' as const,
      }));
    } catch {
      return [];
    }
  }

  private async searchVector(query: string): Promise<Array<SearchResult & { _rawScore: number }>> {
    if (!this.embedFn || !this.dimensions) return [];

    const embedding = await this.embedFn(query);
    const vec = new Float32Array(embedding);

    try {
      const rows = this.db.query(`
        SELECT v.id, v.distance, c.path, c.start_line, c.end_line, c.text
        FROM chunks_vec v
        JOIN chunks c ON c.id = v.id
        WHERE v.embedding MATCH ?
        ORDER BY v.distance
        LIMIT ?
      `).all(vec, this.config.maxResults * 2) as Array<{
        id: string;
        distance: number;
        path: string;
        start_line: number;
        end_line: number;
        text: string;
      }>;

      return rows.map(r => ({
        path: r.path,
        startLine: r.start_line,
        endLine: r.end_line,
        snippet: r.text.slice(0, 500),
        score: 1 - r.distance,
        _rawScore: 1 - r.distance,
        source: r.path.includes('daily/') ? 'daily' as const : 'memory' as const,
      }));
    } catch {
      return [];
    }
  }

  private mergeResults(
    keyword: Array<SearchResult & { _rawScore: number }>,
    vector: Array<SearchResult & { _rawScore: number }>,
  ): SearchResult[] {
    const merged = new Map<string, SearchResult>();

    const hasVector = vector.length > 0;
    const maxKw = Math.max(...keyword.map(r => r._rawScore), 1);
    const maxVec = Math.max(...vector.map(r => r._rawScore), 1);

    // When only keyword search is active, use full weight (1.0)
    const kwWeight = hasVector ? this.config.keywordWeight : 1.0;
    const vecWeight = this.config.vectorWeight;

    for (const r of keyword) {
      const key = `${r.path}:${r.startLine}`;
      const normScore = (r._rawScore / maxKw) * kwWeight;
      merged.set(key, { ...r, score: normScore });
    }

    for (const r of vector) {
      const key = `${r.path}:${r.startLine}`;
      const normScore = (r._rawScore / maxVec) * vecWeight;
      const existing = merged.get(key);
      if (existing) {
        existing.score += normScore;
      } else {
        merged.set(key, { ...r, score: normScore });
      }
    }

    return [...merged.values()]
      .filter(r => r.score >= this.config.minScore)
      .sort((a, b) => b.score - a.score)
      .slice(0, this.config.maxResults);
  }

  private chunkLines(lines: string[], filePath: string): Chunk[] {
    const chunks: Chunk[] = [];
    const charsPerLine = 80;
    const linesPerChunk = Math.ceil(this.config.chunkSize / charsPerLine);
    const overlapLines = Math.ceil(this.config.chunkOverlap / charsPerLine);

    let start = 0;
    while (start < lines.length) {
      const end = Math.min(start + linesPerChunk, lines.length);
      const text = lines.slice(start, end).join('\n');
      const hash = createHash('sha256').update(text).digest('hex').slice(0, 16);

      chunks.push({
        id: `${filePath}:${start}:${hash}`,
        path: filePath,
        startLine: start + 1,
        endLine: end,
        text,
        hash,
      });

      start += linesPerChunk - overlapLines;
      if (start >= lines.length) break;
    }
    return chunks;
  }

  recentChunks(limit: number): SearchResult[] {
    const rows = this.db.query(`
      SELECT path, start_line, end_line, text
      FROM chunks
      ORDER BY path DESC, start_line DESC
      LIMIT ?
    `).all(limit) as Array<{
      path: string;
      start_line: number;
      end_line: number;
      text: string;
    }>;

    return rows.map(r => ({
      path: r.path,
      startLine: r.start_line,
      endLine: r.end_line,
      snippet: r.text.slice(0, 500),
      score: 1.0,
      source: r.path.includes('daily/') ? 'daily' as const : 'memory' as const,
    }));
  }

  // ── Knowledge CRUD ──

  async saveKnowledge(entry: Omit<KnowledgeEntry, 'createdAt' | 'updatedAt'>): Promise<string> {
    const now = new Date().toISOString();
    this.db.prepare(`
      INSERT INTO knowledge (id, title, content, summary, source_url, source_type, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(entry.id, entry.title, entry.content, entry.summary, entry.sourceUrl ?? null, entry.sourceType, now, now);

    // FTS index
    const row = this.db.query(`SELECT rowid FROM knowledge WHERE id = ?`).get(entry.id) as { rowid: number } | null;
    if (row) {
      this.db.prepare(`INSERT INTO knowledge_fts (rowid, title, content, summary) VALUES (?, ?, ?, ?)`)
        .run(row.rowid, entry.title, entry.content, entry.summary);
    }

    // Tags
    if (entry.tags.length > 0) {
      this.addTags(entry.id, entry.tags);
    }

    // Vector embedding on title + summary
    if (this.embedFn && this.dimensions) {
      await this.indexKnowledgeVector(entry.id, `${entry.title} ${entry.summary}`);
    }

    return entry.id;
  }

  getKnowledge(id: string): KnowledgeEntry | null {
    const row = this.db.query(`SELECT * FROM knowledge WHERE id = ?`).get(id) as Record<string, string> | null;
    if (!row) return null;
    return {
      id: row.id,
      title: row.title,
      content: row.content,
      summary: row.summary,
      sourceUrl: row.source_url || undefined,
      sourceType: row.source_type as KnowledgeEntry['sourceType'],
      tags: this.getTagsForKnowledge(id),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  searchKnowledge(query: string, tags?: string[], limit = 10): KnowledgeResult[] {
    let results = this.searchKnowledgeKeyword(query, limit * 2);

    // Tag filter
    if (tags && tags.length > 0) {
      const tagSet = new Set(tags);
      results = results.filter(r => r.tags.some(t => tagSet.has(t)));
    }

    return results.slice(0, limit);
  }

  addTags(knowledgeId: string, tags: string[]): void {
    for (const tag of tags) {
      const name = tag.toLowerCase().trim();
      if (!name) continue;
      this.db.prepare(`INSERT OR IGNORE INTO tags (name) VALUES (?)`).run(name);
      const tagRow = this.db.query(`SELECT id FROM tags WHERE name = ?`).get(name) as { id: number } | null;
      if (tagRow) {
        this.db.prepare(`INSERT OR IGNORE INTO knowledge_tags (knowledge_id, tag_id) VALUES (?, ?)`)
          .run(knowledgeId, tagRow.id);
      }
    }
  }

  removeTags(knowledgeId: string, tags: string[]): void {
    for (const tag of tags) {
      const name = tag.toLowerCase().trim();
      const tagRow = this.db.query(`SELECT id FROM tags WHERE name = ?`).get(name) as { id: number } | null;
      if (tagRow) {
        this.db.prepare(`DELETE FROM knowledge_tags WHERE knowledge_id = ? AND tag_id = ?`)
          .run(knowledgeId, tagRow.id);
      }
    }
  }

  listTags(): string[] {
    const rows = this.db.query(`
      SELECT t.name, COUNT(kt.knowledge_id) as cnt
      FROM tags t JOIN knowledge_tags kt ON t.id = kt.tag_id
      GROUP BY t.id ORDER BY cnt DESC
    `).all() as Array<{ name: string }>;
    return rows.map(r => r.name);
  }

  recentKnowledge(limit: number): KnowledgeResult[] {
    const rows = this.db.query(`
      SELECT id, title, summary, source_type, source_url, created_at
      FROM knowledge ORDER BY created_at DESC LIMIT ?
    `).all(limit) as Array<Record<string, string>>;
    return rows.map(r => ({
      id: r.id,
      title: r.title,
      summary: r.summary,
      tags: this.getTagsForKnowledge(r.id),
      score: 1.0,
      sourceType: r.source_type as KnowledgeEntry['sourceType'],
      sourceUrl: r.source_url || undefined,
      createdAt: r.created_at,
    }));
  }

  private getTagsForKnowledge(knowledgeId: string): string[] {
    const rows = this.db.query(`
      SELECT t.name FROM tags t
      JOIN knowledge_tags kt ON t.id = kt.tag_id
      WHERE kt.knowledge_id = ?
    `).all(knowledgeId) as Array<{ name: string }>;
    return rows.map(r => r.name);
  }

  private searchKnowledgeKeyword(query: string, limit: number): KnowledgeResult[] {
    const escaped = query.replace(/"/g, '""');
    try {
      const rows = this.db.query(`
        SELECT k.id, k.title, k.summary, k.source_type, k.source_url, k.created_at,
               bm25(knowledge_fts) as score
        FROM knowledge_fts f
        JOIN knowledge k ON k.rowid = f.rowid
        WHERE knowledge_fts MATCH ?
        ORDER BY score
        LIMIT ?
      `).all(`"${escaped}"`, limit) as Array<Record<string, string | number>>;

      return rows.map(r => ({
        id: r.id as string,
        title: r.title as string,
        summary: r.summary as string,
        tags: this.getTagsForKnowledge(r.id as string),
        score: Math.abs(r.score as number),
        sourceType: (r.source_type as string) as KnowledgeEntry['sourceType'],
        sourceUrl: (r.source_url as string) || undefined,
        createdAt: r.created_at as string,
      }));
    } catch {
      return [];
    }
  }

  private async indexKnowledgeVector(id: string, text: string): Promise<void> {
    if (!this.embedFn || !this.dimensions) return;
    const embedding = await this.embedFn(text);
    const vec = new Float32Array(embedding);
    try {
      this.db.prepare(`INSERT OR REPLACE INTO chunks_vec (id, embedding) VALUES (?, ?)`)
        .run(`knowledge:${id}`, vec);
    } catch {
      // vec table may not exist
    }
  }

  close(): void {
    this.db.close();
  }
}
