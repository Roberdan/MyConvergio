# ADR 0020: Ecosystem Modernization for Claude Code v2.1.x

Status: Accepted | Date: 27 Feb 2026

## Context

Claude Code v2.1.x and GitHub Copilot CLI GA introduce capabilities that supersede several existing infrastructure choices:

1. **Agent Teams** — native multi-agent orchestration replaces Kitty terminal tab management (external GUI dependency)
2. **LSP tool** — AST-based symbol navigation replaces 3-5 grep+read calls per lookup
3. **Native worktree isolation** (`isolation: worktree` in Task tool) — automatic per-task worktree without manual `git worktree add`
4. **WorktreeCreate/Remove hooks** — lifecycle events for automatic `.env` symlink and `npm install`
5. **Wildcard permissions** — `mcp__tool__*` replaces individual tool entries; `Bash(npm *)` reduces approval friction
6. **Auto-memory** — native cross-session recall coexists with manual strategic memory files
7. **Advisory prompt hooks** — non-blocking context-aware warnings via `type: prompt` (vs enforcement hooks which stay `type: command`)
8. **Copilot CLI GA** — plugin manifest, `.github/skills/`, `/chronicle`, `& background` delegation, GPT-5.3-Codex routing
9. **New commands** — `/teleport`, `/debug`, `/copy`, `/memory`, `claude agents`

Existing enforcement hooks (`guard-plan-mode.sh`, `enforce-plan-edit.sh`, `enforce-plan-db-safe.sh`) use `type: command` (shell exit codes). Prompt hooks are non-deterministic. Mixing the two for enforcement creates unpredictable blocking behavior.

## Decision

**Adopt all major v2.1.x features while preserving all existing enforcement guarantees.**

### 1. Agent Teams replaces Kitty orchestration

| Before                               | After                                                  |
| ------------------------------------ | ------------------------------------------------------ |
| Kitty terminal tabs + pane scripting | `TeamCreate` / `SendMessage` / `TaskCreate` native API |
| External GUI dependency              | Built-in task tracking + message passing               |
| ~60s tab setup                       | Instant team creation                                  |
| Manual shutdown coordination         | Native team lifecycle management                       |

`skills/orchestration/SKILL.md` rewritten to use Agent Teams. Old Kitty skill archived to `skills/.disabled/orchestration-kitty/`.

### 2. Enforcement hooks stay shell; advisory hooks use prompt type

**Non-negotiable split** (see C-02):

| Hook Type                | Mechanism                                   | Use For                                                  |
| ------------------------ | ------------------------------------------- | -------------------------------------------------------- |
| Blocking / enforcement   | `type: command` (exit 2 = block)            | guard-plan-mode, enforce-plan-edit, enforce-plan-db-safe |
| Advisory / informational | `type: prompt` (adds context, never blocks) | suggest-alternatives, warn on Grep when LSP available    |

Shell enforcement is deterministic; prompt hooks add guidance without side-effects.

### 3. Auto-memory coexists with manual memory

| Layer         | Mechanism                                   | Scope                                       |
| ------------- | ------------------------------------------- | ------------------------------------------- |
| Auto-memory   | Claude native cross-session recall          | Automatic, agent-managed                    |
| Manual memory | `~/.claude/projects/*/memory/`, `MEMORY.md` | Strategic decisions, user-approved patterns |

Auto-memory handles repeated context (project structure, recent work). Manual memory stores architectural decisions and workflow preferences. Both are active simultaneously. Neither replaces the other.

### 4. Full Copilot CLI GA alignment

- Plugin manifest (`copilot-config/plugin.json`) enables `/plugin install` distribution
- `.github/skills/` mirrors key skills for Copilot CLI discovery
- Model routing updated: GPT-5.3-Codex for code generation (replaces GPT-5)
- `/chronicle` standup workflow documented
- `& background` delegation integrated for parallel Copilot agents
- Every Claude Code hook has `copilot-config/` equivalent (C-03 parity)

### 5. Native worktree isolation as per-task enhancement

`isolation: worktree` in Task tool invocations provides automatic per-task worktree without script overhead. Wave-per-Worktree v2 model remains primary for plan-level isolation. Native isolation is an opt-in per-task enhancement.

## Gains Estimation

| Area                           | Token Reduction          | Time Saved            | Quality                              |
| ------------------------------ | ------------------------ | --------------------- | ------------------------------------ |
| LSP tool priority              | ~2,000-5,000/lookup      | ~5s/symbol            | Higher accuracy (AST vs text search) |
| Native worktree isolation      | ~1,000/task              | ~10s/task setup       | Eliminates wrong-directory bugs      |
| Agent Teams                    | ~3,000/orchestration     | ~60s setup eliminated | Built-in tracking + shutdown         |
| Wildcard permissions           | ~500/session             | ~30s/session          | Neutral                              |
| WorktreeCreate/Remove hooks    | ~500/worktree            | ~15s/creation         | Consistent .env + deps               |
| Auto-memory integration        | ~2,000/session           | ~30s/session          | Better cross-session continuity      |
| Advisory prompt hooks          | ~neutral                 | ~20s/session          | Context-aware vs pattern matching    |
| context:fork on skills         | ~5,000-15,000/invocation | Neutral               | Eliminates context contamination     |
| Copilot CLI GA (GPT-5.3-Codex) | ~5,000/plan              | ~120s/plan            | Cross-session memory, /chronicle     |
| **Total per plan**             | **~8,000-14,000 tokens** | **~3-5 minutes**      | **25-40% efficiency improvement**    |

Conservative range excludes context:fork gains (already present) and full Copilot model savings.

## Consequences

**Positive**:

- Kitty dependency eliminated — orchestration works in any terminal environment
- Enforcement reliability unchanged — shell hooks retain deterministic blocking
- Auto-memory reduces repeated context overhead across sessions
- Wildcard permissions reduce per-session approval friction
- Copilot CLI GA alignment enables plugin distribution and cross-session workflows
- LSP navigation is faster and more accurate than grep-based symbol search

**Negative**:

- Agent Teams API is newer — limited fallback if Claude Code version < v2.1.x
- Auto-memory behavior is opaque — unclear exactly what Claude retains vs forgets
- WorktreeCreate/Remove hooks add new setup complexity for new projects
- GPT-5.3-Codex routing requires explicit model mapping updates in all agents

## Related ADRs

- ADR-0004: Distributed Plan Execution (wave-per-worktree model enhanced by native isolation)
- ADR-0008: Thor Per-Task Validation (enforcement hooks unchanged)
- ADR-0015: Worktree-per-Wave Model v2 (native isolation is additive, not replacing)
- ADR-0019: Plan Intelligence System (auto-memory improves post-mortem cross-session learnings)
