---
name: strategic-planner-thor
description: Thor validation gates for strategic-planner. Reference module.
version: "2.0.0"
maturity: stable
providers:
  - claude
constraints: ["Read-only — never modifies files"]
---

# Thor Validation Gate (MANDATORY)

**Thor is Roberto's digital enforcer. NO Claude may claim "done" without Thor's approval.**

## Setup: Launch Thor as Dedicated Tab

```bash
# Thor runs in its own Kitty tab, monitoring the validation queue
~/.claude/scripts/thor-queue-setup.sh

# Launch Thor tab
kitty @ new-window --title "Thor-QA" --cwd [project_root]
kitty @ send-text --match title:Thor-QA "wildClaude" && kitty @ send-key --match title:Thor-QA Return

# Wait for Claude to start, then:
kitty @ send-text --match title:Thor-QA "You are Thor. Monitor /tmp/thor-queue/requests/ for validation requests. For each request, validate according to your protocol and respond in /tmp/thor-queue/responses/. Start monitoring now." && kitty @ send-key --match title:Thor-QA Return
```

---

## Worker Validation Flow

Every worker (Claude 2, 3, 4) MUST do this before claiming ANY task complete:

```bash
# 1. Worker prepares validation request
REQUEST_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

# 2. Create request file with evidence
cat > /tmp/thor-queue/requests/${REQUEST_ID}.json << EOF
{
  "request_id": "${REQUEST_ID}",
  "worker_id": "Claude-2",
  "task_reference": "W1-T03",
  "claim": "JWT authentication implemented",
  "evidence": {
    "test_output": "[paste actual test output]",
    "lint_output": "[paste actual lint output]",
    "git_branch": "$(git branch --show-current)",
    "git_status": "[paste actual git status]"
  }
}
EOF

# 3. Notify Thor
kitty @ send-text --match title:Thor-QA "[VALIDATION REQUEST] ${REQUEST_ID} from Claude-2" && kitty @ send-key --match title:Thor-QA Return

# 4. Wait for response
while [ ! -f /tmp/thor-queue/responses/${REQUEST_ID}.json ]; do sleep 5; done

# 5. Read response
cat /tmp/thor-queue/responses/${REQUEST_ID}.json
```

---

## Thor's Brutal Validation

Thor will:
1. **Read the original task** from the plan
2. **Verify EVERY requirement** was completed
3. **Run the tests himself** - not trust claims
4. **Challenge the worker**: "Are you BRUTALLY sure?"
5. **Invoke specialists** if needed (Baccio for architecture, Luca for security)
6. **APPROVE or REJECT** - no middle ground

---

## Response Handling

- **APPROVED**: Worker may mark task ✅ and proceed
- **REJECTED**: Worker MUST fix ALL issues and resubmit
- **CHALLENGED**: Worker MUST provide requested evidence
- **ESCALATED**: Worker STOPS and waits for Roberto (after 3 failures)

---

## Plan Template Addition

Add this to every plan:

```markdown
## 🔱 THOR VALIDATION STATUS

| Worker | Task | Request ID | Status | Retry |
|--------|------|------------|--------|:-----:|
| Claude-2 | W1-T03 | abc123 | ✅ APPROVED | 1 |
| Claude-3 | W1-T05 | def456 | ❌ REJECTED | 2 |

### Validation Queue
- Thor Tab: Thor-QA
- Queue Dir: /tmp/thor-queue/
- Protocol: ~/.claude/agents/core_utility/thor-quality-assurance-guardian.md

### Worker Reminder
⚠️ **YOU ARE NOT DONE UNTIL THOR SAYS YOU ARE DONE**
Before marking ANY task complete:
1. Submit validation request to Thor
2. Wait for Thor's response
3. If REJECTED: Fix everything, resubmit
4. Only after APPROVED: Mark task ✅
```

---

## Integration with Thor Agent

Thor validation uses the consolidated Thor agent at:
`~/.claude/agents/core_utility/thor-quality-assurance-guardian.md`

Thor enforces:
- F-xx functional requirements verification
- 6 validation gates (Task, Code, ISE, Repo, Docs, Git)
- Brutal challenge questions
- ISE Engineering Fundamentals compliance

---

## Changelog

- **2.0.0** (2026-01-10): Extracted from strategic-planner.md for modularity
