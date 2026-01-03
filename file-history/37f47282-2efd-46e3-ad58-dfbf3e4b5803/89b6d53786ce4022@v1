# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - Sprint January 2026 Complete

> **Branch**: `development` | **Plan**: `docs/plans/done/MasterPlan-v2.1-2026-01-02.md`

### Changed (Jan 3 - Rebrand)

- **Package Rename**: `convergio-edu` → `mirrorbuddy`
- **Source Code**: All headers and comments updated
- **Metrics**: API metric names updated (`convergio_*` → `mirrorbuddy_*`)
- **Documentation**: All ADRs and docs updated with new branding
- **E2E Tests**: Updated to use MirrorBuddy branding

### Added (Jan 3 - Wave 4: Supporti Consolidation)

- **New /supporti page**: Unified material browsing experience
  - Sidebar navigation with collapsible sections (type/subject/maestro)
  - Grid and list view modes with toggle
  - Full-text search with Fuse.js and debouncing
  - URL-based filtering (?type=mindmap&subject=math)
  - Breadcrumb navigation
  - Responsive design (mobile/desktop)
- **Redirect /archivio -> /supporti**: Legacy route preserved
- **Updated navigation**: Main nav shows "Supporti" instead of "Archivio"
- **E2E tests**: 23 tests for supporti page (e2e/supporti.spec.ts)

### Added (Jan 3 - Wave 3: Welcome Experience)

- **Enhanced /welcome page**: Visual landing experience
  - hero-section.tsx with Melissa avatar
  - features-section.tsx with feature cards
  - guides-section.tsx for getting started
  - quick-start.tsx with voice/text options
- **Skip flow**: handleSkipWithConfirmation with user consent
- **Returning user support**: Personalized greeting
- **Replay from settings**: /welcome?replay=true parameter
- **E2E tests**: 18 tests for welcome page (e2e/welcome.spec.ts)

### Fixed (Jan 3 - Wave 1-2: Bug Fixes)

- **P0 Critical (7 fixes)**:
  - C-5: History per Coach/Buddy (not global)
  - C-9: Header Counters real-time update
  - C-12: Mindmap Hierarchy (flat → nested)
  - C-13: Conversation Persistence
  - C-14: Material Save intermittent
  - C-15: Save Material Error handling
  - C-16: Sandbox SecurityError (srcdoc)
- **P1 High (9 fixes)**:
  - C-1: STT Discrepancy fix
  - C-2: Session Recap + Memory
  - C-3: Input/Voice panel sticky
  - C-4: Azure OpenAI Costs display
  - C-7: Demo Accessibility settings
  - C-10: Demo in frame (not new tab)
  - C-11: Triple "Chiamata Terminata" cleanup
  - C-17: Fullscreen on Tool Creation
  - C-18: PDF Parsing Failure
  - C-19: ESC Key Inconsistent
- **P2 Medium (5 fixes)**:
  - C-6: Timer + XP Bar in voice panel
  - C-8: Cafe Ambient Audio (procedural)
  - C-20: Mindmap Interactive (pan/zoom)
  - C-21: Summary Export/Convert/Flashcard

### Added (Jan 3 - Admin Dashboard)

- **Admin Analytics Dashboard** (`/admin/analytics`):
  - Token usage statistics (total tokens, calls, avg per call, estimated cost)
  - Voice metrics (sessions, TTS generations, realtime sessions)
  - Flashcard FSRS stats (cards, reviews, accuracy, cards due)
  - Rate limiting events (total, by endpoint)
  - Safety events (total, by severity, unresolved count)
- **New API Routes**:
  - `GET /api/dashboard/token-usage` - AI token usage stats
  - `GET /api/dashboard/voice-metrics` - Voice session metrics
  - `GET /api/dashboard/fsrs-stats` - Flashcard FSRS statistics
  - `GET /api/dashboard/rate-limits` - Rate limit events
  - `GET /api/dashboard/safety-events` - Safety monitoring data
  - `POST /api/dashboard/safety-events` - Resolve safety events
- **Database Models**:
  - `RateLimitEvent` - Stores rate limit violations
  - `SafetyEvent` - Stores safety monitoring events
- **Persistence Layer**:
  - `src/lib/rate-limit.ts` - Rate limit event logging
  - `src/lib/safety/monitoring.ts` - Safety event persistence

### Fixed (WAVE 0 Critical Bugs)

- **0.1 Tool Creation**: ToolMaestroSelectionDialog in conversation-flow, Maestro ID mismatch fix
- **0.2 Memory System**: InactivityMonitor activated, auto-summary on tab close/maestro switch/voice end
- **0.3 Demo Interattive**: demo-handler registered, CSP img-src for images
- **0.4 Gamification**: Section 7 in system prompts, XP communication to students
- **0.5 Parent Dashboard**: `/genitori` route, consent badge, responsive UI
- **0.6 Focus Layout**: 70/30 split, phone-call style panel, minimized sidebar

### Changed (WAVE 1 Voice Migration)

- **Voice Model**: Migrated from `gpt-4o-realtime-preview` to `gpt-4o-mini-realtime-preview`
- **Hybrid Logic**: MirrorBuddy uses premium tier, all others use mini (80-90% cost savings)
- **Config**: Added `AZURE_OPENAI_REALTIME_DEPLOYMENT_MINI` env var

### Added (WAVE 2 Study Kit Generator)

