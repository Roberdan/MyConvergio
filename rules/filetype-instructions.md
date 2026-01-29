# File-Type Instructions

Context-aware coding conventions. Apply the matching section when working on files of that type.

## TypeScript / JavaScript (`*.ts`, `*.tsx`, `*.js`, `*.jsx`)
- **Imports**: Named imports, no default export unless framework requires it
- **Types**: Explicit return types on public functions. Prefer `interface` over `type` for objects
- **Null safety**: Strict null checks. Use optional chaining (`?.`) and nullish coalescing (`??`)
- **Async**: Always `async/await`, never raw `.then()` chains
- **Error handling**: Try/catch at boundary, typed errors, never swallow exceptions
- **Components (React)**: Functional only, named exports, props interface above component
- **Tests**: Colocated `__tests__/` or `.test.ts`. Jest/Vitest. Arrange-Act-Assert pattern

## Python (`*.py`, `*.ipynb`)
- **Style**: PEP 8 + Black formatter. Max 88 chars/line
- **Types**: Type hints on all public functions. Use `from __future__ import annotations`
- **Imports**: stdlib → third-party → local (isort order). Absolute imports preferred
- **Error handling**: Specific exceptions, never bare `except:`. Custom exceptions inherit from base
- **Tests**: pytest with fixtures. Colocated `tests/` directory. Parametrize for variants
- **Docstrings**: Google style for public APIs. Module-level docstring required

## Bash / Shell (`*.sh`)
- **Header**: `#!/usr/bin/env bash` + `set -euo pipefail`
- **Variables**: Quote all `"$variables"`. Use `local` in functions. UPPER_CASE for exports
- **Functions**: Declare before use. Return exit codes, not strings. Use `readonly` for constants
- **Error handling**: `trap cleanup EXIT`. Check command existence with `command -v`
- **Portability**: Prefer POSIX when possible. Use `[[ ]]` over `[ ]` for bash-specific
- **Tests**: Use `bats` framework if available. Test edge cases with empty inputs

## Markdown (`*.md`)
- **Structure**: Single H1, logical heading hierarchy (no skipping levels)
- **Links**: Relative paths for internal docs. Check link validity
- **Tables**: Align columns. Header separator required. Keep concise
- **Code blocks**: Always specify language. Use fenced blocks (triple backtick)
- **Line length**: Max 120 chars for readability. One sentence per line preferred
- **Lists**: Consistent markers (- for unordered). Blank line before/after lists

## Infrastructure as Code (`*.tf`, `*.tfvars`, `*.bicep`)
- **Naming**: snake_case for resources. Descriptive names with environment prefix
- **Modules**: DRY through modules. Pin versions. Document inputs/outputs
- **State**: Remote state with locking. Never commit state files
- **Security**: No hardcoded secrets. Use variables with `sensitive = true`
- **Tagging**: All resources tagged with: environment, project, owner, managed-by

## Configuration (`*.json`, `*.yaml`, `*.yml`, `*.toml`)
- **JSON**: No comments (use `.jsonc` if needed). Consistent indentation (2 spaces)
- **YAML**: 2-space indent. No tabs. Explicit string quoting for ambiguous values
- **Secrets**: Never in config files. Use environment variable references
- **Validation**: Schema references where supported (`$schema` in JSON)
- **Defaults**: Document all non-obvious defaults. Group related settings

## CSS / Styling (`*.css`, `*.scss`, `*.module.css`)
- **Methodology**: BEM or CSS Modules. No global styles without namespace
- **Units**: `rem` for typography, `px` for borders. Avoid `!important`
- **Variables**: CSS custom properties for theming. Define in `:root`
- **Responsive**: Mobile-first. Use semantic breakpoints
- **Performance**: Minimize specificity. Avoid deep nesting (max 3 levels in SCSS)

## SQL (`*.sql`)
- **Keywords**: UPPERCASE (`SELECT`, `FROM`, `WHERE`)
- **Naming**: snake_case tables/columns. Singular table names. `_id` suffix for PKs
- **Safety**: Always use parameterized queries. Never string interpolation
- **Migrations**: Sequential numbering. Include up AND down. Idempotent when possible
- **Performance**: Index foreign keys. EXPLAIN ANALYZE on complex queries
