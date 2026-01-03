# Wave 4: Supporti Consolidation

**Owner**: Claude-C team (C1, C2)
**Worktree**: `wt-supporti`
**Branch**: `feat/supporti-consolidation`
**Status**: Pending (blocked by Wave 0)

---

## Current Situation

MirrorBuddy exposes separate tools:
- Flashcards
- Mind Maps
- Summaries
- Materials (Archive)
- Study Kit
- Quiz
- Interactive Demos
- Calendar

---

## Objective

Design a **single consolidated area called "Supporti"** that:
- Is the complete archive of all learning supports
- Always accessible
- Navigable in a structured way

---

## Navigation Dimensions

### 1. By Tool Type
```
Supporti/
+-- Mind Maps
+-- Summaries
+-- Flashcards
+-- Quiz
+-- Interactive Demos
+-- Documents (PDF, images)
```

### 2. By Subject/Topic
```
Supporti/
+-- Mathematics
|   +-- Geometry
|   +-- Algebra
+-- History
|   +-- French Revolution
|   +-- Roman Empire
+-- Sciences
|   +-- Photosynthesis
+-- [Auto-tagged by AI]
```
### 3. By Timeline/Date
```
Supporti/
+-- Today
+-- This Week
+-- This Month
+-- Complete Archive
+-- [Sortable by creation/modification date]
```
### 4. By Maestro/Coach
```
Supporti/
+-- Created with Galileo
+-- Created with Leonardo
+-- Created with Marie Curie
+-- Created by Study Kit (self-generated)
```
### 5. By Status
```
Supporti/
+-- To Study
+-- In Progress
+-- Completed
+-- Favorites (bookmarked)
```

## Information Architecture

```
/supporti
+-- HEADER
|   +-- Title "Your Supports"
|   +-- Global search bar
|   +-- Quick filters (type, subject, date)
|   +-- View toggle (Grid / List)
|
+-- SIDEBAR (Navigation)
|   +-- All Supports
|   +-- --- By Type ---
|   |   +-- Mind Maps
|   |   +-- Flashcards
|   |   +-- Quiz
|   |   +-- Summaries
|   |   +-- Demos
|   +-- --- By Subject ---
|   |   +-- [Dynamic based on content]
|   +-- --- By Maestro ---
|   |   +-- [Dynamic based on content]
|   +-- Favorites
|
+-- MAIN CONTENT AREA
|   +-- Breadcrumb (Supporti > Maps > Math)
|   +-- Content Grid/List
|   |   +-- Material Card
|   |   |   +-- Thumbnail/Preview
|   |   |   +-- Title
|   |   |   +-- Type (badge)
|   |   |   +-- Subject (tag)
|   |   |   +-- Creation date
|   |   |   +-- Maestro (avatar)
|   |   |   +-- Actions (Open, Bookmark, Delete)
|   |   +-- ...
|   +-- Empty State (if empty)
|
+-- DETAIL VIEW (on click)
    +-- Full content preview
    +-- Complete metadata
    +-- Actions (Edit, Export, Share, Delete)
    +-- Related materials
```

---

## Existing -> New Mapping

| Current Page | Destination |
|--------------|-------------|
| `/archivio` | `/supporti` (default view) |
| `/education` -> Flashcards | `/supporti?type=flashcard` |
| `/education` -> Mind Maps | `/supporti?type=mindmap` |
| `/education` -> Quiz | `/supporti?type=quiz` |
| `/study-kit` | `/supporti?source=studykit` or integrated |
| `/materiali` | DEPRECATED -> redirect to `/supporti` |

---

## Trade-offs and Explicit Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| URL | `/supporti` | Italian, consistent with MirrorBuddy |
| Sidebar | Always visible (collapse on mobile) | Quick navigation |
| Study Kit | Remains as generator, output goes to Supporti | Separation creation/archive |
| Calendar | Stays separate | Different function (scheduling) |
| Search | Full-text + filters | Scalability |

---

## File Structure

