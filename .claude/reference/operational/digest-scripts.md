# Digest Scripts

> **Why**: Raw CLI output (npm build, gh run view, git log) produces 500-5000 lines
> that consume context and cause the agent to lose track of the actual task.
> Digest scripts produce compact JSON (~10x less tokens), are cached, and are
> enforced by the `prefer-ci-summary.sh` hook (exit 2 on raw commands).

## Mapping (NON-NEGOTIABLE)

| Instead of                 | Use                           |
| -------------------------- | ----------------------------- |
| `gh run view --log-failed` | `service-digest.sh ci`        |
| `gh pr view --comments`    | `service-digest.sh pr`        |
| `vercel logs`              | `service-digest.sh deploy`    |
| `npm install` / `npm ci`   | `npm-digest.sh install`       |
| `npm run build`            | `build-digest.sh`             |
| `npm audit`                | `audit-digest.sh`             |
| `npx vitest` / `npm test`  | `test-digest.sh`              |
| `git diff main...feat`     | `diff-digest.sh main feat`    |
| `npx prisma migrate`       | `migration-digest.sh status`  |
| merge/rebase conflicts     | `merge-digest.sh`             |
| stack traces               | `cmd 2>&1 \| error-digest.sh` |
| `git status` / `git log`   | `git-digest.sh [--full]`      |

## Options

- `--no-cache` — force fresh data (skip cached result)
- Hook `prefer-ci-summary.sh` blocks raw commands automatically (exit 2)
