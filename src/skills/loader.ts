import { resolve } from 'path';
import { readdir, readFile } from 'fs/promises';
import type { Skill, SkillMeta } from './types.js';

const FRONTMATTER_RE = /^---\n([\s\S]*?)\n---\n([\s\S]*)$/;

export class SkillLoader {
  private skillsDir: string;

  constructor(dataDir: string) {
    this.skillsDir = resolve(dataDir, 'skills');
  }

  async loadAll(): Promise<Skill[]> {
    const files = await this.listSkillFiles();
    const skills: Skill[] = [];

    for (const file of files) {
      const skill = await this.loadSkill(file);
      if (skill) skills.push(skill);
    }

    return skills;
  }

  buildContext(skills: Skill[]): string {
    if (skills.length === 0) return '';
    const parts = skills.map(s =>
      `### ${s.meta.name}\n${s.meta.description}\n\n${s.body}`,
    );
    return parts.join('\n\n---\n\n');
  }

  private async loadSkill(fileName: string): Promise<Skill | null> {
    const filePath = resolve(this.skillsDir, fileName);
    const raw = await this.safeRead(filePath);
    if (!raw) return null;

    const match = raw.match(FRONTMATTER_RE);
    if (!match) return null;

    const meta = this.parseYaml(match[1]);
    if (!meta.name) return null;

    return { meta, body: match[2].trim(), filePath };
  }

  private parseYaml(raw: string): SkillMeta {
    const meta: Record<string, string | string[]> = {};
    for (const line of raw.split('\n')) {
      const idx = line.indexOf(':');
      if (idx === -1) continue;
      const key = line.slice(0, idx).trim();
      const val = line.slice(idx + 1).trim();
      if (val.startsWith('[') && val.endsWith(']')) {
        meta[key] = val.slice(1, -1).split(',').map(s => s.trim());
      } else {
        meta[key] = val;
      }
    }
    return {
      name: String(meta.name || ''),
      description: String(meta.description || ''),
      tools: Array.isArray(meta.tools) ? meta.tools : undefined,
      schedule: typeof meta.schedule === 'string' ? meta.schedule : undefined,
    };
  }

  private async listSkillFiles(): Promise<string[]> {
    try {
      const entries = await readdir(this.skillsDir);
      return entries.filter(f => f.endsWith('.md'));
    } catch {
      return [];
    }
  }

  private async safeRead(path: string): Promise<string> {
    try {
      return await readFile(path, 'utf-8');
    } catch {
      return '';
    }
  }
}
