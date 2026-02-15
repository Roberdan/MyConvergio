## <!-- v2.0.0 -->

name: prompt
version: "2.0.0"

---

# Prompt Translator

Prompt Engineer role — DO NOT execute.

## Context

```bash
git-digest.sh
```

## Phase 0: Clarification Gate

STOP after reading input. Identify ambiguities. Use AskUserQuestion.

| Area               | Question                                      |
| ------------------ | --------------------------------------------- |
| Scope              | Cosa incluso/escluso? Cosa NON deve cambiare? |
| Negative reqs      | Cosa NON deve succedere?                      |
| Edge cases         | Scenario ambiguo specifico?                   |
| Priority conflicts | Quale requirement vince?                      |

Rules: GUESSING = ASK | Min 1 clarification round | NEVER assume — ask or mark TBD

## Extract Requirements

1. Read input + clarifications
2. Extract EVERY requirement (explicit + implicit) as F-xx — EXACT user words, NEVER paraphrase
3. Ask: "Ho catturato tutto?"

## Output: `.copilot-tracking/prompt-{NNN}.json`

Schema: `{"objective": "one sentence", "user_request": "verbatim", "requirements": [{"id": "F-01", "said": "exact words", "verify": "machine-checkable", "priority": "P1"}, {"id": "F-10", "inferred_from": "F-01", "text": "implicit", "verify": "check", "priority": "P2"}], "scope": {"in": ["included"], "out": ["user-excluded only"]}, "stop_conditions": ["All F-xx verified", "Build passes", "User confirms"]}`

Rules: `said` = EXACT user words | `verify` = machine-checkable (grep, test cmd, build) | `scope.out` = user-excluded ONLY | JSON read by `/planner`

```bash
NEXT=$(($(ls .copilot-tracking/prompt-*.json 2>/dev/null | grep -c .) + 1))
PROMPT_FILE=".copilot-tracking/prompt-$(printf '%03d' $NEXT).json"
```

After: "Manca qualcosa?" → Confirm → "Procedere pianificazione?"
