---
type: pattern
tags: [npm, versioning, publishing, workflow]
date: 2026-02-05
---

# NPM Versioning Workflow

GitHub e npm registry sono **sistemi separati**. Aggiornare il codice su GitHub NON aggiorna automaticamente il package npm.

## Workflow Completo

```bash
# 1. Fai le modifiche al codice
# 2. Bump versione
npm version patch   # 1.0.0 → 1.0.1 (bugfix)
npm version minor   # 1.0.0 → 1.1.0 (nuove feature)
npm version major   # 1.0.0 → 2.0.0 (breaking changes)
# 3. Pubblica su npm
npm publish
# 4. Sync GitHub
git push && git push --tags
```

## Due Modi per Installare

| Metodo | Comando | Sorgente | Aggiornamento |
|--------|---------|----------|---------------|
| npm registry | `npx package@latest` | npm | Richiede `npm publish` |
| GitHub direct | `npx github:user/repo` | GitHub | Automatico |

- **Sviluppo/Testing**: `npx github:user/repo` — prende sempre ultimo commit
- **Produzione/Release**: `npx package@latest` — versione stabile verificata

## Gotchas

1. **`npm version` crea un git tag** — ricorda di pushare i tags
2. **npm cache** — utenti potrebbero avere versione cachata, aspetta qualche minuto
3. **Scoped packages** (`@org/package`) richiedono `--access public` al primo publish
4. **2FA** — npm potrebbe richiedere OTP se hai 2FA abilitato
