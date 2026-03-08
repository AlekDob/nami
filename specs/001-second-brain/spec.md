# Feature Specification: Second Brain UI

**Feature Branch**: `001-second-brain`
**Created**: 2026-02-28
**Status**: Draft
**Input**: UI Second Brain per NamiOS con tagging intelligente e graph view tipo Obsidian

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Knowledge Feed (Priority: P1)

L'utente apre la tab "Brain" e vede tutte le knowledge entries salvate da Nami, organizzate cronologicamente con tag colorati. Può cercare per testo o filtrare per tag. Toccando una entry, vede il dettaglio completo con contenuto, source URL (se link), e tag editabili.

**Why this priority**: È il MVP — senza una UI per vedere e cercare le knowledge entries, il Second Brain è invisibile. L'utente non sa cosa Nami ha salvato.

**Independent Test**: Aprire la tab Brain → vedere almeno le entries salvate via chat → cercare "typescript" → trovare entries taggata → toccare per dettaglio.

**Acceptance Scenarios**:

1. **Given** il knowledge base ha 10+ entries, **When** l'utente apre la tab Brain, **Then** vede una lista cronologica (più recenti prima) con titolo, summary one-liner, tag chips colorati, e icona sourceType (🔗 link, 📝 note, 💡 concept, 💬 quote)
2. **Given** l'utente digita "react" nella search bar, **When** preme invio/dopo 500ms debounce, **Then** i risultati si filtrano mostrando solo entries che matchano per titolo, contenuto o summary
3. **Given** l'utente tocca un tag chip "typescript", **When** il filtro si attiva, **Then** solo entries con quel tag sono visibili, e il chip appare "selezionato" nella barra filtri
4. **Given** l'utente tocca una entry, **When** si apre il detail view, **Then** vede: titolo, contenuto completo (markdown rendered), source URL cliccabile (se link), data creazione, e tag editabili (add/remove)

---

### User Story 2 — Knowledge Graph (Priority: P2)

L'utente può passare dalla vista lista alla vista grafo. Il grafo mostra le knowledge entries come nodi e i tag condivisi come connessioni. I nodi si raggruppano per tag, creando cluster visivi. L'utente può zoomare, pannare, e toccare un nodo per vedere il dettaglio.

**Why this priority**: Il graph è il differentiatore "wow" — è ciò che rende il Second Brain *visivo* come Obsidian. Ma è secondario perché la lista è più pratica per l'uso quotidiano.

**Independent Test**: Switch alla graph view → vedere nodi colorati per sourceType → pinch-to-zoom → toccare un nodo → vedere il dettaglio → notare che entries con tag in comune sono connesse da linee.

**Acceptance Scenarios**:

1. **Given** ci sono 20+ entries, **When** l'utente attiva la graph view, **Then** vede nodi circolari posizionati con force-directed layout, dove nodi con tag condivisi sono più vicini
2. **Given** il grafo è visibile, **When** l'utente fa pinch-to-zoom (iOS) o scroll (macOS), **Then** il grafo si scala fluidamente a 60fps
3. **Given** il grafo è visibile, **When** l'utente tocca un nodo, **Then** il nodo si evidenzia, le connessioni si illuminano, e appare un popover con titolo + summary + azione "Apri dettaglio"
4. **Given** il grafo mostra connessioni, **When** due entries condividono 2+ tag, **Then** la linea di connessione è più spessa (peso proporzionale ai tag condivisi)
5. **Given** il grafo è visibile, **When** l'utente tocca un tag chip nel filtro, **Then** solo i nodi con quel tag restano visibili (gli altri si offuscano con opacità 0.15)

---

### User Story 3 — Tag Management (Priority: P2)

L'utente può vedere tutti i tag esistenti, la loro frequenza d'uso, e gestirli: rinominare, unire (merge) due tag simili, eliminare tag orfani. Dalla barra tag può selezionare multipli per filtri combinati (AND).

**Why this priority**: Senza gestione tag, il sistema accumula tag duplicati/simili ("react" vs "reactjs" vs "React") e diventa inutilizzabile nel tempo.

**Independent Test**: Aprire tag manager → vedere lista tag con conteggio → selezionare "reactjs" → rinominare in "react" → verificare che tutte le entries aggiornano il tag.

**Acceptance Scenarios**:

1. **Given** ci sono 30+ tag, **When** l'utente apre il tag manager, **Then** vede lista tag ordinata per frequenza d'uso (count) con mini barra percentuale
2. **Given** l'utente seleziona un tag, **When** sceglie "Rinomina", **Then** può digitare il nuovo nome e tutte le entries si aggiornano
3. **Given** l'utente seleziona due tag, **When** sceglie "Unisci", **Then** il secondo tag viene merged nel primo e rimosso
4. **Given** esistono tag senza entries, **When** l'utente vede "Tag orfani" section, **Then** può eliminarli con swipe o bulk delete

---

### User Story 4 — Quick Save da Chat (Priority: P3)

