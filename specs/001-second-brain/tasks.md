# Implementation Tasks: Second Brain UI

## Phase 1: Server API (Backend)

- [ ] 1.1 Add knowledge REST endpoints to server
  - Create `src/api/knowledge-routes.ts` with GET /api/knowledge, GET /api/knowledge/:id, GET /api/knowledge/graph
  - Add PATCH /api/knowledge/:id/tags
  - Register routes in `src/api/routes.ts`
  - All endpoints require Bearer auth (reuse existing `verifyAuth`)
  - **Depends on**: None (Second Brain tables already exist from earlier work)
  - **Requirement**: FR-001, FR-002, FR-003, FR-004, FR-007

- [ ] 1.2 [P] Add tag management endpoints
  - GET /api/tags — list tags with count
  - PATCH /api/tags/:name/rename — rename tag
  - POST /api/tags/merge — merge two tags
  - DELETE /api/tags/:name — delete tag and associations
  - **Depends on**: None
  - **Requirement**: FR-009

- [ ] 1.3 Add graph data computation to indexer
  - New method `getGraphData(limit)` on MemoryIndexer
  - SQL: for each pair of entries sharing ≥1 tag, compute edge with weight + sharedTags
  - New method `listKnowledge(query?, tags?, limit, offset)` with total count
  - New methods: `renameTag`, `mergeTags`, `deleteTag`
  - **Depends on**: None
  - **Requirement**: FR-004, FR-005, FR-009

- [ ] 1.4 Deploy and verify server endpoints
  - scp files to server, restart nami service
  - Test each endpoint via curl
  - **Depends on**: 1.1, 1.2, 1.3

## Phase 2: iOS Models & API Client

- [ ] 2.1 Add Swift models for knowledge data
  - `KnowledgeEntry` Codable struct (mirrors server JSON)
  - `TagInfo` struct (name + count)
  - `GraphData` struct (nodes + edges)
  - `SourceType` enum with icon property
  - Add to `Sources/Core/Network/APITypes.swift` or new file if too large
  - **Depends on**: 1.4 (need final API shape)
  - **Requirement**: FR-001

- [ ] 2.2 [P] Add MeowAPIClient methods for knowledge
  - `fetchKnowledge(query?, tags?, limit, offset)` → KnowledgeListResponse
  - `fetchKnowledgeDetail(id)` → KnowledgeEntry
  - `fetchGraph(limit?)` → GraphData
  - `updateTags(entryId, add, remove)` → success
  - `fetchTags()` → [TagInfo]
  - `renameTag(name, newName)`, `mergeTags(keep, merge)`, `deleteTag(name)`
  - **Depends on**: 2.1
  - **Requirement**: FR-001, FR-002, FR-003

- [ ] 2.3 [P] Add SwiftData cache models
  - `CachedKnowledge` @Model with all fields + lastSyncedAt
  - `CachedTag` @Model with name + count
  - Offline fallback: load from cache when API fails
  - **Depends on**: 2.1
  - **Requirement**: FR-010

## Phase 3: Brain List View (P1 — MVP)

- [ ] 3.1 Create BrainViewModel
  - @Observable class with entries[], tags[], selectedTags, searchQuery, isLoading, error
  - Methods: loadEntries(), search(query), toggleTag(name), loadTags()
  - Debounced search (500ms via Task.sleep)
  - SwiftData fallback on API error
  - **Depends on**: 2.2, 2.3
  - **Requirement**: FR-001, FR-002, FR-003, FR-010

- [ ] 3.2 Create TagChip reusable component
  - Small rounded rect with deterministic color from tag name hash
  - Selected/unselected states (filled vs outlined)
  - Tap handler for toggle
  - Long-press for tag info popover
  - **Depends on**: None (pure UI)
  - **Requirement**: NFR-004

- [ ] 3.3 [P] Create BrainListView
  - Search bar at top
  - Horizontal scroll of tag chips (filter bar)
  - List of entries: SourceType icon + title + summary + tag chips + relative date
  - Pull-to-refresh
  - Empty state with illustration
  - Tap → push BrainDetailView
  - **Depends on**: 3.1, 3.2
  - **Requirement**: FR-001, FR-002, FR-003, FR-012

- [ ] 3.4 [P] Create BrainDetailView
  - Title (editable?)
  - Content rendered as markdown (reuse MarkdownText)
  - Source URL as tappable link (if sourceType == link)
  - Tag editor: existing tags as chips + add new tag input
  - Remove tag via X button on chip
  - CreatedAt / UpdatedAt dates
  - **Depends on**: 3.1, 3.2
  - **Requirement**: FR-007, FR-008

