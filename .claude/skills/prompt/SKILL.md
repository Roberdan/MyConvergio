---
name: prompt
description: Extract structured requirements (F-xx) from user input. Outputs JSON to .copilot-tracking/
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
context: fork
user-invocable: true
version: "1.0.0"
---

# Prompt Translator Skill

> Reusable workflow extracted from prompt agent expertise.

## Purpose

Extract structured functional requirements (F-xx) from natural language user input, producing machine-readable JSON for downstream planning agents.

## When to Use

- New feature requests that need structured decomposition
- Ambiguous user input requiring clarification before planning
- Requirements extraction before `@planner` execution
- Any input that needs F-xx requirement mapping

## Workflow Steps

1. **Context Gathering**
   - Read repository state via `git-digest.sh`
   - Understand project structure and existing patterns

2. **Clarification (MANDATORY)**
   - Identify ambiguities in user input
   - Ask about: scope, negative requirements, edge cases, priority
   - NEVER fill gaps with assumptions — ask or mark TBD

3. **Requirement Extraction**
   - Extract EVERY requirement (explicit + implicit) as F-xx
   - Use EXACT user words — NEVER paraphrase
   - Each requirement needs: id, said (verbatim), verify (machine-checkable), priority

4. **Output Generation**
   - Save to `.copilot-tracking/prompt-{NNN}.json`
   - Include: objective, user_request, requirements[], scope, stop_conditions

5. **User Confirmation**
   - Ask "Have I captured everything? Anything missing?"
   - User confirms → offer handoff to `@planner`

## Inputs Required

- **User request**: Natural language description of desired feature/change
- **Repository context**: Auto-detected from current working directory

## Outputs Produced

- **Prompt JSON**: `.copilot-tracking/prompt-{NNN}.json` with structured F-xx requirements
- **Handoff**: Ready for `@planner` to create execution plan

## Output Format

```json
{
  "objective": "one sentence goal",
  "user_request": "EXACT user words, verbatim",
  "requirements": [
    { "id": "F-01", "said": "exact words", "verify": "how to check", "priority": "P1" }
  ],
  "scope": { "in": ["included"], "out": ["explicitly excluded by user"] },
  "stop_conditions": ["All F-xx verified", "Build passes", "User confirms"]
}
```

## Critical Rules

| Rule      | Requirement                                                             |
| --------- | ----------------------------------------------------------------------- |
| said      | EXACT user words, never paraphrase                                      |
| verify    | Machine-checkable (grep, test command, build passes), not prose         |
| scope.out | ONLY items USER explicitly said to exclude, NEVER add on own initiative |
| Purpose   | This JSON is read by planner agent to generate spec.json                |

## Related Agents

- **po-prompt-optimizer** - Prompt engineering and optimization
- **strategic-planner** - Strategic planning from requirements
- **ali-chief-of-staff** - Orchestration and delegation