| File | Purpose |
|------|---------|
| `src/app/supporti/page.tsx` | Main page (NEW) |
| `src/app/supporti/[type]/page.tsx` | Filtered by type (NEW) |
| `src/app/supporti/components/sidebar.tsx` | Navigation (NEW) |
| `src/app/supporti/components/material-card.tsx` | Single card (NEW) |
| `src/app/supporti/components/filters.tsx` | Advanced filters (NEW) |
| `src/app/supporti/components/search.tsx` | Search component (NEW) |
| `src/lib/stores/materials-store.ts` | Materials state (exists) |
| `src/lib/api/materials.ts` | API client |

---

## Execution Plan

| Step | Task | Owner | Files Touched | Parallel? | Dependencies |
|------|------|-------|---------------|-----------|--------------|
| 4.1 | Base structure | Claude-C1 | `app/supporti/page.tsx` (NEW) | NO | 0.3 |
| 4.2 | Sidebar | Claude-C1 | `supporti/components/sidebar.tsx` (NEW) | YES | 4.1 |
| 4.3 | Material card | Claude-C2 | `supporti/components/material-card.tsx` (NEW) | YES | 4.1 |
| 4.8 | Redirect /archivio | Claude-C2 | `app/archivio/page.tsx` | YES | 4.1 |
| 4.9 | Redirect /materiali | Claude-C2 | `app/materiali/page.tsx` | YES | 4.1 |
| 4.10 | Navigation update | Claude-C1 | `app/page.tsx` (nav only) | YES | 4.1 |
| 4.4 | Type filters | Claude-C1 | `supporti/components/filters.tsx` | NO | 4.2, 4.3 |
| 4.5 | Subject filters | Claude-C1 | `supporti/components/filters.tsx` | NO | 4.4 |
| 4.6 | Date filters | Claude-C1 | `supporti/components/filters.tsx` | NO | 4.4 |
| 4.7 | Full-text search | Claude-C1 | `supporti/components/search.tsx` (NEW) | NO | 4.4 |
| 4.11 | E2E tests | Claude-C1 | `e2e/supporti.spec.ts` (NEW) | NO | 4.7 |

---

## Acceptance Criteria

- [ ] /supporti page implemented
- [ ] Navigation for all 5 dimensions
- [ ] Full-text search working
- [ ] All existing tools accessible from Supporti
- [ ] Material cards with preview, metadata, actions
- [ ] Responsive design
- [ ] ZERO functionality loss vs current
- [ ] Redirects from deprecated pages
- [ ] E2E tests cover navigation

---

## Migration (Non-Breaking)

1. Create /supporti with new UI
2. Keep /archivio as alias (redirect)
3. Update navigation links
4. Deprecate /materiali after 2 weeks
5. Remove legacy pages after 4 weeks

---

## Sign-off Checklist

| Step | Task | Status | Date | Signature |
|------|------|--------|------|-----------|
| 4.1 | Base structure | [ ] | | Claude-C1 |
| 4.2 | Sidebar | [ ] | | Claude-C1 |
| 4.3 | Material card | [ ] | | Claude-C2 |
| 4.8 | Redirect /archivio | [ ] | | Claude-C2 |
| 4.9 | Redirect /materiali | [ ] | | Claude-C2 |
| 4.10 | Navigation update | [ ] | | Claude-C1 |
| 4.4 | Type filters | [ ] | | Claude-C1 |
| 4.5 | Subject filters | [ ] | | Claude-C1 |
| 4.6 | Date filters | [ ] | | Claude-C1 |
| 4.7 | Full-text search | [ ] | | Claude-C1 |
| 4.11 | E2E tests | [ ] | | Claude-C1 |
| - | PR created | [ ] | | Claude-C1 |

---

## Evidence Section (per VERIFICATION-PROCESS.md)

| Check | Result | Timestamp |
|-------|--------|-----------|
| `npm run typecheck` | [ ] PASS / FAIL | |
| `npm run lint` | [ ] PASS / FAIL | |
| `npm run build` | [ ] PASS / FAIL | |
| `grep -ri PLACEHOLDER src/` | [ ] 0 matches | |
| Manual testing | [ ] Done | |

**Verified by**: _________________ **Date**: _________________

**PR Compliance**: Before creating PR, complete `docs/EXECUTION-CHECKLIST.md`

---

*Parent document: [TODAY.md](../TODAY.md)*
*Created: 3 January 2026*
