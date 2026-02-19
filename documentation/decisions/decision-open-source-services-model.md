---
date: 2026-02-05
type: decision
status: approved
tags: [business-model, open-source, monetization]
---

# Decision: Open Source + Services Business Model

## Contesto

NamiOS deve diventare distribuibile. Valutati tre modelli di business.

## Opzioni Considerate

### A) SaaS (Tu Hosti)
- Revenue: subscription, controllo totale
- Contro: Costi infra, scalabilita', support burden

### B) Freemium Self-Hosted
- Revenue: tier pro con features gated
- Contro: License system da mantenere, bypass possibile

### C) Open Source + Services (SCELTO)
- Core: 100% codice pubblico (MIT)
- Revenue: Consulenza, setup, managed hosting, training
- Pro: Trust massimo, community, niente pirateria

## Decisione

**Opzione C: Open Source + Services**

## Rationale

1. **Trust:** Codice trasparente = niente "che fanno con i miei dati?"
2. **Community:** Contributi esterni, bug fix gratis, evangelisti
3. **Skillset:** Alek e' gia' consulente (EUR500/h), sa vendere servizi
4. **Mercato:** Italia non ha un "OpenClaw nostrano"
5. **Differenziatore:** App iOS nativa (OpenClaw ha solo CLI)

## Revenue Streams

| Stream | Prezzo | Target |
|--------|--------|--------|
| Setup assistito | EUR200-500 | Chi non vuole smanettare |
| Consulenza oraria | EUR150-500/h | Customizzazioni |
| Managed hosting | EUR50-200/mese | Chiavi in mano |
| Training/Workshop | EUR500-2000 | Aziende, team |
| Custom features | EUR1000-5000 | Esigenze specifiche |

## Conseguenze

- GitHub repo pubblico con MIT license
- Documentazione eccellente obbligatoria
- Landing page namios.ai con `/services`
- Discord community per support gratuito
