# Claude Config

**Identity**: Principal Software Engineer. ISE Fundamentals apply.

**Rules**: execution.md | guardian.md | engineering-standards.md | file-size-limits.md | agent-discovery.md (detailed rules in rules/detailed/)

**Preferences**: English (code/docs), Italian (speech) | Concise, no fluff | No emojis | Action-first | Datetime: DD Mese YYYY, HH:MM CET

**Refs**: [ISE Playbook](https://microsoft.github.io/code-with-engineering-playbook/) | [Claude Code Docs](https://docs.anthropic.com/en/docs/claude-code)

## System Architecture

### Components
- **Dashboard**: Real-time plan monitoring (http://localhost:31415)
- **Database**: SQLite at `~/.claude/data/dashboard.db` (tracks plans, waves, tasks, execution)
- **Agents**: Core utilities + can extend to MyConvergio agents (via agent-discovery routing)
- **Scripts**: Executor tracking and task markdown generation
- **Rules**: Complete engineering standards + security + testing + API design

### Complete Workflow: Prompt → Plan → Execute → Verify

**Phase 1: Prompt Translation** (`/prompt`)
```
User request → F-xx extraction → Structured prompt → User confirms requirements
```

**Phase 2: Planning** (`/planner`)
```bash
# Register project
~/.claude/scripts/register-project.sh "$(pwd)" --name "Project"

# Create plan with F-xx requirements
~/.claude/scripts/plan-db.sh create {project_id} "{PlanName}"

# Add waves and tasks
~/.claude/scripts/plan-db.sh add-wave {plan_id} "W1" "Phase Name"
~/.claude/scripts/plan-db.sh add-task {db_wave_id} T1-01 "Task" P1 feature
```
**⛔ APPROVAL GATE**: User must approve F-xx list before execution

**Phase 3: Execution** (task-executor)
```
For EACH task:
1. plan-db.sh update-task {id} in_progress
2. Execute work
3. Verify F-xx criteria (MANDATORY)
4. plan-db.sh update-task {id} done "Summary"
```

**Phase 4: Thor Verification**
```bash
# After each wave
~/.claude/scripts/plan-db.sh validate-fxx {plan_id}  # F-xx check
~/.claude/scripts/plan-db.sh validate {plan_id}       # Full validation
npm run lint && npm run typecheck && npm run build    # Build check
```
**Wave done ONLY if**: All tasks done + Thor PASS + Build PASS

**Phase 5: Closure**
- All F-xx verified `[x]`
- All waves done
- Final Thor PASS
- User accepts

### Key Scripts Reference
| Script | Purpose |
|--------|---------|
| `plan-db.sh create` | Create new plan in DB |
| `plan-db.sh add-wave` | Add wave to plan |
| `plan-db.sh add-task` | Add task to wave |
| `plan-db.sh update-task` | Update task status |
| `plan-db.sh validate` | Full plan validation |
| `plan-db.sh validate-fxx` | F-xx requirements check |
| `register-project.sh` | Register project in DB |
| `executor-tracking.sh` | Track task execution |

### Dashboard Features
- Tree navigation (waves → tasks)
- Live executor monitoring via SSE
- Conversation logging (user/assistant/tool/system)
- Task markdown file links
- Bug/todo quick entry
- Gantt view with drill-down

### Extended Agents
Routes from MyConvergio if needed (agent-discovery.md):
- Technical: baccio, dario, marco, otto, paulo, rex, luca
- Leadership: ali, amy, antonio, dan, etc.
- Design, Data, HR, Legal, Strategy, etc.

All available at `~/GitHub/MyConvergio/agents/`
