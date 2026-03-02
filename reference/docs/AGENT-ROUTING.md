# Agent Routing Architecture

**Last Updated**: 5 January 2026
**Status**: OPTIMIZED - Agents distributed by domain for context efficiency

---

## Architecture

### Local Agents (~/.claude/agents/)

**ONLY core agents that support Claude Code execution:**

| Agent             | Path                                              | Purpose                             | Used By              |
| ----------------- | ------------------------------------------------- | ----------------------------------- | -------------------- |
| **Thor**          | `core_utility/thor-quality-assurance-guardian.md` | Plan validation, quality gates      | Planner, Dashboard   |
| **Task-Executor** | `technical_development/task-executor.md`          | Execute plan tasks with DB tracking | Planner coordination |

### Remote Agents (~/GitHub/MyConvergio/agents/)

**All other agents by domain - called when needed:**

**Technical**:

- baccio-tech-architect.md
- dario-debugger.md
- marco-devops-engineer.md
- otto-performance-optimizer.md
- paolo-best-practices-enforcer.md
- rex-code-reviewer.md
- luca-security-expert.md
- diana-performance-dashboard.md

**Leadership**:

- ali-chief-of-staff.md
- amy-cfo.md
- antonio-strategy-expert.md
- dan-engineering-gm.md
- matteo-strategic-business-architect.md
- satya-board-of-directors.md

**Strategy & Planning**:

- strategic-planner.md
- socrates-first-principles-reasoning.md
- marcus-context-memory-keeper.md
- taskmaster-strategic-task-decomposition-master.md
- xavier-coordination-patterns.md
- wanda-workflow-orchestrator.md

**Other Domains**: (40+ agents for marketing, sales, HR, legal, design, operations, etc.)

---

## Routing Rules

### When to Use Local Agents

**Thor** (always available):

```bash
# For plan validation after wave completion
~/.claude/scripts/plan-db.sh validate {plan_id}
# Internally uses thor-quality-assurance-guardian.md
```

**Task-Executor** (internal agent):

```bash
# Called automatically by planner for task execution
# Never called directly - planner manages invocation
```

### When to Use Remote Agents

**Call from MyConvergio when needed:**

```typescript
await Task({
  subagent_type: "agent-name", // From ~/GitHub/MyConvergio/agents/
  description: "...",
  prompt: "...",
});
```

**Examples**:

- Architecture review → baccio-tech-architect
- Performance issue → dario-debugger or otto-performance-optimizer
- Code review → rex-code-reviewer
- Security audit → luca-security-expert
- Strategic planning → strategic-planner or ali-chief-of-staff

---

## Benefits

| Aspect                 | Benefit                                         |
| ---------------------- | ----------------------------------------------- |
| **Context Efficiency** | ~./claude/ stays lean (<10 agents)              |
| **Load Time**          | Only core agents loaded initially               |
| **Scalability**        | 60+ agents available on-demand in MyConvergio   |
| **Maintenance**        | Single source of truth (MyConvergio)            |
| **Flexibility**        | Easy to swap agents without touching ~/.claude/ |

---

## Decision Criteria

**Keep agent in ~/.claude/?**

| Question                                 | Answer = Keep Local       | Answer = Move to MyConvergio |
| ---------------------------------------- | ------------------------- | ---------------------------- |
| Is it required for every plan execution? | YES → Keep                | NO → Move                    |
| Is it needed to bootstrap Claude Code?   | YES → Keep                | NO → Move                    |
| Is it a quality gate?                    | YES → Keep                | NO → Move                    |
| Does it execute user tasks?              | Only Task-Executor → Keep | Others → Move                |
| Is it optional/domain-specific?          | (N/A)                     | YES → Move                   |

---

## Current State

### Optimized Structure

```
~/.claude/
├── agents/
│   ├── core_utility/
│   │   ├── CONSTITUTION.md (rules)
│   │   ├── EXECUTION_DISCIPLINE.md (rules, legacy)
│   │   └── thor-quality-assurance-guardian.md (CORE)
│   └── technical_development/
│       └── task-executor.md (CORE)
├── scripts/
│   ├── plan-db.sh (DB management)
│   ├── PLANNER-QUICKREF.md (docs)
│   └── ... (utilities)
├── commands/
│   ├── planner.md (skill)
│   ├── prompt.md (skill)
│   └── ... (skills)
└── AGENT-ROUTING.md (this file)

~/GitHub/MyConvergio/
└── agents/
    ├── ali-chief-of-staff.md
    ├── baccio-tech-architect.md
    ├── ... (60+ agents by domain)
    └── thor-quality-assurance-guardian.md (copy, reference)
```

---

## Migration Status

| Agent                 | Local | MyConvergio | Status                                |
| --------------------- | ----- | ----------- | ------------------------------------- |
| thor                  | ✓     | ✓           | **CORE locally, also in MyConvergio** |
| task-executor         | ✓     | -           | **CORE locally only**                 |
| All technical agents  | ✗     | ✓           | Moved ✅                              |
| All leadership agents | ✗     | ✓           | Moved ✅                              |
| All other agents      | ✗     | ✓           | Moved ✅                              |

---

## Context Optimization Impact

| Metric           | Before     | After      | Improvement             |
| ---------------- | ---------- | ---------- | ----------------------- |
| Local agents     | 15+        | 2          | **-87% (15 → 2)**       |
| Initial load     | ~35KB      | ~5KB       | **-86%**                |
| Startup time     | Slower     | Faster     | **~5x faster**          |
| Available agents | Same (60+) | Same (60+) | Zero loss of capability |

---

## See Also

- `~/.claude/rules/agent-discovery.md` - Agent discovery and routing patterns
- `~/.claude/PLANNER-ARCHITECTURE.md` - Plan execution architecture
- `~/.claude/commands/planner.md` - Planner skill documentation