- **PDF Parsing**: `study-kit-handler.ts` with pdf-parse v2.4.5 API (PDFParse class)
- **Pipeline**: extractTextFromPDF → generateSummary → generateMindmap → generateDemo → generateQuiz
- **API Routes**: `/api/study-kit`, `/api/study-kit/[id]`, `/api/study-kit/upload`
- **UI**: `/study-kit` page with upload, progress, viewer

### Improved (WAVE 3 Tech Debt)

- **Health Endpoint**: `/api/health` for monitoring
- **Rate Limiting**: Base implementation on chat/realtime APIs
- **Caching**: React Query cache for maestri list, settings

### Added

#### Phase 9: Testing & Verification (Tasks 9.01-9.07)
- **E2E Tests**:
  - `e2e/mindmap-hierarchy.spec.ts`: Tests mindmap title field and hierarchy rendering (ADR 0020)
  - `e2e/knowledge-hub.spec.ts`: Tests Knowledge Hub views, search, organization (ADR 0022)
  - `e2e/accessibility-knowledge-hub.spec.ts`: Axe accessibility audit for WCAG 2.1 AA
- **Safety Tests**:
  - `src/lib/safety/__tests__/memory-safety.test.ts`: 27 tests for memory injection attacks
  - `src/lib/safety/__tests__/knowledge-hub-safety.test.ts`: 22 tests for material content safety
- **Integration Tests**:
  - `src/lib/conversation/__tests__/memory-integration.test.ts`: 15 tests for memory flow (ADR 0021)
- **Total New Tests**: 75+ tests covering adversarial inputs, jailbreak prevention, accessibility

#### Phase 10: Documentation (Tasks 10.01-10.11)
- Updated `docs/ARCHITECTURE.md`:
  - Added Conversational Memory section (ADR-0021)
  - Added Knowledge Hub section (ADR-0022)
  - Added Tool Focus Selection section (ADR-0020)
  - Updated ADR count from 18 to 22
  - Updated statistics (1400+ tests, 150+ components)
- Finalized ADRs:
  - ADR 0020: Mindmap Data Structure Fix - Status: Accepted
  - ADR 0021: Conversational Memory Injection - Status: Accepted
  - ADR 0022: Knowledge Hub Architecture - Status: Accepted
- Created Claude docs:
  - `docs/claude/conversation-memory.md`: Memory injection reference
  - Updated `docs/claude/knowledge-hub.md`: Full implementation reference

#### Knowledge Hub UI Components (Phase 5, Tasks 5.17-5.22)
- **SearchBar** (`src/components/education/knowledge-hub/components/search-bar.tsx`):
  - Debounced search input with configurable delay
  - Type filter dropdown with ARIA listbox
  - Keyboard navigation (Escape to clear/blur)
  - Screen reader announcements
- **SidebarNavigation** (`src/components/education/knowledge-hub/components/sidebar-navigation.tsx`):
  - Tree navigation for collections with expand/collapse
  - Tag toggle selection with checkbox semantics
  - Quick filters (Recent, Favorites, Archived)
  - Keyboard navigation (ArrowRight/Left to expand/collapse, Enter/Space to select)
- **QuickActions** (`src/components/education/knowledge-hub/components/quick-actions.tsx`):
  - Action buttons: New material, Upload file, Create folder, Create tag
  - Compact mode (icon-only with tooltips)
- **BulkToolbar** (`src/components/education/knowledge-hub/components/bulk-toolbar.tsx`):
  - Bulk operations: Move, Add tags, Archive, Restore, Delete
  - Selection count display with singular/plural handling
- **StatsPanel** (`src/components/education/knowledge-hub/components/stats-panel.tsx`):
  - Material counts by type (mindmap, quiz, flashcard, summary)
  - Activity statistics (today, this week)
  - Color-coded type icons
- **MaterialCard** (`src/components/education/knowledge-hub/components/material-card.tsx`):
  - Drag & drop with keyboard alternative (Arrow keys)
  - Selection checkbox, favorite toggle
  - Context menu with actions (Open, Duplicate, Move, Tags, Archive, Delete)
  - Tag display with overflow indicator
  - Relative date formatting (Oggi, Ieri, X giorni fa)
- **177 Unit Tests** (`src/components/education/knowledge-hub/components/__tests__/`):
  - `search-bar.test.tsx`: 24 tests (debounce, keyboard, type filter, accessibility)
  - `sidebar-navigation.test.tsx`: 34 tests (collections, tags, quick filters, keyboard nav)
  - `quick-actions.test.tsx`: 22 tests (buttons, compact mode, accessibility)
  - `bulk-toolbar.test.tsx`: 25 tests (visibility, actions, accessibility)
  - `stats-panel.test.tsx`: 22 tests (counts, styling, color coding)
  - `material-card.test.tsx`: 50 tests (rendering, selection, favorites, drag & drop, menu)
- All components WCAG 2.1 AA compliant with keyboard navigation and ARIA attributes

#### Knowledge Hub Hooks (Phase 5, Tasks 5.23-5.28)
- **useMaterialsSearch** (`src/components/education/knowledge-hub/hooks/use-materials-search.ts`):
  - Fuse.js fuzzy search integration with configurable threshold
  - Debounced query execution with adjustable delay
  - Type filtering (all, quiz, mindmap, flashcard, etc.)
  - Result highlighting support
  - Helper functions: `sortMaterialsByRecency`, `filterMaterials`
- **useCollections** (`src/components/education/knowledge-hub/hooks/use-collections.ts`):
  - CRUD operations for collections/folders
  - Hierarchical tree structure with parent-child relationships
  - Breadcrumb path generation
  - Material movement between collections