Quando Nami salva automaticamente una knowledge entry durante una chat, appare una notifica inline nel messaggio ("💾 Salvato in Brain: [titolo]") con un link diretto alla entry. L'utente può toccare per editare tag o contenuto subito.

**Why this priority**: Chiude il loop — l'utente vede in tempo reale cosa Nami salva e può correggerlo immediatamente, migliorando la qualità del knowledge base nel tempo.

**Independent Test**: Mandare un URL a Nami via chat → vedere la conferma inline "Salvato in Brain" → toccare → arrivare al dettaglio → modificare un tag.

**Acceptance Scenarios**:

1. **Given** Nami salva una entry durante il chat, **When** il messaggio di risposta arriva, **Then** contiene un blocco "Brain: [titolo] [tag1, tag2]" con link diretto
2. **Given** l'utente tocca il link "Brain", **When** la navigazione avviene, **Then** si apre il detail view della entry appena salvata

---

### Edge Cases

- Cosa succede con 0 entries? → Empty state con illustrazione + CTA "Condividi qualcosa con Nami per iniziare"
- Cosa succede con 500+ entries nel grafo? → Clustering automatico: mostra solo i 50 nodi più recenti/rilevanti, con opzione "Mostra tutto"
- Cosa succede se il server è offline? → SwiftData cache locale, label "Offline — dati cached" con timestamp ultimo sync
- Cosa succede con tag molto lunghi? → Trunca a 20 caratteri con ellipsis nel chip, full name nel tooltip/long-press
- Cosa succede su macOS con trackpad? → Scroll = pan, pinch = zoom, click = select, right-click = context menu

## Clarifications

### Q1: Tab Brain vs Memory?
**Risposta**: Due tab separate. Memory resta per daily log/MEMORY.md. Brain è la nuova tab per knowledge entries + graph.

### Q2: Livello interattività graph?
**Risposta**: Dinamico con fisica — nodi si muovono in tempo reale, drag singolo nodo, simulazione fisica continua. Massimo wow factor.

### Q3: API server?
**Risposta**: Nuovi endpoint REST dedicati (GET /api/knowledge, GET /api/tags, PATCH, ecc.). La UI chiama direttamente, non passa dal chat.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Il sistema DEVE mostrare una lista scrollabile di knowledge entries con titolo, summary, tag, sourceType icon, e data creazione
- **FR-002**: Il sistema DEVE supportare ricerca full-text su titolo, contenuto e summary con debounce 500ms
- **FR-003**: Il sistema DEVE permettere il filtro per tag singolo o multiplo (AND logic)
- **FR-004**: Il sistema DEVE mostrare un grafo interattivo con nodi (entries) e edge (tag condivisi)
- **FR-005**: Il grafo DEVE usare un algoritmo force-directed per posizionare i nodi
- **FR-006**: Il sistema DEVE permettere zoom (pinch/scroll) e pan (drag) sul grafo a 60fps
- **FR-007**: Il sistema DEVE mostrare il dettaglio di una entry con contenuto markdown renderizzato
- **FR-008**: Il sistema DEVE permettere di aggiungere/rimuovere tag da una entry
- **FR-009**: Il sistema DEVE supportare rinomina e merge tag
- **FR-010**: Il sistema DEVE funzionare offline con cache SwiftData, sincronizzando quando il server torna disponibile
- **FR-011**: Il sistema DEVE adattarsi a iOS (touch, full-screen) e macOS (keyboard+mouse, split view)
- **FR-012**: Il sistema DEVE mostrare un empty state quando non ci sono entries

### Non-Functional Requirements

- **NFR-001**: Il grafo deve renderizzare a 60fps con 100 nodi su iPhone 15
- **NFR-002**: La ricerca deve tornare risultati in <500ms
- **NFR-003**: Il transition lista↔grafo deve essere animato (300ms)
- **NFR-004**: I colori tag devono essere deterministici (stesso tag = stesso colore, generato dall'hash del nome)

### Key Entities

- **KnowledgeEntry**: Una unità di conoscenza salvata (titolo, contenuto, summary, sourceUrl?, sourceType, tag[], createdAt, updatedAt). Corrisponde alla tabella `knowledge` del server SQLite.
- **Tag**: Un'etichetta normalizzata (lowercase, singular) associata a una o più entries. Corrisponde alla tabella `tags` del server SQLite.
- **GraphNode**: Rappresentazione visiva di una KnowledgeEntry nel grafo (posizione x/y, velocità, colore derivato da sourceType).
- **GraphEdge**: Connessione tra due nodi che condividono almeno un tag. Peso = numero di tag condivisi.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: L'utente può trovare una entry specifica in <10 secondi (search + tap)
- **SC-002**: Il grafo mostra relazioni tra entries che l'utente non avrebbe scoperto dalla lista (serendipity)
- **SC-003**: Il grafo renderizza fluidamente (>55fps) con 100 nodi su hardware target
- **SC-004**: 100% delle entries salvate via chat sono visibili nella UI Brain entro 2 secondi dal salvataggio
