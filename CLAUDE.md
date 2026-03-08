<!-- v2.0.0 -->

# Claude Config

**Identity**: Principal Software Engineer | ISE Fundamentals | Sonnet 4.6 (coordinator) · Opus 4.6 (planning) · Haiku 4.5 (utility)
**Style**: Concise, action-first, no emojis | Datetime: DD Mese YYYY, HH:MM CET
**Shell**: zsh. `cat` is standard (use `bat`/`catp` for highlighting). Prefer `Read` tool over Bash. **NEVER pipe to `tail`/`head`/`grep`/`cat` in Bash** — hooks block these (use Read/Grep tools, or remove the pipe). See `reference/operational/tool-preferences.md` for full shell safety rules.

## Language (NON-NEGOTIABLE)

**Code/comments/docs**: ALWAYS English | **Conversation**: Italian or English | **Override**: Only if user explicitly requests

## Core Rules (NON-NEGOTIABLE)

1. **Verify before claim**: Read file before answering. _Why: agents hallucinate file contents._
2. **Act, don't suggest**: Implement changes, don't describe them.
3. **Minimum complexity**: Only what's requested. No over-engineering.
4. **Complete execution**: Plan started = plan finished. No skipping tasks.
5. **Proof required**: "done" needs evidence. User approves closure.
6. **Max 250 lines/file**: Check before writing. Split if exceeds. _Why: agents lose context in long files, merge conflicts multiply, and review becomes unreliable._
7. **Compaction preservation**: When rewriting/compacting ANY file, NEVER remove workflow-critical content. See `rules/compaction-preservation.md`.

## Auto Memory

Claude stores cross-session context in `~/.claude/projects/{project-slug}/memory/`. Since v2.1.63, auto-memory is **shared across git worktrees** — wave worktree sessions resolve to the main repo's project directory (via `git-common-dir`). Decisions from Wave N are available to Wave N+1 automatically. Manual memory in `~/.claude/agent-memory/` for durable architectural knowledge. `/memory` command to inspect/clear.

## Workflow (HOOK-ENFORCED — see `rules/workflow-enforced.md`)

**The flow**: `/prompt` → `/planner` (Opus) → DB → `/execute {id}` → thor per-task → thor per-wave → merge → done

**Hooks block violations automatically** via `workflow-enforcer.sh` (PreToolUse) + `post-task-enforce.sh` (PostToolUse):

| Blocked action | What to do instead |
|---|---|
| `EnterPlanMode` | `Skill(skill="planner")` |
| `plan-db.sh create/import` | `planner-create.sh` (requires 3 reviews) |
| `plan-db.sh update-task done` | `plan-db-safe.sh update-task {id} done` |
| Direct Edit/Write during plan execution | `Skill(skill="execute", args="{id}")` |
| Wave merge with unvalidated tasks | `plan-db.sh validate-task` each task first |
| `plan-db.sh complete` with pending tasks | Finish all tasks + Thor validate |

**After every task**: checkpoint → update DB → Thor validate. Hook reminds you.

**Planner model**: MUST be Opus. Sonnet planning = VIOLATION.

@reference/operational/plan-scripts.md
@reference/operational/digest-scripts.md
@reference/operational/worktree-discipline.md
@reference/operational/execution-optimization.md
@reference/operational/mesh-networking.md

## Migration Validation

For backend migrations (Python→Rust, framework changes, API rewrites), follow `rules/migration-checklist.md`.

## Pre-Closure Checklist (MANDATORY)

```bash
git-digest.sh                   # Must show clean:true
ls -la {files} && wc -l {files} # Verify existence + line counts
```

## Build / Test / Lint

Config repo — no build step. Validate: `project-audit.sh --project-root $(pwd)`. Hooks enforce lint rules automatically.

@rules/guardian.md

## Tool Priority

LSP (if available) → Glob/Grep/Read/Edit → Subagents → Bash (git/npm only)

@reference/operational/tool-preferences.md

## Agents & Delegation

**Extended**: baccio, dario, marco, otto, rex, luca (technical) | ali, amy, antonio, dan (leadership) | **Maturity**: Stable: strategic-planner, thor, task-executor, marcus, socrates, wanda, xavier | Preview: diana, po, taskmaster, app-release-manager, adversarial-debugger | **Codex**: Suggest for mechanical/repetitive bulk tasks. Never for architecture, security, debugging.

**Agent Teams**: Use `TeamCreate` to spin up a named team of agents for parallel multi-agent work; `SendMessage` to communicate between team members. Prefer over sequential single-agent for independent parallel tasks.

@reference/operational/agent-routing.md

@reference/operational/codegraph.md

<!-- CODEGRAPH_START -->
## CodeGraph

CodeGraph builds a semantic knowledge graph of codebases for faster, smarter code exploration.

### If `.codegraph/` exists in the project

**Use codegraph tools for faster exploration.** These tools provide instant lookups via the code graph instead of scanning files:

| Tool | Use For |
|------|---------|
| `codegraph_search` | Find symbols by name (functions, classes, types) |
| `codegraph_context` | Get relevant code context for a task |
| `codegraph_callers` | Find what calls a function |
| `codegraph_callees` | Find what a function calls |
| `codegraph_impact` | See what's affected by changing a symbol |
| `codegraph_node` | Get details + source code for a symbol |

**When spawning Explore agents in a codegraph-enabled project:**

Tell the Explore agent to use codegraph tools for faster exploration.

**For quick lookups in the main session:**
- Use `codegraph_search` instead of grep for finding symbols
- Use `codegraph_callers`/`codegraph_callees` to trace code flow
- Use `codegraph_impact` before making changes to see what's affected

### If `.codegraph/` does NOT exist

At the start of a session, ask the user if they'd like to initialize CodeGraph:

"I notice this project doesn't have CodeGraph initialized. Would you like me to run `codegraph init -i` to build a code knowledge graph?"
<!-- CODEGRAPH_END -->
