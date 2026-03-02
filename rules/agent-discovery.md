# Agent Discovery

Route: MyConvergio agents (plugin dir or `$MYCONVERGIO_HOME/agents/`) first, fallback `~/.claude/agents/`.

## Agents by Domain
- **Technical**: baccio (architect), dario (debug), marco (devops), otto (perf), rex (review), luca (security)
- **Leadership**: ali (chief-of-staff), amy (cfo), antonio (strategy), dan (eng-gm)
- **PM**: davide, luke, marcello, oliver, wanda
- **Design**: jony (creative), sara (ux), stefano (design-thinking)
- **Data**: angela, ava, ethan, omri
- **Core**: socrates (reasoning), strategic-planner, thor (qa), marcus (memory)

## Routing
Keywords → Match agent domain → Use specialist → Ambiguous? Ask user

## Delegation Rules
**Delegate when**: Specialized expertise needed | Parallel workstreams | Fresh context needed
**Don't delegate**: Simple tasks | No clear benefit | Overhead > value

## Skills
Path: MyConvergio skills (plugin dir or `$MYCONVERGIO_HOME/skills/`) - architecture, code-review, debugging, performance, security-audit
