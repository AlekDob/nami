import type { Agent } from '../agent/agent.js';
import type { Scheduler } from '../scheduler/cron.js';
import type { SoulLoader } from '../soul/soul.js';
import { validateAuth } from './auth.js';
import { handleRoute } from './routes.js';
import { handleUpgrade, wsHandlers, setAgent, setSessions } from './websocket.js';
import { SessionStore } from '../sessions/store.js';

export interface ApiServerConfig {
  agent: Agent;
  scheduler: Scheduler;
  soul: SoulLoader;
  port: number;
  dataDir?: string;
}

export function startApiServer(config: ApiServerConfig): void {
  const { agent, scheduler, soul, port, dataDir } = config;

  const sessions = new SessionStore(dataDir || './data');
  sessions.init().catch(e => console.error('[Sessions] init failed:', e));

  const ctx = { agent, scheduler, soul, sessions };

  setAgent(agent);
  setSessions(sessions);

  Bun.serve({
    port,
    maxRequestBodySize: 10 * 1024 * 1024, // 10 MB for image uploads
    fetch(req, server) {
      // CORS preflight
      if (req.method === 'OPTIONS') {
        return new Response(null, {
          status: 204,
          headers: corsHeaders(),
        });
      }

      // WebSocket upgrade
      const url = new URL(req.url);
      if (url.pathname === '/ws') {
        const resp = handleUpgrade(req, server);
        return resp || undefined;
      }

      // Health check (no auth)
      if (url.pathname === '/api/health') {
        return new Response(
          JSON.stringify({ ok: true }),
          { headers: { 'Content-Type': 'application/json' } },
        );
      }

      // Creation preview (no auth for Safari/browser access)
      if (url.pathname.match(/^\/api\/creations\/[^\/]+\/preview$/)) {
        return handleRoute(req, ctx).then((resp) => {
          const newHeaders = new Headers(resp.headers);
          for (const [k, v] of Object.entries(corsHeaders())) {
            newHeaders.set(k, v);
          }
          return new Response(resp.body, {
            status: resp.status,
            headers: newHeaders,
          });
        });
      }

      // Auth check for all other API routes
      if (!validateAuth(req)) {
        return new Response(
          JSON.stringify({ error: 'Unauthorized', code: 401 }),
          {
            status: 401,
            headers: { 'Content-Type': 'application/json' },
          },
        );
      }

      return handleRoute(req, ctx).then((resp) => {
        // Add CORS headers to all responses
        const newHeaders = new Headers(resp.headers);
        for (const [k, v] of Object.entries(corsHeaders())) {
          newHeaders.set(k, v);
        }
        return new Response(resp.body, {
          status: resp.status,
          headers: newHeaders,
        });
      });
    },
    websocket: wsHandlers,
  });

  console.log('  API server listening on port ' + port);
}

function corsHeaders(): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}
