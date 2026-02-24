# Compaction Preservation Rules

When rewriting, compacting, or optimizing ANY instruction/config/rule file, these categories MUST survive intact. Removing them = VIOLATION.

## NEVER Remove

| Category                         | Examples                                                                                      | Why                                                            |
| -------------------------------- | --------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **Quality gate commands**        | `npm run test:unit`, `npm run ci:summary`, `i18n:check`, `prisma generate`                    | Agents skip verification without explicit commands             |
| **Thor validation workflow**     | per-task Thor → `validate-task`, per-wave Thor → `validate-wave`, 10 gates, "NEVER skip Thor" | Agents self-report success; Thor is the only independent check |
| **Pre-commit/pre-push hooks**    | i18n:check always (not conditional), smart-test, env-var-audit                                | Hooks are the last defense before bad commits                  |
| **Mandatory verification steps** | "run tests before commit", "i18n sync after UI changes", "env var 4-place checklist"          | Every one of these was added because agents repeatedly forgot  |
| **Security constraints**         | CSP, RBAC, parameterized queries, WCAG, encryption                                            | Safety-critical; removal = vulnerability                       |
| **State management rules**       | "NO localStorage", "Zustand + REST only", session-based auth                                  | Architectural invariants with cascading effects                |
| **Worktree discipline**          | "NEVER git checkout on main", worktree-create.sh, isolation rules                             | Silent branch corruption without these                         |

## Compaction Checklist

Before finalizing any compacted file:

1. **Diff check**: Compare old vs new — list every removed section
2. **Category scan**: For each removal, verify it's NOT in the table above
3. **Command preservation**: Every CLI command from original MUST appear in output
4. **Workflow completeness**: If original had steps 1-6, output must have steps 1-6

## Compression Techniques (SAFE)

- Remove prose/explanations, keep commands and rules
- Merge related items into tables
- Use abbreviations (`env var` not `environment variable`)
- Remove examples if the rule is self-explanatory
- Collapse multi-line formatting into single lines

## Compression Techniques (FORBIDDEN)

- Removing entire workflow steps ("they'll figure it out")
- Dropping verification commands ("obvious")
- Merging distinct quality gates into one ("lint+test+build" → "validate")
- Removing "why" annotations on non-obvious rules
- Replacing explicit commands with vague instructions ("run appropriate checks")
