# File Size Limits

> Global rule for maintainability and token optimization.

**Last Updated**: 3 Gennaio 2026, 16:52 CET

---

## Core Rule

**Maximum 250 lines per file.** No exceptions without explicit approval.

### Why

1. **Token optimization**: Smaller files = less context = lower costs
2. **Maintainability**: Single responsibility, easier to navigate
3. **Parallel execution**: Smaller units can be processed independently
4. **Review efficiency**: Easier to review, fewer merge conflicts

---

## Split Strategies

### Plans (docs/plans/)

When a plan exceeds 250 lines, split into:

```
docs/plans/
├── ProjectPlan-Main.md      # Tracker only (max 250 lines)
│   ├── Overview & objectives
│   ├── Phase list with status
│   ├── Progress summary table
│   └── Links to phase files
├── ProjectPlan-Phase1.md    # Phase details (max 250 lines each)
├── ProjectPlan-Phase2.md
└── ProjectPlan-Phase3.md
```

**Main file structure**:
```markdown
# ProjectPlan - Main Tracker

**Created**: DD Mese YYYY, HH:MM CET

## Phases Overview

| Phase | File | Status | Progress |
|-------|------|--------|----------|
| 1 | [Phase1](./ProjectPlan-Phase1.md) | In Progress | 3/10 |
| 2 | [Phase2](./ProjectPlan-Phase2.md) | Pending | 0/8 |

## Global Progress: 3/18 (17%)
```

### Code Files

When a code file exceeds 250 lines:

1. **Extract modules**: Move related functions to separate files
2. **Split by responsibility**: One concern per file
3. **Use barrel exports**: `index.ts` to re-export

```
src/auth/
├── index.ts           # Re-exports (< 50 lines)
├── login.ts           # Login logic (< 250 lines)
├── logout.ts          # Logout logic (< 250 lines)
├── token.ts           # Token management (< 250 lines)
└── types.ts           # Type definitions (< 250 lines)
```

### Agent/Command Files

When an agent or command exceeds 250 lines:

1. **Core file**: Identity, main behavior, key rules
2. **Reference files**: Detailed examples, edge cases, historical learnings

```
agents/
├── thor-quality-assurance-guardian.md       # Core (< 250 lines)
└── thor-quality-assurance-guardian-ref.md   # Reference material
```

---

## Exceptions

Files that MAY exceed 250 lines:

- `package.json`, `tsconfig.json` (generated/config)
- Vendor/third-party files
- Auto-generated files (migrations, schemas)
- Single-file exports required by framework

**Must be documented**: If exceeding limit, add comment explaining why.

---

## Validation

Before committing, check:

```bash
# Find files exceeding 250 lines
find . -name "*.md" -o -name "*.ts" -o -name "*.tsx" | xargs wc -l | awk '$1 > 250'
```

Thor validates this gate. Files > 250 lines without exception = REJECTED.

---

## Enforcement

| Actor | Responsibility |
|-------|----------------|
| `/planner` | Create split plans by default |
| `/prompt` | Include split requirement in prompts |
| Agents | Self-check before output |
| `thor` | Validate all files < 250 lines |
