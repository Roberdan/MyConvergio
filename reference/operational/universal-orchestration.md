# Universal Agent Orchestration

Cross-CLI operating contract for any plan, project, repository, language, platform, or architecture.

## Goal

Turn `prompt -> planner -> executor -> thor -> check -> PR -> merge` into a portable state machine that can run on Claude CLI, Copilot CLI, and mesh nodes without repo-specific assumptions.

## Core Principle

Route by **capability + constraints**, not by tool ideology or repository type.

## Capability Taxonomy

| Capability | Responsibility | Typical models |
| --- | --- | --- |
| `planner` | Decompose work, assign waves/tasks, enforce constraints | Claude Opus 4.6 |
| `researcher` | Gather external/current context, ADR history, prior failures | GPT-5.4, Gemini, Opus |
| `executor` | Implement deterministic code/config/docs changes | GPT-5.3-Codex, Sonnet, Haiku |
| `validator` | Run Thor, verify requirements and gates | Claude Sonnet 4.6 |
| `reviewer` | Inspect PRs, security, regressions, architecture tradeoffs | GPT-5.4, Opus |
| `deployer` | Release, CI/CD follow-through, smoke checks, rollback prep | Sonnet, manual fallback |
| `operator` | Mesh sync, worktree moves, environment coordination | Lightweight model or script |

## Task Envelope

Every executable task should carry this contract, even if storage stays split across DB fields:

```json
{
  "capability": "executor",
  "objective": "Implement feature X",
  "constraints": ["C-01 no breaking change", "C-02 no secrets"],
  "worktree_path": "/abs/path",
  "executor_agent": "copilot",
  "model": "gpt-5.3-codex",
  "verify": ["npm test", "npm run typecheck"],
  "trust_zone": "repo-local",
  "platform_tags": ["typescript", "node", "web"],
  "handoff_to": ["validator"]
}
```

## Routing Rules

1. **Planner decides capability first**
2. **Node selection** uses worktree access, platform tags, online status, and trust zone
3. **Model selection** uses lowest-adequate-model policy
4. **Thor is independent of executor**
5. **Manual tasks are explicit** and front-loaded when possible

## Node Selection Heuristic

| Signal | Meaning |
| --- | --- |
| `worktree access` | Node can access the target repo/worktree safely |
| `platform_tags` | Node matches language/runtime/tooling needs |
| `trust_zone` | Secrets, prod, or regulated work allowed/not allowed |
| `health` | Node online, low drift, ready preflight |
| `load` | CPU/memory/task pressure acceptable |

## State Machine

```text
draft
  -> planned
  -> preflight_ready
  -> executing
  -> submitted
  -> thor_validating
  -> wave_validated
  -> pr_open
  -> ci_green
  -> merged
  -> complete
```

Allowed failure branches:

- `preflight_blocked`
- `blocked`
- `ci_failed`
- `needs_replan`
- `manual_required`

## Guardrails

| Guardrail | Why |
| --- | --- |
| Execution preflight snapshot | Prevent dirty worktree / auth / missing ops context |
| Worktree isolation | Prevent main branch corruption |
| Capability-aware routing | Avoid using coding models for architecture and vice versa |
| Thor per-task + per-wave | Objective completion gate |
| Dashboard health alerts | Make blocked/stale state visible |
| Plan DB only | Single source of truth for progress |

## Compaction Continuity

Manual or automatic compaction must never destroy workflow continuity.

Required continuity artifacts:

1. **Plan DB state**: task status, wave status, execution host, validator state
2. **Execution preflight snapshot**: fresh readiness view for the active plan
3. **Checkpoint summary**: current wave, blocked items, next command to run
4. **Dashboard organization snapshot**: current node -> pod -> task ownership

Rule: before any deliberate compaction or session handoff, persist the current phase to durable state first; after resume, reconstruct from DB/snapshots before taking action.

## Dynamic Agent Creation

Agents may be created dynamically when a wave requires a new capability bundle:

- `executor + reviewer` for risky refactors
- `researcher + planner` for ambiguous migrations
- `deployer + validator` for release waves

Creation rule:

1. Detect missing capability coverage in current wave
2. Spawn or assign the lightest available agent/tool that satisfies it
3. Register ownership in DB/dashboard as an **agent pod**

## Dashboard Contract

The dashboard should present the system as an **AI organization**, not a flat queue.

### Required views

| View | Purpose |
| --- | --- |
| Mission view | Plan/wave/task status |
| Organization view | Node -> squad -> agent pod -> live task |
| Health view | Preflight, Thor, CI, auth, drift |
| Event feed | Delegations, retries, merges, validations |
| Cost/model view | Token and model efficiency |

### Organization vocabulary

| Term | Meaning |
| --- | --- |
| `node` | Machine/mesh peer executing work |
| `squad` | Node-level working group |
| `agent pod` | Unique capability+agent+model assignment |
| `live task` | In-progress, submitted, or blocked work item |

## Cross-CLI Parity

| Concern | Claude CLI | Copilot CLI |
| --- | --- | --- |
| Planning | Opus planner | `@planner` |
| Execution | task-executor | `copilot-worker.sh` / agents |
| Validation | Thor subagent | `@validate` / Thor wrapper |
| Monitoring | Dashboard + hooks | Dashboard + hooks |

## Minimal Implementation Checklist

- Persist execution readiness
- Tag every task with executor + model
- Infer/render capability pods in dashboard
- Show node ownership for live work
- Keep Thor and CI state visible
- Make blocked states actionable

## Success Criteria

The system is working when:

1. Any new repo can be planned without custom workflow code
2. Any task can be routed to a compatible node/agent/model
3. Dashboard shows who is doing what, where, and why it is blocked
4. "Done" always means Thor-validated and operationally visible
