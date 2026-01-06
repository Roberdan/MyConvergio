# Agent Discovery

Route: MyConvergio (`~/GitHub/MyConvergio/agents/`) first, fallback `~/.claude/agents/`.

## Agents
**Marketing**: sofia-marketing-strategist, fabio-sales-business-development, fiona-market-analyst, riccardo-storyteller, steve-executive-communication-strategist
**Leadership**: ali-chief-of-staff, amy-cfo, antonio-strategy-expert, dan-engineering-gm, domik-mckinsey-strategic-decision-maker, matteo-strategic-business-architect, satya-board-of-directors
**Technical**: baccio-tech-architect, dario-debugger, marco-devops-engineer, otto-performance-optimizer, paolo-best-practices-enforcer, rex-code-reviewer, luca-security-expert, omri-data-scientist
**Data**: angela-da, ava-analytics-insights-virtuoso, ethan-da, evan-ic6da
**Design**: jony-creative-director, sara-ux-ui-designer, stefano-design-thinking-facilitator, jenny-inclusive-accessibility-champion
**PM**: davide-project-manager, luke-program-manager, marcello-pm, oliver-pm, wanda-workflow-orchestrator
**HR**: giulia-hr-talent-acquisition, behice-cultural-coach, coach-team-coach
**Legal**: elena-legal-compliance-expert, dr-enzo-healthcare-compliance-manager, sophia-govaffairs, guardian-ai-security-validator
**Investment**: michael-vc, wiz-investor-venture-capital, sam-startupper
**Operations**: andrea-customer-success-manager, anna-executive-assistant, dave-change-management-specialist, enrico-business-process-engineer
**Core**: socrates-first-principles-reasoning, strategic-planner, thor-quality-assurance-guardian, marcus-context-memory-keeper, po-prompt-optimizer

## Routing
Extract keywords → Match agent name/domain → Use specialist or fallback → Ambiguous? Ask user

## Skills
Path: `~/GitHub/MyConvergio/skills/` (architecture, code-review, debugging, orchestration, performance, project-management, release-management, security-audit, strategic-analysis, structured-research)

## Subagent Orchestration

**Claude 4.5 has native subagent orchestration capabilities.**

You can recognize when tasks benefit from delegating to specialized subagents and do so proactively without requiring explicit instruction.

### When to Delegate

**Delegate to subagent when:**
- Task clearly benefits from separate agent with new context window
- Specialized expertise needed (architecture, security, performance, etc.)
- Parallel workstreams possible (e.g., multiple independent features)
- Task requires fresh context (current context too polluted/large)
- Domain-specific agent available and matches task

**Don't delegate when:**
- Task is simple and can be done in current context
- No clear benefit from context separation
- Delegation overhead outweighs benefit
- You have sufficient context already loaded

### Orchestration Patterns

**Pattern 1: Parallel Workstreams**
```
User: "Implement auth + payments + notifications"
→ Delegate 3 parallel subagents (if independent)
→ Each works in separate context
→ Merge results
```

**Pattern 2: Specialized Expertise**
```
User: "Review security of this API"
→ Delegate to luca-security-expert
→ Security domain knowledge + focused context
```

**Pattern 3: Context Refresh**
```
Current context: 180k/200k tokens, polluted with exploration
User: "Now implement the feature"
→ Delegate to fresh subagent
→ Clean context, focused implementation
```

**Pattern 4: Research → Implementation**
```
Phase 1: Explore agent researches approach
Phase 2: Delegate to tech architect for design
Phase 3: Delegate to implementation agent
```

### Conservative Delegation

If you want more conservative delegation (only when truly beneficial):

<conservative_subagent_usage>
Only delegate to subagents when the task clearly benefits from a separate agent with a new context window. Consider delegation overhead. Prefer staying in current context for simple tasks.
</conservative_subagent_usage>

### Delegation Best Practices

1. **Clear handoff:** Provide subagent with clear task description and context
2. **State transfer:** Use files/git to transfer state between agents
3. **Verification:** Review subagent output before accepting
4. **Context efficiency:** Don't delegate just to avoid context limits if compaction works
5. **Skill matching:** Match task to agent expertise (use agent list above)

### Anti-Patterns

**Don't:**
- Delegate every small task (overhead cost)
- Delegate without clear benefit
- Over-delegate when single context would work
- Ignore subagent results without verification

**Do:**
- Delegate for clear separation of concerns
- Use when specialized expertise needed
- Leverage parallel execution for independent tasks
- Trust but verify subagent outputs