- **useTags** (`src/components/education/knowledge-hub/hooks/use-tags.ts`):
  - CRUD operations for tags
  - Multi-select tag filtering
  - Tag-to-material association management
  - Material count tracking per tag
  - 16 predefined colors with `getRandomTagColor` utility
- **useSmartCollections** (`src/components/education/knowledge-hub/hooks/use-smart-collections.ts`):
  - Dynamic collections: Recent (7 days), Favorites, Archived
  - Time-based: Today, This Week, This Month
  - Type-based: Quiz, Mindmap, Flashcard, Summary, etc. (13 types)
  - Auto-sorting by creation date (newest first)
- **useBulkActions** (`src/components/education/knowledge-hub/hooks/use-bulk-actions.ts`):
  - Multi-select management with Set-based state
  - Bulk operations: Move, Add Tags, Archive, Restore, Delete, Duplicate
  - Loading and error state management
  - Selection callbacks for external sync
- **129 Unit Tests** (`src/components/education/knowledge-hub/hooks/__tests__/`):
  - `use-materials-search.test.ts`: 26 tests (search, debounce, filtering, sorting)
  - `use-collections.test.ts`: 27 tests (CRUD, tree building, breadcrumbs)
  - `use-tags.test.ts`: 31 tests (CRUD, selection, material associations)
  - `use-smart-collections.test.ts`: 20 tests (time filters, type grouping)
  - `use-bulk-actions.test.ts`: 25 tests (selection, actions, error handling)

#### Knowledge Hub Renderer Registry (Phase 5, Tasks 5.03-5.15)
- **Renderer Registry** (`src/components/education/knowledge-hub/renderers/index.tsx`):
  - Lazy loading with dynamic imports for code splitting
  - Utility functions: `getRendererImport`, `hasRenderer`, `getSupportedRenderers`
  - `FallbackRenderer` for unknown material types
  - Display labels and icons for all 12 material types
- **Type-Safe Renderers** for all material types:
  - `MindmapRenderer`: Wrapper around MarkMapRenderer
  - `QuizRenderer`: Interactive quiz with show/hide answers toggle
  - `FlashcardRenderer`: Flip animation cards with navigation
  - `SummaryRenderer`: Wrapper around SummaryRenderer with expandAll
  - `DemoRenderer`: HTML/CSS/JS interactive demos with iframe sandbox
  - `DiagramRenderer`: Mermaid diagram wrapper
  - `TimelineRenderer`: Vertical timeline with motion animations
  - `FormulaRenderer`: KaTeX formula wrapper
  - `ChartRenderer`: Chart.js wrapper (line, bar, pie, scatter, area)
  - `PdfRenderer`: PDF viewer with download option
  - `ImageRenderer`: Accessible image with alt text
  - `HomeworkRenderer`: Task list with completion tracking
- **126 Unit Tests** (`src/components/education/knowledge-hub/renderers/__tests__/`):
  - `index.test.tsx`: 29 tests for registry functions (hasRenderer, getRendererImport, getSupportedRenderers)
  - `validation.test.ts`: 43 tests for all type guards and validation utilities
  - `renderers.test.tsx`: 44 tests for all 12 renderer components (rendering, empty states, interactions)
  - `error-boundary.test.tsx`: 10 tests for RendererErrorBoundary and withErrorBoundary HOC

#### Knowledge Hub Material Dialog (Phase 5, Tasks 5.01-5.02)
- **Material Dialog** (`src/components/education/knowledge-hub/material-dialog.tsx`):
  - WCAG 2.1 AA accessible modal with focus trap
  - Dynamic renderer loading via React.lazy
  - Edit/Delete actions with confirmation
  - Loading states and error handling
  - Keyboard navigation (Escape to close)
- **Dialog Tests** (`src/components/education/knowledge-hub/__tests__/material-dialog.test.tsx`)

---

## [Unreleased] - Session Summaries & Unified Archive

> **Branch**: `feature/conversation-summaries-unified-archive` | **Plan**: `docs/plans/SessionSummaryUnifiedArchive-2026-01-01.md`

### Added

#### Conversation Summaries
- **Summary Generator** (`src/lib/conversation/summary-generator.ts`): Auto-generate summaries at session end
  - Triggered by explicit close or 15-min inactivity timeout
  - Extracts topics, key facts, and student learnings
  - Saves to Conversation table
- **Inactivity Monitor** (`src/lib/conversation/inactivity-monitor.ts`): Track conversation activity
  - 15-minute timeout per conversation
  - Automatic summary trigger on timeout
  - Singleton pattern for global tracking

#### Contextual Greetings
- **Greeting Generator** (`src/lib/conversation/contextual-greeting.ts`): Personalized welcome messages
  - References previous conversation summary
  - Time-aware greetings ("ieri", "la settimana scorsa")
  - Fallback to default greeting if no history

#### Dual Rating System
- **Maestro Evaluation** (`src/lib/session/maestro-evaluation.ts`): AI evaluation of sessions
  - Score 1-10 with constructive feedback
  - Identifies strengths and areas to improve
  - Encouraging tone focused on progress
- **Rating Modal** (`src/components/session/session-rating-modal.tsx`): Student self-evaluation
  - 5-star rating with optional feedback
  - Session info display (duration, topics)
  - Skip option for quick exit

