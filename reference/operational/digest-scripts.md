<!-- v2.2.0 | 01 Mar 2026 | c dispatcher aliases (Plan 290) -->

# Digest Scripts

> **Why**: Raw CLI output (npm build, gh run view, git log) produces 500-5000 lines. Digest scripts produce compact JSON (~10x less tokens), are cached, enforced by `prefer-ci-summary.sh` hook (exit 2 on raw commands).

> **Prefer `c` aliases — 60-80% fewer tokens than full script names.**

## Mapping (NON-NEGOTIABLE)

| Instead of                                             | Use                                      | `c` alias                    |
| ------------------------------------------------------ | ---------------------------------------- | ---------------------------- |
| `gh run view --log-failed`                             | `service-digest.sh ci`                   | `c d ci`                     |
| `gh pr view --comments`                                | `service-digest.sh pr`                   | `c d pr`                     |
| `vercel logs`                                          | `service-digest.sh deploy`               | `c d deploy`                 |
| `npm install` / `npm ci`                               | `npm-digest.sh install`                  | —                            |
| `npm run build`                                        | `build-digest.sh`                        | `c d build`                  |
| `npm audit`                                            | `audit-digest.sh`                        | —                            |
| `npx vitest` / `npm test`                              | `test-digest.sh`                         | `c d test`                   |
| `git diff main...feat`                                 | `diff-digest.sh main feat`               | `c d diff main feat`         |
| `npx prisma migrate`                                   | `migration-digest.sh status`             | —                            |
| merge/rebase conflicts                                 | `merge-digest.sh`                        | —                            |
| stack traces                                           | `cmd 2>&1 \| error-digest.sh`            | —                            |
| `git status` / `git log`                               | `git-digest.sh [--full]`                 | `c d git`                    |
| Copilot bot PR comments                                | `copilot-review-digest.sh`               | —                            |
| Manual audit scripts such as hardening-check + linters | `project-audit.sh --project-root $(pwd)` | —                            |
| `gh pr checks`                                         | `ci-digest.sh checks <pr>`               | `c ci checks <pr>`           |
| `CI polling post-merge`                                | `ci-watch.sh`                            | `c ci watch`                 |
| `sqlite3 dashboard.db`                                 | `db-digest.sh`                           | `c db stats`                 |
| `db-digest.sh token-stats`                             | `db-digest.sh token-stats`               | `c db token-stats`           |
| `db-digest.sh monthly`                                 | `db-digest.sh monthly`                   | `c db monthly`               |
| Per-model cost breakdown                               | `db-digest.sh cost-report <plan_id>`     | `c db cost-report <plan_id>` |
| `custom SQL query`                                     | `db-query.sh`                            | —                            |

## Options

- `--no-cache` — force fresh data (skip cached result)
- `--compact` — omit non-essential fields (~30-40% fewer tokens)
- Hook `prefer-ci-summary.sh` blocks raw commands automatically (exit 2)
