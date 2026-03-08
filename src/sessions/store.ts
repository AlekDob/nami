import { resolve } from 'path';
import { readFile, writeFile, mkdir, unlink } from 'fs/promises';
import type {
  Session, SessionMessage, SessionMeta,
  SessionIndex, SessionSource,
} from './types.js';

const MAX_TITLE_LENGTH = 60;

export class SessionStore {
  private indexPath: string;
  private sessionsDir: string;
  private index: SessionIndex = { sessions: [], version: 1 };

  constructor(dataDir: string) {
    this.sessionsDir = resolve(dataDir, 'sessions');
    this.indexPath = resolve(this.sessionsDir, 'index.json');
  }

  async init(): Promise<void> {
    await mkdir(this.sessionsDir, { recursive: true });
    await this.loadIndex();
  }

  async createSession(
    source: SessionSource,
    title?: string,
  ): Promise<Session> {
    const id = crypto.randomUUID().slice(0, 8);
    const now = new Date().toISOString();
    const session: Session = {
      id,
      title: title || 'New conversation',
      source,
      messages: [],
      createdAt: now,
      updatedAt: now,
    };
    await this.saveSession(session);
    this.addToIndex(session);
    await this.saveIndex();
    return session;
  }

  async getSession(id: string): Promise<Session | null> {
    try {
      const path = this.sessionPath(id);
      const raw = await readFile(path, 'utf-8');
      return JSON.parse(raw) as Session;
    } catch {
      return null;
    }
  }

  listSessions(): SessionMeta[] {
    return [...this.index.sessions].sort(
      (a, b) => new Date(b.updatedAt).getTime()
        - new Date(a.updatedAt).getTime(),
    );
  }

  async deleteSession(id: string): Promise<boolean> {
    const idx = this.index.sessions.findIndex(s => s.id === id);
    if (idx === -1) return false;
    this.index.sessions.splice(idx, 1);
    await this.saveIndex();
    try { await unlink(this.sessionPath(id)); } catch { /* ok */ }
    return true;
  }

  async updateSession(
    id: string,
    updates: Partial<Pick<Session, 'title'>>,
  ): Promise<SessionMeta | null> {
    const session = await this.getSession(id);
    if (!session) return null;
    if (updates.title) session.title = updates.title;
    session.updatedAt = new Date().toISOString();
    await this.saveSession(session);
    this.syncIndexEntry(session);
    await this.saveIndex();
    return this.toMeta(session);
  }

  async appendMessage(
    id: string,
    role: SessionMessage['role'],
    content: string,
  ): Promise<void> {
    const session = await this.getSession(id);
    if (!session) return;
    const msg: SessionMessage = {
      role,
      content,
      timestamp: new Date().toISOString(),
    };
    session.messages.push(msg);
    session.updatedAt = msg.timestamp;
    if (session.title === 'New conversation' && role === 'user') {
      session.title = this.safeSlice(content, MAX_TITLE_LENGTH).trim();
    }
    await this.saveSession(session);
    this.syncIndexEntry(session);
    await this.saveIndex();
  }

  // MARK: - Private

  // Brain: fix-sessions-surrogate-pair-truncation
  /** Truncate without splitting UTF-16 surrogate pairs */
  private safeSlice(str: string, maxLen: number): string {
    if (str.length <= maxLen) return str;
    // If char at maxLen-1 is a high surrogate, cut one shorter
    const code = str.charCodeAt(maxLen - 1);
    const end = (code >= 0xD800 && code <= 0xDBFF) ? maxLen - 1 : maxLen;
    return str.slice(0, end);
  }

  /** Remove lone surrogates that break Swift JSONDecoder */
  private stripLoneSurrogates(str: string): string {
    let result = '';
    for (let i = 0; i < str.length; i++) {
      const code = str.charCodeAt(i);
      if (code >= 0xD800 && code <= 0xDBFF) {
        const next = str.charCodeAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          result += str[i] + str[i + 1];
          i++;
        }
        // else: lone high surrogate — skip
      } else if (code >= 0xDC00 && code <= 0xDFFF) {
        // lone low surrogate — skip
      } else {
        result += str[i];
      }
    }
    return result;
  }

  private sessionPath(id: string): string {
    return resolve(this.sessionsDir, `${id}.json`);
  }

  private async saveSession(session: Session): Promise<void> {
    await writeFile(
      this.sessionPath(session.id),
      JSON.stringify(session, null, 2),
      'utf-8',
    );
  }

  private toMeta(session: Session): SessionMeta {
    const last = session.messages[session.messages.length - 1];
    return {
      id: session.id,
      title: session.title,
      source: session.source,
      messageCount: session.messages.length,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
      lastMessage: last ? this.safeSlice(last.content, 100) : '',
    };
  }

  private addToIndex(session: Session): void {
    this.index.sessions.push(this.toMeta(session));
  }

  private syncIndexEntry(session: Session): void {
    const idx = this.index.sessions.findIndex(
      s => s.id === session.id,
    );
    const meta = this.toMeta(session);
    if (idx >= 0) {
      this.index.sessions[idx] = meta;
    } else {
      this.index.sessions.push(meta);
    }
  }

  private async loadIndex(): Promise<void> {
    try {
      const raw = await readFile(this.indexPath, 'utf-8');
      this.index = JSON.parse(raw) as SessionIndex;
      // Brain: fix-sessions-surrogate-pair-truncation
      // Sanitize old data that may contain lone surrogates from pre-fix era
      let dirty = false;
      for (const s of this.index.sessions) {
        const cleanMsg = this.stripLoneSurrogates(s.lastMessage || '');
        const cleanTitle = this.stripLoneSurrogates(s.title || '');
        if (cleanMsg !== s.lastMessage) { s.lastMessage = cleanMsg; dirty = true; }
        if (cleanTitle !== s.title) { s.title = cleanTitle; dirty = true; }
      }
      if (dirty) await this.saveIndex();
    } catch {
      this.index = { sessions: [], version: 1 };
    }
  }

  private async saveIndex(): Promise<void> {
    await writeFile(
      this.indexPath,
      JSON.stringify(this.index, null, 2),
      'utf-8',
    );
  }
}