#### Parent Notes
- **Parent Note Generator** (`src/lib/session/parent-note-generator.ts`): Auto-generated parent summaries
  - Parent-friendly language (non-technical)
  - Highlights achievements
  - Constructive framing of concerns
  - Practical home activity suggestions
- **Parent Notes API** (`src/app/api/parent-notes/route.ts`): CRUD operations
  - List notes with unread count
  - Mark as viewed tracking
  - Delete functionality

#### API Endpoints
- `POST /api/conversations/[id]/end`: End conversation with summary
- `GET /api/conversations/[id]/end`: Get conversation summary
- `GET/PATCH/DELETE /api/parent-notes`: Parent notes CRUD

#### Knowledge Hub API Routes (ADR 0022, MasterPlan Phase 4)
- `GET /api/conversations/memory`: Load conversation context for memory injection (ADR 0021)
- `GET/POST /api/collections`: List and create material folders (nested support)
- `GET/PUT/DELETE /api/collections/[id]`: Single collection operations
- `GET/POST /api/tags`: List and create user tags with material counts
- `GET/PUT/DELETE /api/tags/[id]`: Single tag operations
- `POST /api/materials/bulk`: Bulk operations (move, archive, delete, restore, addTags, removeTags, setTags)
- Updated `/api/materials`: Added searchableText generation, collection/tag filters
- Updated `/api/chat`: Added conversation memory injection (ADR 0021)
- **Security**: All endpoints use cookie auth, Zod validation, Prisma parameterized queries, ownership verification

### Changed

#### Unified Tool Archive
- **Material table extended**: Now includes sessionId relation, topic, conversationId
- **tool-persistence.ts**: Migrated from CreatedTool to Material table
  - All CRUD operations now use Material
  - Soft delete via status field
  - Session linking support

#### StudySession Schema
- Added rating fields: studentRating, studentFeedback, maestroScore, maestroFeedback
- Added session context: topics, conversationId, strengths, areasToImprove
- Added materials relation for session-tool linking

#### Knowledge Hub Schema (ADR 0022)
- **Material.searchableText**: Pre-computed searchable content for Fuse.js full-text search
- **Material.collectionId**: Foreign key to Collection for folder organization
- **Collection model**: Folders for organizing materials
  - Nested folders via self-referential `parentId`
  - User-scoped with unique name per folder level
  - Color and icon customization
- **Tag model**: User-defined tags with color support
- **MaterialTag junction**: Many-to-many Material-Tag relation with cascade delete
- All new fields properly indexed for query performance

#### Conversation Flow Store
- `endConversationWithSummary()`: New action for summary-aware session end
- `loadContextualGreeting()`: Fetch personalized greeting
- `showRatingModal` / `sessionSummary`: State for rating flow
- Integration with inactivity monitor

### Deprecated
- **CreatedTool table**: Marked deprecated, use Material instead
  - Migration script: `scripts/migrate-created-tools.ts`
  - 30-day buffer before removal

### Documentation
- ADR 0019: Session Summaries & Unified Archive
- ADR 0020: Mindmap Data Structure Fix
- ADR 0021: Conversational Memory Injection
- ADR 0022: Knowledge Hub Architecture
- Claude docs: `docs/claude/session-summaries.md`

---

## [Unreleased] - Tool Architecture Improvements

> **Branch**: `main` | **GitHub Issues**: #64, Plan

### Changed

#### Demo/HTML Snippets Migration to Database
- **Migrated Demo storage** from Zustand in-memory store to database API (ADR 0015 compliance)
  - Added `useDemos()` hook in `src/lib/hooks/use-saved-materials.ts`
  - Updated `html-snippets-view.tsx` to use database-backed `useDemos()` instead of `useHTMLSnippetsStore`
  - Updated `html-preview.tsx` to save via `autoSaveMaterial()` API
  - Supports both legacy `code` format and new `html/css/js` component format
- **Unified tool auto-save** in `tool-result-display.tsx`:
  - Added `AutoSaveDemo` component for automatic demo archiving
  - Added `AutoSaveSummary` component for automatic summary archiving
  - All tools now consistently auto-save to database on creation

#### Mindmap Improvements
- **Fixed "undefined" central node** bug: AI prompt now uses `title` parameter consistently
- **Improved mindmap structure**: Enhanced AI prompt with detailed instructions for hierarchical structure
  - Clear guidance on main branches (3-5) and sub-nodes (2-4 per branch)
  - Example structure provided for better AI understanding
  - 2-3 depth levels specification

#### Uniform Focus Mode
- **Standardized "Crea con Professore"** across all tool views:
  - `mindmaps-view.tsx`: Uses `enterFocusMode('mindmap')`
  - `quiz-view.tsx`: Uses `enterFocusMode('quiz')`
  - `flashcards-view.tsx`: Uses `enterFocusMode('flashcard')`
  - `summaries-view.tsx`: Uses `enterFocusMode('summary')`

### Added
- `'create_demo'` and `'create_summary'` to ToolType union in `types/index.ts`
- `SavedDemo` interface for typed demo data
- Loading state in `html-snippets-view.tsx` for better UX

### Technical
- All educational tools now follow ADR 0015 Database-First Architecture
- Removed dependency on `useHTMLSnippetsStore` Zustand store for demos

---
## [Unreleased] - Ambient Audio Feature

> **Branch**: `feature/71-ambient-audio-enhanced` | **GitHub Issue**: #71

### Added

