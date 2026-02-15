---
name: docs
description: Update project documentation (ADRs, CHANGELOG, running notes) in compact Claude-friendly format
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash
context: fork
user-invocable: true
version: "1.0.0"
---

# Documentation Skill

> Update ADRs, CHANGELOG, and running notes outside of plan workflows.

## Purpose

Create and update project documentation using the compact Claude-friendly format defined in knowledge-codification.md. Use this when documentation needs updating but no plan is active.

## When to Use

- Creating new ADRs for decisions made outside plans
- Updating CHANGELOG.md after manual changes
- Documenting learnings from debugging sessions
- Updating running notes for ongoing work
- Post-release documentation updates

## Workflow

### 1. Detect Project Context

```bash
# Find project root (nearest package.json or .git)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "Project: $PROJECT_ROOT"
ls "$PROJECT_ROOT/docs/adr/" 2>/dev/null | tail -5
```

### 2. Read Format Rules

Read `~/.claude/commands/planner-modules/knowledge-codification.md` for:

- ADR compact format (max 20 lines, `Status: X | Date: Y | Plan: Z` on one line)
- CHANGELOG incremental format (`## [Unreleased]` sections)
- Running notes format (`docs/adr/plan-{id}-notes.md`)

### 3. Ask What to Document

Use AskUserQuestion:

- "What type of documentation?" (ADR / CHANGELOG / Running Notes / All)
- "What decision or change to document?" (free text)
- "Related to a specific plan?" (plan ID or none)

### 4. Determine Next ADR Number

```bash
# Find highest ADR number
ls docs/adr/[0-9]*.md 2>/dev/null | sort -t/ -k3 -n | tail -1
```

### 5. Write Documentation

#### ADR (max 20 lines)

```markdown
# ADR {NNNN}: {Title}

Status: Accepted | Date: {DD Mon YYYY} | Plan: {plan_id or "none"}

## Context

{2-3 sentences: what problem, when encountered}

## Decision

{2-3 sentences: what we chose, why}

## Consequences

- Positive: {outcome}
- Negative: {tradeoff}

## Enforcement

- Rule: `{eslint-rule-or-grep-pattern}`
- Check: `{verification command}`
- Ref: {related ADR IDs if any}
```

#### CHANGELOG (incremental)

```markdown
## [Unreleased]

### {Category}

- Added: {new feature/file}
- Changed: {modification}
- Fixed: {bug fix}
```

#### Running Notes

```markdown
# {Context} Running Notes

## {Section}

- Decision: {what and why, 1 line}
- Issue: {problem} -> Fix: {solution}
- Pattern: {reusable insight}
```

### 6. Verify

```bash
# ADR exists and is under 20 lines
wc -l docs/adr/{new-adr}.md
# CHANGELOG updated
grep -q 'Unreleased' CHANGELOG.md
```

## Format Rules (from knowledge-codification.md)

- **ADR max 20 lines**. No prose filler.
- **Status/Date/Plan on ONE line** (grep-friendly)
- **Consequences use `Positive:`/`Negative:` labels** (grep-friendly)
- **Enforcement MUST include a runnable check command**
- **One ADR per decision**. Don't merge unrelated learnings.
- **Code, comments, documentation**: ALWAYS in English

## Inputs Required

- **What to document**: Decision, change, learning, or bug fix
- **Document type**: ADR, CHANGELOG, running notes, or combination
- **Plan context**: Optional plan ID for cross-referencing

## Outputs Produced

- **ADR file**: `docs/adr/{NNNN}-{slug}.md` (compact format)
- **CHANGELOG entry**: Appended to `## [Unreleased]` section
- **Running notes**: Updated in `docs/adr/plan-{id}-notes.md`
