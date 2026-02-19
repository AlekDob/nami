---
date: 2026-02-05
type: decision
title: Repository Separation - Backend Public, App Private
status: implemented
---

# Decision: Separare Backend (Open Source) da App Swift (Privata)

## Contesto

NamiOS ha due componenti: Backend TypeScript (server Bun) e App SwiftUI (client iOS/macOS). Backend open source per community e trust, app Swift privata per collaboratori/clienti.

## Opzioni Valutate

### A) Due Repository Separate (SCELTA)
```
github.com/AlekDob/nami       (PUBLIC)  - Backend
github.com/AlekDob/namios-app (PRIVATE) - App Swift
```
Pro: Controllo granulare permessi, backend completamente open, app protetta

### B) Monorepo con Submodule Privato
Contro: Submodules complicati, confusione per contributor

### C) Cartella Esclusa in Monorepo
Non possibile — GitHub non supporta parti private in repo pubbliche.

## Decisione

**Opzione A: Due repository separate.**

## Benefici

| Aspetto | Vantaggio |
|---------|-----------|
| Trust | Backend trasparente |
| Protezione IP | UX proprietaria non copiabile |
| App Store | Puo' pubblicare senza esporre codice |
| Monetizzazione | Accesso app = feature premium |
| Community | Puo' contribuire al backend |

## Commits

- Backend pubblico: `bf9a0b5` (rimosso MeowApp/, aggiornato README)
- App privata: `ee8d283` (commit iniziale, 12,212 righe Swift)

## Links

- Backend: https://github.com/AlekDob/nami
- App (privata): https://github.com/AlekDob/namios-app
