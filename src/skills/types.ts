export interface SkillMeta {
  name: string;
  description: string;
  tools?: string[];
  schedule?: string;
}

export interface Skill {
  meta: SkillMeta;
  body: string;
  filePath: string;
}
