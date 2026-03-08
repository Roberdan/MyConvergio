# Planner Quality Gates

## Thor requirements
- Per-task Thor validation is mandatory.
- Per-wave Thor validation is mandatory after all task validations.
- Progress is based on Thor-validated tasks, not executor claims.

## Integration and closure gates
- Include explicit integration/wiring tasks for new exports or interfaces.
- Final wave must include `TF-tests` and `TF-pr`.
- `TF-tests` runs after implementation tasks, before `TF-pr`.
- Plan completion requires PR/CI merge-readiness evidence.

## Production deployment verification gate (NON-NEGOTIABLE)

Every plan's final wave (WF) MUST include a `TF-deploy-verify` task AFTER `TF-pr` that verifies the changes are live in production. This task:

1. Waits for deploy workflow to complete (CI green + deploy triggered)
2. Runs repo-specific health/smoke checks (see repo CLAUDE.md for `deploy_verification` section)
3. Verifies deployed version matches the version bumped in the plan
4. Reports evidence: health endpoint response, version string, smoke test result

If the repo has no `deploy_verification` config in its CLAUDE.md, the planner MUST ask the user how to verify deployment before generating the spec.

**Task order in WF**: `TF-tests` -> `TF-doc` -> `TF-pr` -> `TF-deploy-verify`

Skipping deploy verification = plan is NOT complete. `plan-db.sh complete` must not be called until deploy is confirmed.

## Codification gate
- Apply knowledge codification workflow from:
  - `@planner-modules/knowledge-codification.md`
- Ensure ADR + lint enforcement patterns are generated when applicable.
