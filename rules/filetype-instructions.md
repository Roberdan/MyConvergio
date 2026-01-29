# File-Type Instructions

Apply matching conventions per file type. Standard best practices assumed — only project-specific overrides listed.

## TS/JS (`*.ts`, `*.tsx`, `*.js`, `*.jsx`)
Named imports, no default export (unless framework). `interface` > `type` for objects. `async/await` only. Try/catch at boundary. React: functional, named exports, props interface above component. Tests: colocated `.test.ts`, AAA pattern.

## Python (`*.py`)
PEP 8 + Black (88 chars). Type hints on public APIs. Google-style docstrings. Specific exceptions only. pytest + fixtures.

## Bash (`*.sh`)
`#!/usr/bin/env bash` + `set -euo pipefail`. Quote `"$vars"`. `local` in functions. `trap cleanup EXIT`.

## Markdown (`*.md`)
Single H1. Fenced code blocks with language. Max 120 chars. One sentence per line.

## Config (`*.json`, `*.yaml`, `*.toml`)
2-space indent. No secrets. Schema refs where supported.

## CSS (`*.css`, `*.scss`, `*.module.css`)
CSS Modules or BEM. `rem` for type, `px` for borders. Mobile-first. Max 3 nesting levels.

## SQL
UPPERCASE keywords. snake_case. Parameterized queries only. Index FKs.
