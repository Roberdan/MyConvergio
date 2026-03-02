<!-- v2.2.0 | 28 Feb 2026 | Add ci-watch.sh mapping -->

# Digest Scripts

> **Why**: Raw CLI output (npm build, gh run view, git log) produces 500-5000 lines. Digest scripts produce compact JSON (~10x less tokens), are cached, enforced by `prefer-ci-summary.sh` hook (exit 2 on raw commands).

## Mapping (NON-NEGOTIABLE)

| Instead of                                             | Use                                      |
| ------------------------------------------------------ | ---------------------------------------- |
| `gh run view --log-failed`                             | `service-digest.sh ci`                   |
| `gh pr view --comments`                                | `service-digest.sh pr`                   |
| `vercel logs`                                          | `service-digest.sh deploy`               |
| `npm install` / `npm ci`                               | `npm-digest.sh install`                  |
| `npm run build`                                        | `build-digest.sh`                        |
| `npm audit`                                            | `audit-digest.sh`                        |
| `npx vitest` / `npm test`                              | `test-digest.sh`                         |
| `git diff main...feat`                                 | `diff-digest.sh main feat`               |
| `npx prisma migrate`                                   | `migration-digest.sh status`             |
| merge/rebase conflicts                                 | `merge-digest.sh`                        |
| stack traces                                           | `cmd 2>&1 \| error-digest.sh`            |
| `git status` / `git log`                               | `git-digest.sh [--full]`                 |
| Copilot bot PR comments                                | `copilot-review-digest.sh`               |
| Manual audit scripts such as hardening-check + linters | `project-audit.sh --project-root $(pwd)` |
| `gh pr checks`                                         | `ci-digest.sh checks <pr>`               |
| Manual CI polling (`gh pr checks --watch`, run loops) | `ci-watch.sh <branch> --repo owner/repo` |

## Options

- `--no-cache` — force fresh data (skip cached result)
- `--compact` — omit non-essential fields (~30-40% fewer tokens)
- Hook `prefer-ci-summary.sh` blocks raw commands automatically (exit 2)
