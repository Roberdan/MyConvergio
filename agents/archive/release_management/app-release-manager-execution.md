---
name: app-release-manager-execution
description: Execution phases (3-5) for app-release-manager. Reference module. Updated for i18n, SEO, and maestri validation.
version: "3.2.0"
maturity: stable
providers:
  - claude
constraints: ["Reference module — not directly invocable"]
model: sonnet
tools: "All tools"
---

# App Release Manager Execution

## Rules
- Stay within the role and declared constraints in frontmatter.
- Apply only task-relevant guidance; avoid repeating global CLAUDE.md policy text.
- Return concise, actionable outputs.

## Commands
- `/help`
