# Prepare - Project Bootstrap

Run `/prepare` to register project + generate/update `CLAUDE.md`.

## Workflow
1. Detect project type (package.json→Node, Cargo.toml→Rust, go.mod→Go, pyproject.toml→Python)
2. Analyze structure (src/, lib/, components/)
3. Detect icon (public/logo*.png, assets/icon*.png, favicon.*)
4. Create/update CLAUDE.md + .claudeignore
5. Register in `~/.claude/plans/registry.json` (includes icon path)

## Detection
| File | Type | Commands |
|------|------|----------|
| package.json | Node.js | npm run build/test/lint |
| Cargo.toml | Rust | cargo build/test/clippy |
| go.mod | Go | go build/test |
| pyproject.toml | Python | pytest, ruff, mypy |

## .claudeignore (auto-created)
Node: node_modules/, dist/, .next/, coverage/
Python: __pycache__/, .venv/, .pytest_cache/
General: .git/, .DS_Store, *.min.js

## Output: CLAUDE.md
```markdown
# CLAUDE.md
[Description]

icon: [detected or suggested path]

## Commands
[From manifest]

## Architecture
**Stack**: [Detected] | **Paths**: [Key dirs]

## Project Rules
**Verification**: `[build+test+lint]`
```

## Icon Detection
Search order: `public/logo*.png` → `assets/icon*.png` → `.claude/icon.png` → `favicon.*`
If found, suggest adding `icon: <path>` to CLAUDE.md. User confirms.

## Flags
`--check` Only verify | `--force` Overwrite | `--minimal` 30-line version

## Integration
After prepare: /prompt detects context, /planner uses commands, thor validates rules
