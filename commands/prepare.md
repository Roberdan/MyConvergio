# Prepare - Project Context Bootstrap

Prepare a project for Claude: register + generate/update `CLAUDE.md`.

## Activation

Run `/prepare` in any repository to bootstrap the project.

## Behavior

1. **Detect project type** from manifest files
2. **Analyze structure** to identify key paths
3. **Generate CLAUDE.md** with standard sections
4. **Preserve existing** content if CLAUDE.md exists

## Detection Logic

### Project Type Detection

| File | Type | Default Commands |
|------|------|------------------|
| `package.json` | Node.js | npm run build/test/lint/dev |
| `Cargo.toml` | Rust | cargo build/test, cargo clippy |
| `go.mod` | Go | go build/test, golangci-lint |
| `pyproject.toml` | Python | pytest, ruff, mypy |
| `requirements.txt` | Python | pytest |
| `Makefile` | Generic | make build/test |

### Structure Analysis

1. List top-level directories
2. Identify patterns: src/, lib/, cmd/, internal/, components/
3. Detect frameworks: Next.js, FastAPI, Gin, etc.

## Generation Process

```
1. Register project: ~/.claude/scripts/register-project.sh $(pwd)
2. Check/create .claudeignore (optimize token usage)
3. Check if ./CLAUDE.md exists
4. If exists AND complete → skip to step 9 (already conformant)
5. If exists but incomplete → analyze missing sections, propose additions
6. If not exists → generate from template
7. Extract commands from package.json scripts (if Node.js)
8. Detect architecture from folder structure
9. Write CLAUDE.md (only if changes needed)
10. Confirm registration complete
```

**Key behavior**: Registration ALWAYS happens. CLAUDE.md only touched if needed.

## .claudeignore Optimization

If `.claudeignore` doesn't exist, create one based on project type:

**Node.js**:
```
node_modules/
dist/
.next/
coverage/
*.log
```

**Python**:
```
__pycache__/
.venv/
venv/
*.pyc
.pytest_cache/
```

**iOS/Swift**:
```
.build/
DerivedData/
*.xcworkspace
Pods/
```

**General** (always include):
```
.git/
.DS_Store
*.min.js
*.min.css
```

## Output Structure

Per `docs/project-context-spec.md`:

```markdown
# CLAUDE.md

[Auto-detected description or placeholder]

## Commands

[Extracted from manifest or detected]

## Architecture

**Stack**: [Detected]
**Key paths**: [From structure analysis]

## Project Rules

**Verification**: `[build + test + lint command]`
**Process**: [User input or placeholder]
**Constraints**: [User input or placeholder]
```

## Example Execution

```
> /prepare

Detected: Node.js project (package.json)
Stack: Next.js 14 + TypeScript + Prisma

Commands found:
- npm run dev
- npm run build
- npm run test
- npm run lint

Key paths detected:
- src/app/ (Next.js App Router)
- src/lib/ (utilities)
- prisma/ (database)

Generated CLAUDE.md with standard structure.
Please fill in:
- [ ] Project description (line 3)
- [ ] Process rules (line 18)
- [ ] Constraints (line 19-20)
```

## Flags

| Flag | Effect |
|------|--------|
| `--check` | Only check compliance, don't modify |
| `--force` | Overwrite existing CLAUDE.md |
| `--minimal` | Generate minimal 30-line version |

## Integration

After preparation, project works with:
- `/prompt` → Detects project context
- `/planner` → Uses project verification commands, shows dashboard
- `thor` → Validates against project rules

### Centralized Plans

When `/prepare` runs:
1. Creates `CLAUDE.md` in project root
2. Registers project in `~/.claude/plans/registry.json`
3. Creates plan folder: `~/.claude/plans/{project_id}/`

All plans are stored centrally, enabling:
- Multi-project dashboard view
- Plan version history for learning
- Cross-project analytics
