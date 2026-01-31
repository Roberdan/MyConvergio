# Codex Delegation Strategy

## When to Suggest Codex Delegation

Proactively propose delegating to Codex when the task is:

| Criteria | Examples |
|----------|----------|
| Mechanical/repetitive | Translations, bulk renames, boilerplate |
| Well-defined scope | "Replace X with Y in N files" |
| Low architectural risk | No cross-cutting logic changes |
| Parallelizable | Can run while Claude works on other tasks |
| Token-expensive for Claude | >500 lines of simple edits |

## Codex-Eligible Tasks

- `[TRANSLATE]` placeholder translations
- Test file boilerplate (mock setup, imports)
- Bulk rename/refactor (variable names, imports)
- Documentation generation (JSDoc, README sections)
- JSON/config file updates across many files
- CSS/Tailwind class bulk updates
- Adding missing i18n keys across locales
- Repetitive test case generation

## Claude-Only Tasks (NEVER delegate)

- Architectural decisions
- Security-sensitive code
- Complex debugging / root cause analysis
- ESLint rule creation
- Cross-cutting logic changes
- CI/build investigation
- Database schema changes
- API design

## Workflow

1. Claude identifies delegatable task
2. Claude proposes: "Questo task e' delegabile a Codex. Prompt suggerito: ..."
3. User confirms (or Claude waits ~1 min then does it)
4. After Codex finishes, Claude reviews and integrates

## Planner/Executor Integration

The planner SHOULD tag tasks with `codex: true` when they match delegation criteria.
The executor SHOULD propose delegation before starting codex-eligible tasks.

Task metadata example:
```
{ "codex": true, "prompt": "Translate [TRANSLATE] in messages/en/*.json" }
```