#### Ambient Audio System for Focus & Study
- **Audio Engine** (`src/lib/audio/engine.ts`): Web Audio API-based engine for real-time audio generation and mixing
  - Singleton pattern for global audio management
  - Multi-layer audio mixing with individual volume controls
  - Smooth audio ducking for voice/TTS integration
  - Master gain control with fade transitions
- **Audio Generators** (`src/lib/audio/generators.ts`): Procedural audio generation
  - White noise (equal energy across frequencies)
  - Pink noise (1/f spectrum, natural sound)
  - Brown noise (1/f² spectrum, deeper rumbling)
  - Binaural beats (Alpha 8-14Hz, Beta 14-30Hz, Theta 4-8Hz)
  - Stereo oscillator setup for binaural effect
- **Ambient Audio Store** (`src/lib/stores/ambient-audio-store.ts`): Zustand store for state management
  - Playback state tracking (idle, playing, paused, loading, error)
  - Multi-layer management with individual controls
  - 7 preset configurations (focus, deep work, creative, library, starbucks, rainy day, nature)
  - Auto-duck settings for voice integration
  - Study session integration settings
- **React Hook** (`src/lib/hooks/use-ambient-audio.ts`): Integration hook for components
  - Synchronizes Zustand store with Web Audio engine
  - Provides play/pause/stop controls
  - Layer management (add, remove, volume, toggle)
  - Preset application
  - Master volume control
  - Ducking controls for voice integration
- **UI Components**:
  - **AmbientAudioControl** (`src/components/ambient-audio/ambient-audio-control.tsx`): Full-featured audio control panel
    - Master volume slider with percentage display
    - Play/Pause/Stop controls
    - 7 quick preset buttons with descriptions
    - Advanced mixer with layer management
    - Real-time volume control per layer
    - Visual feedback for active layers
    - Coming soon indicator for ambient soundscapes
  - **AmbientAudioSettings** (`src/components/settings/sections/ambient-audio-settings.tsx`): Settings section wrapper
- **Test Page** (`src/app/test-audio/page.tsx`): Dedicated demo page
  - Feature showcase with descriptions
  - Usage tips and best practices
  - Scientific research references
  - Integration roadmap information
- **Settings Integration**: New "Audio Ambientale" tab in settings page
  - Distinct from Audio/Video device settings
  - Full access to ambient audio controls
  - Persistent across sessions (prepared)
- **E2E Tests** (`e2e/ambient-audio.spec.ts`): Comprehensive test coverage
  - Test page component visibility
  - Preset button functionality
  - Play/pause/stop controls
  - Volume slider interaction
  - Advanced mixer toggle
  - Settings tab integration
  - Keyboard navigation accessibility
  - Screen reader compatibility

#### Audio Modes Available
- **Noise Types**:
  - White Noise: Equal energy masking
  - Pink Noise: Natural 1/f spectrum
  - Brown Noise: Deep 1/f² rumbling
- **Binaural Beats** (requires stereo headphones):
  - Alpha (8-14 Hz): Relaxed focus, ideal for studying
  - Beta (14-30 Hz): Active concentration, problem-solving
  - Theta (4-8 Hz): Creative thinking, meditation
- **Ambient Soundscapes** (procedural audio generation):
  - Rain: Filtered noise with randomized rain drops
  - Thunderstorm: Rain with deep thunder rumbles
  - Fireplace: Crackling fire sounds
  - Café: Murmur with subtle clinks
  - Library: Quiet ambience with page turns
  - Forest: Wind with bird chirps
  - Ocean: Wave patterns with rhythm

#### Presets
- **Focus**: Binaural alpha for concentration
- **Deep Work**: Beta waves + brown noise
- **Creative**: Theta waves + nature sounds
- **Library**: Quiet ambience + white noise
- **Starbucks**: Café atmosphere
- **Rainy Day**: Rain + fireplace + thunder
- **Nature**: Forest + ocean sounds

### Technical Details
- Web Audio API for cross-browser compatibility
- Procedural generation eliminates need for large audio files
- Singleton audio engine pattern for resource efficiency
- ScriptProcessorNode fallback for compatibility
- Support for AudioWorklet (performance optimization)
- Multi-layer architecture allows custom combinations
- Smooth volume transitions (200ms ramps)
- Auto-ducking capability for voice/TTS integration
- Zustand store for React state management
- TypeScript strict mode compliance

### Future Enhancements
- Pomodoro timer integration
- Study session auto-start
- Settings persistence across sessions
- User-created preset saving
- Visualization spectrum analyzer

## [Unreleased] - MirrorBuddy v2.0

> **Branch**: `MirrorBuddy` | **GitHub Issues**: #19-#31, #44 closed

### Added

#### Landing Page & Returning User Support (Issues #73, #74)
- **Beautiful Landing Page** (`src/app/welcome/page.tsx`): Gradient hero with Melissa avatar, feature grid
- **Returning User Detection**: API endpoint `/api/onboarding` fetches existing user data from database
- **Dynamic Melissa Prompt**: `generateMelissaOnboardingPrompt(existingData)` adapts greeting for returning users
- **Personalized Greeting**: "Ciao [Nome]! È bello rivederti! Vuoi cambiare qualcosa?"
- **Skip Option**: Returning users can skip onboarding and go directly to app
- **Zod Validation**: POST endpoint validates input with proper error responses
- **Accessibility**: `aria-live="polite"` for screen reader announcements
- **Unit Tests**: 27 new tests for onboarding tools

