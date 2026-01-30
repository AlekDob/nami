export interface Job {
  id: string;
  name: string;
  cron: string;
  task: string;
  userId: string;
  enabled: boolean;
  notify?: boolean;
  repeat?: boolean;
  lastRun?: string;
}

export interface JobStore {
  jobs: Job[];
  version: number;
}
