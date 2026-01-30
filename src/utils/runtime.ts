// Runtime detection: Bun or Node.js
export type Runtime = "bun" | "node";

let cachedRuntime: Runtime | null = null;

export function detectRuntime(): Runtime {
  if (cachedRuntime) return cachedRuntime;
  
  if (typeof process !== "undefined" && process.versions?.bun) {
    cachedRuntime = "bun";
  } else {
    cachedRuntime = "node";
  }
  
  return cachedRuntime;
}

export function isBun(): boolean {
  return detectRuntime() === "bun";
}

export function isNode(): boolean {
  return detectRuntime() === "node";
}

export async function sleep(ms: number): Promise<void> {
  if (isBun()) {
    await Bun.sleep(ms);
  } else {
    await new Promise(resolve => setTimeout(resolve, ms));
  }
}

export function getPlatform(): { os: string; arch: string; runtime: Runtime } {
  return {
    os: process.platform,
    arch: process.arch,
    runtime: detectRuntime()
  };
}