#### Conversation-First Tool Creation (Issue #23)
- **Fullscreen Tool Layout** (`src/components/conversation/fullscreen-tool-layout.tsx`): 82/18 split with Maestro overlay
- **Maestro Overlay** (`src/components/tools/maestro-overlay.tsx`): Floating Maestro during tool building
- **Intent Detection** with tool type recognition (mindmap, quiz, flashcard)
- Tools created through natural conversation, not forms

#### Voice Commands for Mindmaps (ADR-0011, Issue #44)
- **useMindmapModifications Hook** (`src/lib/hooks/use-mindmap-modifications.ts`): SSE subscription for real-time mindmap modification events
- **InteractiveMarkMapRenderer** (`src/components/tools/interactive-markmap-renderer.tsx`): Extended renderer with imperative modification API
  - `addNode(concept, parentNode?)` - Add new concept as child
  - `expandNode(node, suggestions?)` - Add multiple children
  - `deleteNode(node)` - Remove node and descendants
  - `focusNode(node)` - Center view with highlight animation
  - `setNodeColor(node, color)` - Change node styling
  - `connectNodes(nodeA, nodeB)` - Create conceptual link
  - `undo()` - Revert last modification
- **LiveMindmap** (`src/components/tools/live-mindmap.tsx`): Wrapper combining renderer + SSE for voice-controlled mindmaps
- Fuzzy node matching for voice command targeting
- D3 animations for smooth visual feedback

#### Multi-User Collaboration (Issue #44)
- **Mindmap Room** (`src/lib/collab/mindmap-room.ts`): Real-time room state with CRDT-like versioning
- **Collab WebSocket** (`src/lib/collab/collab-websocket.ts`): WebSocket connection management
- **Room API** (`src/app/api/collab/rooms/`): Create, join, leave rooms
- Participant cursors and presence indicators
- Conflict resolution via version numbers

#### Import/Export Multi-Format (Issue #44)
- **Mindmap Export** (`src/lib/tools/mindmap-export.ts`): PNG, SVG, Markdown, FreeMind (.mm), XMind, JSON
- **Mindmap Import** (`src/lib/tools/mindmap-import.ts`): Auto-detect format, parse Markdown/FreeMind/XMind/JSON
- Download helper for browser blob saving

#### Tool Execution System (ADR-0009)
- **OpenAI Function Calling**: Maestri can create tools via structured function calls
- **Tool Executor** (`src/lib/tools/tool-executor.ts`): Handler registry pattern
- **Tool Handlers**: mindmap, quiz, demo, search, flashcard
- **Tool Panel** (`src/components/tools/tool-panel.tsx`): UI for tool visualization
- **Tool Persistence**: IndexedDB for binaries, Prisma for metadata

#### Student Summary Editor with Maieutic Method (Issue #70)
- **StudentSummaryEditor** (`src/components/tools/student-summary-editor.tsx`): Student writes their own summary with Coach guidance
  - Guided 3-section structure: Introduzione, Sviluppo, Conclusione
  - Each section has a guiding question to prompt student thinking
  - Markdown support for formatting
  - Real-time word count
- **Maieutic Method**: Coach guides with questions, never writes for the student
- **Inline Comments** (`InlineComment` type): Coach can highlight text and add feedback
- **Voice Commands**: `open_student_summary`, `student_summary_add_comment`
- **SSE Sync Hook** (`src/lib/hooks/use-student-summary-sync.ts`): Real-time collaboration
- **Archive Integration**: Summaries appear in Archivio under "Riassunti" filter

#### Showcase Mode
- **Offline Demo** (`src/app/showcase/`): Full app demo without LLM connection
- **Showcase Button**: Added to AI Provider settings for easy access
- Pre-recorded responses for all features demonstration

#### Pomodoro Timer (Issue #45)
- **PomodoroTimer** (`src/components/education/pomodoro-timer.tsx`): ADHD-friendly focus sessions
- Configurable work/break intervals
- Visual and audio notifications
- Integration with unified header

#### Video Conference Layout
- **Voice Session Layout**: Video-conference style with Maestro fullscreen
- **Fullscreen Mindmaps**: Tool takes 100% during creation
- **Picture-in-Picture**: Maestro avatar overlay during tool building

#### Side-by-Side Voice UI
- **Coach/Buddy Voice**: Separate voice layout for Coach and Buddy characters
- Dual panel design for conversation + character display

#### Unified Maestri Voice Experience (PR #43)
- **MaestroSession** (`src/components/maestros/maestro-session.tsx`): 835-line unified component combining voice and chat
  - Side-by-side layout: chat on left (flex-1), voice panel on right (w-64)
  - Seamless voice/chat switching within same session
  - Voice transcripts appear in chat stream with 🔊 indicator
  - Real-time Azure Realtime API integration
- **VoicePanel** (`src/components/voice/voice-panel.tsx`): Shared voice controls component
  - Extracted from CharacterChatView for reuse
  - Avatar with speaking animation
  - Audio visualizer with input levels
  - Mute/unmute and end call controls
  - Supports both hex colors and Tailwind gradients
- **EvaluationCard** (`src/components/chat/evaluation-card.tsx`): Inline session evaluation
  - Auto-generated at session end (5+ messages or 2+ minutes)
  - Score calculation: engagement, questions asked, duration
  - Grade display (Insufficiente → Eccellente)
  - Parent diary integration with GDPR consent
- **Session Metrics**: XP rewards, question counting, duration tracking
- **LazyMaestroSession**: Code-split wrapper for performance

