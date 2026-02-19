## Type of Change

- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Refactoring (no functional changes)
- [ ] Documentation
- [ ] CI/CD or infrastructure

## Changes Made

<!-- List specific changes. Be explicit — match your diff. -->

-
-

## Changes NOT Made

<!-- Explicitly state what is OUT OF SCOPE. This prevents scope creep. -->

-

## Verification Evidence

<!-- Paste actual output. "it works" is not evidence. -->
<!-- ADAPT: Replace rows below with project-specific commands -->

| Check               | Result                                     |
| ------------------- | ------------------------------------------ |
| Lint (frontend)     | `# ADAPT: npm run lint` — ? errors         |
| Lint (backend)      | `# ADAPT: ruff check .` — ? errors         |
| Typecheck           | `# ADAPT: npm run typecheck` — pass/fail   |
| Unit tests (FE)     | `# ADAPT: npm run test` — ?/? passed       |
| Unit tests (BE)     | `# ADAPT: pytest` — ?/? passed             |
| Build               | `# ADAPT: npm run build` — pass/fail       |
| DB migrations       | `# ADAPT: alembic upgrade head` — pass/N/A |
| E2E (if applicable) | pass/skip                                  |

## Workaround Declaration

<!-- MANDATORY: Declare any technical debt introduced. -->

- [ ] No `@ts-ignore`, `@ts-expect-error`, `type: ignore`, or `# noqa` added
- [ ] No `eslint-disable` or `ruff: noqa` without a tracking issue
- [ ] No hardcoded values that should be env vars

<!-- If any box is unchecked, explain WHY and link tracking issue. -->

## Checklist

- [ ] Self-reviewed the diff (not just "it compiles")
- [ ] Tests cover the change (new tests for new code)
- [ ] Environment variables documented in `.env.example`
- [ ] Database migrations included (if applicable)
- [ ] No secrets in code or logs
- [ ] Accessible (keyboard nav, contrast, screen reader if UI change)

## Reviewer Notes

<!-- Anything the reviewer should pay attention to? -->
