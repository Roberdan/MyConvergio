# Claude Config

**Identity**: Principal Software Engineer. ISE Fundamentals apply.

**Rules**: execution.md | guardian.md | engineering-standards.md | file-size-limits.md | agent-discovery.md

**Preferences**: English (code/docs), Italian (speech) | Concise, no fluff | No emojis | Action-first | Datetime: DD Mese YYYY, HH:MM CET

**Refs**: [ISE Playbook](https://microsoft.github.io/code-with-engineering-playbook/) | [Claude Code Docs](https://docs.anthropic.com/en/docs/claude-code)

## System Architecture

### Components
- **Dashboard**: Real-time plan monitoring (http://localhost:31415)
- **Database**: SQLite at `~/.claude/data/dashboard.db` (tracks plans, waves, tasks, execution)
- **Agents**: Core utilities + can extend to MyConvergio agents (via agent-discovery routing)
- **Scripts**: Executor tracking and task markdown generation
- **Rules**: Complete engineering standards + security + testing + API design

### Quick Start: Planning a Task

```bash
# 1. Invoke strategic-planner agent (creates plan + wave + task markdown files)
claude "I need to implement XYZ feature"

# 2. Planner generates:
#    - ~/.claude/plans/active/{project}/plan-{id}.md
#    - ~/. claude/plans/active/{project}/plan-{id}/waves/W{X}-name.md
#    - ~/.claude/plans/active/{project}/plan-{id}/waves/W{X}/tasks/T{X}-task.md
#    - Database entries with markdown_path linking

# 3. View plan in dashboard
open http://localhost:31415

# 4. Start executor tracking when executing a task
source ~/.claude/scripts/executor-tracking.sh
executor_start {project} {task_id}
# ... do work ...
executor_complete
```

### Dashboard Features
- Tree navigation (waves → tasks)
- Live executor monitoring via SSE
- Conversation logging (user/assistant/tool/system)
- Task markdown file links
- Bug/todo quick entry

### Extended Agents
Routes from MyConvergio if needed (agent-discovery.md):
- Technical: baccio, dario, marco, otto, paulo, rex, luca
- Leadership: ali, amy, antonio, dan, etc.
- Design, Data, HR, Legal, Strategy, etc.

All available at `~/GitHub/MyConvergio/agents/`