#### Separate Conversations per Character (ADR-0010)
- Each Maestro/Coach/Buddy maintains independent conversation history
- Context preserved across sessions per character
- Clean handoffs between characters

#### Telemetry System (ADR-0006)
- **TelemetryEvent** model in Prisma schema
- Usage analytics for Grafana integration
- Privacy-respecting event tracking

#### Notification Persistence (ADR-0007)
- **Notification** model with scheduling support
- Server-side triggers for level-up, streak, achievements
- API endpoints for CRUD operations

#### Parent Dashboard GDPR (ADR-0008)
- **Dual Consent**: Parent AND student must approve
- **Data Export**: JSON/PDF portability
- **Right to Erasure**: Deletion request tracking
- **Access Logging**: Audit trail for GDPR compliance
- **Settings Integration**: "Genitori" tab in Settings links to `/parent-dashboard`

#### Materiali Redesign
- **50/50 Responsive Grid**: Better layout for materials view
- Improved visual hierarchy

#### Audio Device Selection
- **setSinkId Integration**: Choose output audio device
- Device picker in voice settings

#### Onboarding Flow
- **Welcome Page** (`src/app/welcome/`): Multi-step onboarding
- **Onboarding Store**: Track completion state
- Redirect to welcome if not completed
- Meet the Maestri carousel

#### Triangle of Support Architecture (ADR-0003)
- **Melissa & Davide (Learning Coaches)**: New AI characters focused on building student autonomy
  - Melissa: Young, energetic female coach (default)
  - Davide: Calm, reassuring male coach (alternative)
  - Focus on teaching study methods, not doing work for students
- **Mario & Maria (Peer Buddies)**: MirrorBuddy system for emotional peer support
  - Mario: Male peer (default), always 1 year older than student
  - Maria: Female peer (alternative)
  - "Mirroring" system: buddy has same learning differences as student
  - Horizontal relationship (peer-to-peer, not teacher-student)
- **Character Router** (`src/lib/ai/character-router.ts`): Intent-based routing to appropriate character
- **Intent Detection** (`src/lib/ai/intent-detection.ts`): Classifies student messages (academic, method, emotional, crisis)
- **Handoff Manager** (`src/lib/ai/handoff-manager.ts`): Manages transitions between characters

#### Safety Guardrails for Child Protection (ADR-0004)
- **Core Safety Prompts** (`src/lib/safety/safety-prompts.ts`): Injected into ALL character system prompts
- **Content Filter** (`src/lib/safety/content-filter.ts`): Input filtering for profanity and inappropriate content
- **Output Sanitizer** (`src/lib/safety/output-sanitizer.ts`): Response sanitization before delivery
- **Jailbreak Detector** (`src/lib/safety/jailbreak-detector.ts`): Pattern matching for prompt injection attempts
- **Adversarial Test Suite** (`src/lib/safety/__tests__/`): Automated safety testing
- Italian-specific crisis keywords detection with helpline referrals (Telefono Azzurro: 19696)

#### Real-time Tool Canvas (ADR-0005)
- **SSE Streaming** (`src/app/api/tools/stream/route.ts`): Server-Sent Events for real-time updates
- **Tool Events Manager** (`src/lib/realtime/tool-events.ts`): Client registry and event broadcasting
- **Tool State Management** (`src/lib/realtime/tool-state.ts`): Track tool creation progress
- 80/20 layout: 80% tool canvas, 20% Maestro picture-in-picture

#### Student Profile System
- **Profile Generator** (`src/lib/profile/profile-generator.ts`): Synthesizes insights from all Maestri
- **Parent Dashboard** (`src/app/parent-dashboard/page.tsx`): View for parents to see student progress
- Insight collection from Maestri conversations
- Growth-focused language (strengths and "areas of growth", not deficits)

#### Storage Architecture (ADR-0001)
- **Provider-agnostic Storage Service**: Abstract interface for file storage
- **Local Storage Provider**: Development mode using `./uploads/`
- **Azure Blob Provider**: Production mode (deferred implementation)
- Support for: homework photos, mind maps, PDFs, voice recordings

#### Voice Improvements
- **Barge-in**: Users can now interrupt the Maestro while speaking for natural conversation flow
- **Enhanced voice personalities**: Cicerone and Erodoto have detailed speaking style, pacing, and emotional instructions

#### Accessibility
- **7 Accessibility Profiles**: Quick-select presets for Dislessia, ADHD, Autismo, Visivo, Uditivo, Motorio, Paralisi Cerebrale
- **Cerebral Palsy profile**: TTS, large text, keyboard nav, extra spacing