- [ ] 3.5 Create BrainTab and register in ContentView
  - Container view with segmented picker (list | graph)
  - Add `.brain` case to AppTab enum
  - Add brain icon (brain.head.profile) to sidebar
  - Initialize BrainViewModel in ContentView.onAppear
  - **Depends on**: 3.3, 3.4
  - **Requirement**: FR-011

## Phase 4: Knowledge Graph (P2)

- [ ] 4.1 Create GraphPhysics engine
  - Force-directed simulation: repulsion (Coulomb), attraction (Hooke), centering, damping
  - GraphNode struct: id, position (CGPoint), velocity (CGVector), title, sourceType, tags
  - GraphEdge struct: source, target, weight, sharedTags
  - Timer-based update loop (displayLink equivalent via TimelineView)
  - Cooling function: reduce forces over 5 seconds to reach equilibrium
  - Pause after inactivity, resume on interaction
  - **Depends on**: None (pure algorithm)
  - **Requirement**: FR-005, NFR-001

- [ ] 4.2 Create BrainGraphView
  - SwiftUI Canvas rendering nodes + edges
  - Nodes: circles colored by sourceType, size proportional to tag count
  - Edges: lines with thickness = weight, semi-transparent
  - Labels: truncated title below each node
  - MagnificationGesture for zoom, DragGesture for pan
  - Tap detection: find node nearest to tap point
  - Node drag: override position, physics adjusts neighbors
  - Selected node: highlight + connected edges glow
  - **Depends on**: 4.1
  - **Requirement**: FR-004, FR-006, NFR-001, NFR-003

- [ ] 4.3 Add node tap → detail navigation
  - Tap node → show popover with title + summary + "Open" button
  - "Open" pushes BrainDetailView
  - Tag filter from graph: tap tag in popover → filter graph to that tag
  - macOS: right-click context menu on nodes
  - **Depends on**: 4.2, 3.4
  - **Requirement**: FR-004

- [ ] 4.4 Graph ↔ List transition animation
  - When switching viewMode, animate nodes from list Y-positions to graph positions (or vice versa)
  - Use matchedGeometryEffect or custom transition
  - 300ms spring animation
  - **Depends on**: 4.2, 3.3
  - **Requirement**: NFR-003

## Phase 5: Tag Manager (P2)

- [ ] 5.1 Create TagManagerSheet
  - Present as .sheet from Brain tab
  - List all tags ordered by frequency (count)
  - Each row: tag chip + count + mini usage bar
  - "Orphan tags" section at bottom
  - **Depends on**: 3.1
  - **Requirement**: FR-009

- [ ] 5.2 Add tag rename/merge/delete actions
  - Swipe actions: rename, delete
  - Multi-select mode for merge (select 2 → "Merge" button)
  - Rename: alert with text field → API call → reload
  - Merge: confirmation dialog → API call → reload
  - Delete orphans: bulk delete button
  - **Depends on**: 5.1
  - **Requirement**: FR-009

## Phase 6: Polish & Platform Adaptation

- [ ] 6.1 macOS layout adaptation
  - Graph: scroll = zoom, trackpad pinch = zoom, drag = pan
  - List: wider rows, keyboard navigation
  - Detail: side-by-side with list (NavigationSplitView)
  - Disable spring animations on macOS (per constitution)
  - **Depends on**: 4.2, 3.5
  - **Requirement**: FR-011

- [ ] 6.2 [P] Performance optimization
  - Graph: cap at 100 nodes default, "Show all" button for more
  - Canvas: skip drawing off-screen nodes
  - Physics: pause after 5s inactivity
  - Tag colors: cache in dictionary
  - Search: verify <500ms response time
  - **Depends on**: 4.2
  - **Requirement**: NFR-001, NFR-002

- [ ] 6.3 [P] Accessibility
  - VoiceOver labels on graph nodes (title + tag count)
  - Accessibility actions: "Open detail", "Filter by tag"
  - Dynamic Type support in list view
  - Reduce Motion: skip graph animation, show static layout
  - **Depends on**: 4.2, 3.3
  - **Requirement**: Quality Gate (constitution)

## Notes

- `[P]` indicates tasks that can be parallelized with siblings
- Phase 1 (server) blocks Phase 2 (iOS models) which blocks Phase 3 (UI)
- Phase 4 (graph) can start in parallel with Phase 3 task 3.3 once 4.1 (physics engine) is done
- Phase 5 (tag manager) depends only on Phase 3 ViewModel
- Phase 6 (polish) is the last mile
