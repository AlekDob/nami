# Implementation Plan: Second Brain UI

## Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│                    NamiOS App                         │
│                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐ │
│  │  Brain Tab  │  │  Graph View │  │  Tag Manager │ │
│  │  (List)     │  │  (Canvas)   │  │  (Sheet)     │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬───────┘ │
│         │                │                │          │
│  ┌──────┴────────────────┴────────────────┴───────┐  │
│  │              BrainViewModel (@Observable)       │  │
│  │  entries: [KnowledgeEntry]                      │  │
│  │  tags: [TagInfo]                                │  │
│  │  graphNodes: [GraphNode]                        │  │
│  │  graphEdges: [GraphEdge]                        │  │
│  └──────────────────┬─────────────────────────────┘  │
│                     │                                │
│  ┌──────────────────┴─────────────────────────────┐  │
│  │          MeowAPIClient (REST)                   │  │
│  │  GET /api/knowledge                             │  │
│  │  GET /api/knowledge/:id                         │  │
│  │  GET /api/tags                                  │  │
│  │  PATCH /api/knowledge/:id/tags                  │  │
│  │  PATCH /api/tags/:id/rename                     │  │
│  │  POST /api/tags/merge                           │  │
│  │  DELETE /api/tags/:id                           │  │
│  └──────────────────┬─────────────────────────────┘  │
│                     │                                │
│  ┌──────────────────┴─────────────────────────────┐  │
│  │          SwiftData Cache (Offline)              │  │
│  │  CachedKnowledge, CachedTag                    │  │
│  └────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
           │
           │ HTTPS
           ▼
┌──────────────────────────────────────────────────────┐
│              Hetzner Server (Bun)                     │
│                                                      │
│  src/api/routes.ts  ←  new /api/knowledge endpoints  │
│         │                                            │
│  src/memory/store.ts  ←  existing CRUD methods       │
│         │                                            │
│  src/memory/indexer.ts  ←  SQLite knowledge + tags   │
└──────────────────────────────────────────────────────┘
```

## Server-Side: New REST Endpoints

### New file: `src/api/knowledge-routes.ts`

| Method | Path | Description | Response |
|--------|------|-------------|----------|
| GET | `/api/knowledge` | List entries (paginated) | `{ entries: KnowledgeEntry[], total: number }` |
| GET | `/api/knowledge/:id` | Single entry detail | `KnowledgeEntry` |
| GET | `/api/knowledge/graph` | Graph data (nodes + edges) | `{ nodes: GraphNode[], edges: GraphEdge[] }` |
| PATCH | `/api/knowledge/:id/tags` | Update tags on entry | `{ success: true, tags: string[] }` |
| GET | `/api/tags` | All tags with count | `{ tags: TagInfo[] }` |
| PATCH | `/api/tags/:name/rename` | Rename tag | `{ success: true }` |
| POST | `/api/tags/merge` | Merge two tags | `{ success: true }` |
| DELETE | `/api/tags/:name` | Delete tag | `{ success: true }` |

**Query params for GET /api/knowledge:**
- `q` — search query (FTS5)
- `tags` — comma-separated tag filter
- `limit` — max results (default 50)
- `offset` — pagination offset
- `sort` — `recent` (default) | `score`

**Graph endpoint computes edges server-side**: per ogni coppia di entries che condividono almeno 1 tag, crea un edge con weight = numero di tag condivisi. Più efficiente che calcolare lato client.

### Server changes needed in `src/memory/indexer.ts`:

New methods:
- `listKnowledge(query?, tags?, limit, offset)` — paginated list with total count
- `getGraphData(limit?)` — returns nodes (id, title, sourceType, tags, createdAt) + edges (source, target, weight, sharedTags)
- `renameTag(oldName, newName)` — update tag name across all entries
- `mergeTags(keepTag, mergeTag)` — merge entries from mergeTag into keepTag, delete mergeTag
- `deleteTag(name)` — remove tag and all associations

---

## Client-Side: SwiftUI Architecture

### File Structure (iOS App)

```
Sources/Features/Brain/
├── BrainTab.swift              # Tab container (list ↔ graph toggle)
├── BrainListView.swift         # Knowledge entries list + search
├── BrainDetailView.swift       # Entry detail with markdown + tag editor
├── BrainGraphView.swift        # Force-directed graph (Canvas)
├── BrainViewModel.swift        # @Observable state management
├── TagManagerSheet.swift       # Tag list + rename/merge/delete
├── TagChip.swift               # Reusable colored tag chip
├── GraphPhysics.swift          # Force-directed simulation engine
└── GraphNode.swift             # Node/Edge models for graph
```

### Key Design Decisions

**1. Force-Directed Graph: Custom Canvas Implementation**

No third-party libraries. Use SwiftUI `Canvas` with `TimelineView` for 60fps physics:

```
TimelineView(.animation) { timeline in
  Canvas { context, size in
    // Draw edges (lines with thickness = weight)
    // Draw nodes (circles with color = sourceType)
    // Draw labels (title, truncated)
  }
}
.gesture(MagnificationGesture + DragGesture)
```

Physics engine in `GraphPhysics.swift`:
- **Repulsion**: All nodes repel each other (Coulomb's law, `F = k / d²`)
- **Attraction**: Connected nodes attract (Hooke's law, `F = -k * d`)
- **Centering**: Light force towards center prevents drift
- **Damping**: Velocity *= 0.95 each frame (settles over time)
- **Cooling**: Reduce forces over time to reach equilibrium
- **Dragging**: User drag overrides position, neighbors adjust in real-time

**2. Tag Color Generation**

Deterministic color from tag name hash:

```swift
extension String {
    var tagColor: Color {
        let hash = self.utf8.reduce(0) { $0 &+ UInt64($1) &* 31 }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.85)
    }
}
```

**3. SourceType Icons**

```swift
enum SourceType: String, Codable {
    case note, link, concept, quote