#### Other
- **Notification Service Stub**: Placeholder for future notification system (NOT_IMPLEMENTED, see Issue #14)

### Changed
- **Conversation Flow**: Now routes to appropriate character based on intent
- **Settings UI**: Reorganized Audio/Video settings for better UX
- **Theme System**: Fixed theme detection and added value prop to ThemeProvider
- **Maestri Data**: Split `maestri-full.ts` into per-maestro modules for maintainability
- **Logging**: All `console.*` calls replaced with structured `logger` utility
- **Voice Panel**: Improved layout balance and proportions
- **Voice mapping**: 6 maestri updated to gender-appropriate voices
  - Mozart: shimmer → sage (masculine)
  - Erodoto: ballad → echo (authoritative historian)
  - Cicerone: ballad → echo (oratorical)
  - Manzoni: coral → sage (refined)
  - Leonardo: coral → alloy (versatile polymath)
  - Ippocrate: coral → sage (wise physician)
- **VAD sensitivity**: threshold 0.5 → 0.4 (captures softer voices)
- **Turn-taking speed**: silence_duration_ms 500 → 400 (faster response)

### Fixed
- **Onboarding Voice Session** (#61): Voice session now persists across onboarding steps, preventing disconnect/reconnect and fallback to Web Speech API
- **Parent Dashboard Navigation**: Added sticky header with "Torna all'app" back button
- WCAG 2.1 AA accessibility fixes for conversation-flow component
- Motion animations respect `prefers-reduced-motion`
- Aria-labels on buttons and interactive elements
- Aria-live regions for dynamic content
- **Theme switching** (#4): Light theme now correctly overrides OS dark mode preference
- **Accent colors** (#5): CSS custom properties for accent colors now apply correctly in light mode
- **Language buttons** (#6): Selected language state has clear visual feedback
- **AI Provider status** (#7): Fixed Ollama button closing tag for proper semantic HTML
- **E2E Tests**: Fixed 28 failing Playwright tests
- **Voice Session**: Eliminated empty error objects `{}` in logs
- **Button Nesting**: Resolved hydration error in MaestroCard
- **Homework Camera**: Fixed camera capture and inline subject dialog
- **Showcase Navigation**: Added exit navigation back to main app
- CodeQL security alerts resolved (HTML sanitization, voiceInstructions injection)
- Removed unused imports and lint warnings

### Security
- All 17 Maestri now have safety guardrails injected automatically
- Crisis keyword detection with Italian helpline numbers
- Jailbreak/prompt injection detection and blocking
- Privacy protection: AI will not request personal information
- GDPR-compliant data handling for minors

### Removed
- Deprecated `libretto-view.tsx` component
- Fake history data replaced with real sessionHistory

### Documentation
- **ADR 0001**: Materials Storage Strategy
- **ADR 0002**: MarkMap for Mind Maps
- **ADR 0003**: Triangle of Support Architecture
- **ADR 0004**: Safety Guardrails for Child Protection
- **ADR 0005**: Real-time SSE Architecture
- **ADR 0006**: Telemetry System
- **ADR 0007**: Notification Persistence
- **ADR 0008**: Parent Dashboard GDPR Compliance
- **ADR 0009**: Tool Execution Architecture
- **ADR 0010**: Separate Conversations per Character
- **ADR 0011**: Voice Commands for Mindmap Modifications
- Updated CLAUDE.md with MirrorBuddy architecture, Tool Execution, Voice Commands
- Updated E2E tests for new features
- Added voice support documentation for Coach & Buddy

---

## [1.0.0] - 2025-12-28

### Added

#### AI Maestri (17 Tutors)
- **Euclide** - Mathematics tutor inspired by Euclid of Alexandria
- **Leonardo** - Art tutor inspired by Leonardo da Vinci
- **Darwin** - Science tutor inspired by Charles Darwin
- **Curie** - Chemistry tutor inspired by Marie Curie
- **Feynman** - Physics tutor inspired by Richard Feynman
- **Galileo** - Astronomy tutor inspired by Galileo Galilei
- **Lovelace** - Computer Science tutor inspired by Ada Lovelace
- **Shakespeare** - English tutor inspired by William Shakespeare
- **Mozart** - Music tutor inspired by Wolfgang Amadeus Mozart
- **Socrate** - Philosophy tutor using Socratic method
- **Erodoto** - History tutor inspired by Herodotus
- **Manzoni** - Italian tutor inspired by Alessandro Manzoni
- **Cicerone** - Civic Education tutor inspired by Cicero
- **Humboldt** - Geography tutor inspired by Alexander von Humboldt
- **Ippocrate** - Physical Education tutor inspired by Hippocrates
- **Smith** - Economics tutor inspired by Adam Smith
- **Chris** - Storytelling tutor inspired by Chris Anderson (TED)

#### Voice Features
- Real-time voice sessions with Azure OpenAI Realtime API
- Natural voice-to-voice conversations
- Automatic transcription
- Session recordings for review
- Interrupt-and-respond capability

#### Learning Tools
- Mind maps with MarkMap visualization
- FSRS flashcard system (spaced repetition)
- Adaptive quiz system
- Progress tracking per subject
- Session history

#### Gamification
- XP system for all activities
- Level progression
- Achievement badges
- Daily streaks
- Optional leaderboards

#### Accessibility (WCAG 2.1 AA)
- OpenDyslexic font option for dyslexia
- Reduced motion mode for ADHD
- Predictable layouts for autism
- Large touch targets for motor impairments
- Full keyboard navigation
- Screen reader support
- High contrast mode
- Focus indicators

#### Technical
- Next.js 16 with App Router
- TypeScript 5 strict mode
- Prisma ORM with SQLite/PostgreSQL
- Zustand state management
- Tailwind CSS 4
- Playwright E2E tests

### Configuration
- Azure OpenAI support (full features including voice)
- Ollama support for local development (text only)
- Azure Cost Management integration (optional)

---

## Roadmap

### Completed in MirrorBuddy v2.0
- [x] Parent/teacher dashboard (`/parent-dashboard`)
- [x] Study companion feature (MirrorBuddy: Mario & Maria)

### Future
- [ ] Multi-language support
- [ ] Mobile-optimized UI
- [ ] Offline mode

---

*This project is part of [FightTheStroke](https://fightthestroke.org)'s mission to support children with learning differences.*
