import { connect, type ClientHttp2Session } from 'node:http2';
import { createSign } from 'node:crypto';
import { readFile, writeFile, mkdir } from 'fs/promises';
import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';

interface APNsConfig {
  keyPath: string;
  keyId: string;
  teamId: string;
  bundleId: string;
  production: boolean;
  dataDir: string;
}

interface DeviceEntry {
  token: string;
  registeredAt: string;
}

interface DeviceStore {
  devices: DeviceEntry[];
  version: number;
}

let config: APNsConfig | null = null;
let privateKey: string = '';
let cachedToken: string = '';
let tokenExpiry = 0;
let h2Client: ClientHttp2Session | null = null;

function getApnsHost(prod: boolean): string {
  return prod
    ? 'https://api.push.apple.com'
    : 'https://api.sandbox.push.apple.com';
}

function devicesPath(): string {
  return join(config?.dataDir || '/root/meow/data', 'devices.json');
}

async function loadDevices(): Promise<DeviceStore> {
  const path = devicesPath();
  if (!existsSync(path)) return { devices: [], version: 1 };
  const raw = await readFile(path, 'utf-8');
  return JSON.parse(raw) as DeviceStore;
}

async function saveDevices(store: DeviceStore): Promise<void> {
  const path = devicesPath();
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, JSON.stringify(store, null, 2));
}

function base64url(input: string): string {
  return Buffer.from(input).toString('base64url');
}

function generateJWT(): string {
  if (cachedToken && Date.now() < tokenExpiry) return cachedToken;
  if (!config) throw new Error('APNs not initialized');

  const header = base64url(JSON.stringify({
    alg: 'ES256',
    kid: config.keyId,
  }));
  const claims = base64url(JSON.stringify({
    iss: config.teamId,
    iat: Math.floor(Date.now() / 1000),
  }));

  const signingInput = header + '.' + claims;
  const sign = createSign('SHA256');
  sign.update(signingInput);
  const signature = sign.sign(privateKey, 'base64url');

  cachedToken = signingInput + '.' + signature;
  tokenExpiry = Date.now() + 50 * 60 * 1000;
  return cachedToken;
}

function getH2Client(): ClientHttp2Session {
  if (h2Client && !h2Client.closed && !h2Client.destroyed) {
    return h2Client;
  }
  const host = getApnsHost(config?.production ?? false);
  h2Client = connect(host);
  h2Client.on('error', () => { h2Client = null; });
  h2Client.on('close', () => { h2Client = null; });
  return h2Client;
}

async function sendToDevice(
  token: string,
  payload: string,
): Promise<number> {
  const jwt = generateJWT();
  const client = getH2Client();

  return new Promise((resolve, reject) => {
    const req = client.request({
      ':method': 'POST',
      ':path': '/3/device/' + token,
      'authorization': 'bearer ' + jwt,
      'apns-topic': config?.bundleId ?? '',
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'content-type': 'application/json',
    });

    let status = 0;
    let responseBody = '';
    req.on('response', (headers) => {
      status = (headers[':status'] as number) || 0;
      console.log('[APNs] Response status:', status);
    });
    req.on('data', (chunk: Buffer) => { responseBody += chunk.toString(); });
    req.on('end', () => {
      if (responseBody) console.log('[APNs] Response body:', responseBody);
      resolve(status);
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

export async function initAPNs(cfg: APNsConfig): Promise<void> {
  config = cfg;
  privateKey = await readFile(cfg.keyPath, 'utf-8');
  console.log('  APNs initialized (' + (cfg.production ? 'production' : 'sandbox') + ')');
}

export async function registerDevice(token: string): Promise<void> {
  const store = await loadDevices();
  if (store.devices.some((d) => d.token === token)) return;
  store.devices.push({ token, registeredAt: new Date().toISOString() });
  await saveDevices(store);
}

export async function unregisterDevice(token: string): Promise<void> {
  const store = await loadDevices();
  store.devices = store.devices.filter((d) => d.token !== token);
  await saveDevices(store);
}

export function getDeviceCount(): number {
  const path = devicesPath();
  if (!existsSync(path)) return 0;
  try {
    const raw = readFileSync(path, 'utf-8');
    return (JSON.parse(raw) as DeviceStore).devices.length;
  } catch { return 0; }
}

export async function sendPushNotification(
  title: string,
  body: string,
  sessionId?: string,
): Promise<void> {
  if (!config || !privateKey) return;
  const store = await loadDevices();
  if (store.devices.length === 0) return;

  const payload = JSON.stringify({
    aps: {
      alert: { title, body: body.slice(0, 200) },
      sound: 'default',
      badge: 1,
    },
    sessionId: sessionId ?? null,
  });

  const staleTokens: string[] = [];
  for (const device of store.devices) {
    try {
      const status = await sendToDevice(device.token, payload);
      if (status === 410 || status === 400) {
        staleTokens.push(device.token);
      }
    } catch {
      // Connection error — skip
    }
  }

  if (staleTokens.length > 0) {
    store.devices = store.devices.filter(
      (d) => !staleTokens.includes(d.token),
    );
    await saveDevices(store);
  }
}
