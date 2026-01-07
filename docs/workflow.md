# MyConvergio Execution Workflow

This guide describes the standard end-to-end workflow for delivery.

## 1) Prompt
Use `/prompt` to extract requirements (F-xx), clarify scope, and confirm acceptance criteria.

Reference:
- `.claude/commands/prompt.md`

## 2) Planner
Use `/planner` to produce a multi-wave plan with tasks mapped to F-xx.

Reference:
- `.claude/commands/planner.md`

## 3) Execution + Tracking
Execute tasks and record progress with executor tracking helpers.

References:
- `EXECUTOR_TRACKING.md`
- `.claude/scripts/executor-tracking.sh`
- `.claude/scripts/generate-task-md.sh`

## 4) Thor QA Guardian
Use Thor to validate completion, evidence, and quality gates.

Reference:
- `.claude/agents/core_utility/thor-quality-assurance-guardian.md`

## 5) Dashboard
Use the dashboard to monitor plans, waves, tasks, notifications, and git activity.

References:
- `dashboard/`
- `dashboard/TEST-README.md`
