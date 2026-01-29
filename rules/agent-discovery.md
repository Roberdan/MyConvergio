# Agent Discovery & Maturity

Route: MyConvergio agents first (`$MYCONVERGIO_HOME/agents/`), fallback `~/.claude/agents/`.

## Agents by Domain
- **Technical**: baccio (architect), dario (debug), marco (devops), otto (perf), rex (review), luca (security)
- **Leadership**: ali (chief-of-staff), amy (cfo), antonio (strategy), dan (eng-gm)
- **PM**: davide, luke, marcello, oliver, wanda
- **Design**: jony (creative), sara (ux), stefano (design-thinking)
- **Data**: angela, ava, ethan, omri
- **Core**: socrates (reasoning), strategic-planner, thor (qa), marcus (memory)

## Routing
Keywords → Match domain → Use specialist → Ambiguous? Ask user
**Delegate when**: Specialist needed | Parallel work | Fresh context
**Don't delegate**: Simple tasks | Overhead > value

## Skills
Path: `$MYCONVERGIO_HOME/skills/` — architecture, code-review, debugging, performance, security-audit

## Maturity Lifecycle
`experimental → preview → stable → deprecated`. Prefer `stable`. New = `experimental`.

**Stable agents**: strategic-planner, thor, task-executor, marcus, socrates, wanda, xavier
**Preview agents**: diana, po, taskmaster, app-release-manager
**Stable skills**: architecture, code-review, debugging, security-audit
**Preview skills**: performance, orchestration
**Deprecated**: strategic-analysis, project-management (in `.disabled/`)
