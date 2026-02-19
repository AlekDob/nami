---
type: bug
status: fixed
date: 2026-02-05
severity: medium
tags: [api, auth, safari, macos]
---

# Bug: Preview Endpoint Returns 401 When Opened in Safari

## Problema

Quando l'utente clicca su una creation nella sezione OS dell'app, Safari si apre ma mostra:
```json
{"error":"Unauthorized","code":401}
```

## Causa

L'endpoint `/api/creations/:id/preview` richiede autenticazione Bearer token, ma Safari non ha accesso al token (stored in-app).

## Soluzione

Aggiunta eccezione nel middleware auth in `src/api/server.ts` per permettere accesso pubblico al preview endpoint:

```typescript
// Creation preview (no auth for Safari/browser access)
if (url.pathname.match(/^\/api\/creations\/[^\/]+\/preview$/)) {
  return handleRoute(req, ctx).then((resp) => {
    const newHeaders = new Headers(resp.headers);
    for (const [k, v] of Object.entries(corsHeaders())) {
      newHeaders.set(k, v);
    }
    return new Response(resp.body, { status: resp.status, headers: newHeaders });
  });
}
```

## Considerazioni Sicurezza

**Pro:** UX migliore, creations sono gia' public-facing (app HTML standalone)
**Contro:** Chiunque con l'URL puo' vedere la preview (ID e' UUID, difficile da indovinare)

**Mitigazioni possibili (future):** Token temporaneo nel query string, rate limiting per IP, user-specific creations.

Per ora, trattandosi di un server single-user, il rischio e' accettabile.

## Files Changed

- `/root/meow/src/api/server.ts` - aggiunta eccezione auth