    var icon: String {
        switch self {
        case .note: "doc.text"
        case .link: "link"
        case .concept: "lightbulb"
        case .quote: "quote.bubble"
        }
    }
}
```

**4. Offline-First with SwiftData**

```swift
@Model class CachedKnowledge {
    @Attribute(.unique) var id: String
    var title: String
    var summary: String
    var content: String
    var sourceType: String
    var sourceUrl: String?
    var tags: [String]  // stored as JSON
    var createdAt: Date
    var updatedAt: Date
    var lastSyncedAt: Date
}
```

On app launch: load from SwiftData → display immediately → fetch from API → merge.

**5. List ↔ Graph Toggle**

```swift
// BrainTab.swift
@State private var viewMode: ViewMode = .list  // .list | .graph

Picker("", selection: $viewMode) {
    Image(systemName: "list.bullet").tag(ViewMode.list)
    Image(systemName: "circle.grid.3x3.fill").tag(ViewMode.graph)
}
.pickerStyle(.segmented)
```

Transition: `matchedGeometryEffect` per animare i nodi dalla posizione lista alla posizione grafo (300ms).

---

## Data Flow

### Search Flow
```
User types "react"
  → BrainViewModel.search(query: "react")
    → MeowAPIClient.searchKnowledge(q: "react")
      → GET /api/knowledge?q=react
        → indexer.listKnowledge(query: "react")
          → knowledge_fts MATCH "react"
    → Update entries[] → List re-renders
```

### Tag Filter Flow
```
User taps tag "typescript"
  → BrainViewModel.toggleTag("typescript")
    → selectedTags.toggle("typescript")
    → MeowAPIClient.searchKnowledge(tags: "typescript")
      → GET /api/knowledge?tags=typescript
    → Update entries[] + graphNodes[]
```

### Graph Data Flow
```
BrainTab switches to .graph
  → BrainViewModel.loadGraph()
    → MeowAPIClient.fetchGraph()
      → GET /api/knowledge/graph
        → indexer.getGraphData()
          → SQL: find all tag overlaps between entries
    → graphNodes[] = response.nodes
    → graphEdges[] = response.edges
    → GraphPhysics.start() → 60fps simulation
```

---

## API Models (Shared Types)

### Server → Client (JSON)

```typescript
// GET /api/knowledge response
interface KnowledgeListResponse {
  entries: KnowledgeEntry[];
  total: number;
}

// GET /api/knowledge/graph response
interface GraphResponse {
  nodes: Array<{
    id: string;
    title: string;
    sourceType: 'note' | 'link' | 'concept' | 'quote';
    tags: string[];
    createdAt: string;
  }>;
  edges: Array<{
    source: string;  // node id
    target: string;  // node id
    weight: number;  // shared tag count
    sharedTags: string[];
  }>;
}

// GET /api/tags response
interface TagListResponse {
  tags: Array<{
    name: string;
    count: number;
  }>;
}
```

---

## Performance Considerations

1. **Graph limit**: Default 100 nodes max. Server paginates, client shows "Load more" button.
2. **Physics pausing**: After 5 seconds of no interaction, pause simulation (save CPU).
3. **Canvas vs SwiftUI Views**: Canvas is MANDATORY for graph — individual SwiftUI views per node would cause layout death.
4. **Tag colors cached**: Compute once per tag, store in dictionary.
5. **Search debounce**: 500ms before API call.
6. **SwiftData background sync**: Fetch API on background thread, merge on main.
