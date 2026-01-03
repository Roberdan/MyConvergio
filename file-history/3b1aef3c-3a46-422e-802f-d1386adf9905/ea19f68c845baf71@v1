

# CLAUDE.md

AI-powered educational platform for students with learning differences.  
17 AI "Maestros", voice, FSRS flashcards, mind maps, quizzes, gamification.

## Commands

```bash
npm run dev          # Dev server :3000
npm run build        # Production build
npm run lint         # ESLint
npm run typecheck    # TypeScript
npm run test         # Playwright E2E
npx prisma generate  # After schema changes
npx prisma db push   # Sync schema
```

## Architecture

**AI Providers** (`src/lib/ai/providers.ts`): Azure OpenAI (primary, voice) | Ollama (fallback, text-only)

**State** (`src/lib/stores/app-store.ts`): Zustand stores sync via REST APIs (ADR 0015) - NO localStorage for user data.

**Key paths**: Types `src/types/index.ts` | Safety `src/lib/safety/` | FSRS `src/lib/education/fsrs.ts` | Maestros `src/data/maestri-full.ts`

## On-Demand Docs

Load with `@docs/claude/<name>.md`:

**Core**: mirrorbuddy | tools | database | api-routes | knowledge-hub  
**Voice**: voice-api | ambient-audio | onboarding  
**Features**: pomodoro | notifications | parent-dashboard | session-summaries | summary-tool | conversation-memory  
**Characters**: buddies | coaches

## Project Rules

**Verification**: `npm run lint && npm run typecheck && npm run build && npm run test`

**Process**:
- Tests first: Write failing test → implement → pass
- Update CHANGELOG for user-facing changes
- Add to `@docs/claude/` if complex feature
- Types in `src/types/index.ts`
- Conventional commits, reference issue if exists

**Constraints**:
- WCAG 2.1 AA accessibility (7 profiles in `src/lib/accessibility/`)
- NO localStorage for user data (ADR 0015) - Zustand + REST only
- Azure OpenAI primary, Ollama fallback only
- Prisma for all DB operations (`prisma/schema.prisma`)
- Path aliases: `@/lib/...`, `@/components/...`

## Summary Instructions

When compacting: code changes, test output, architectural decisions, open tasks.  
Discard verbose listings and debug output.
