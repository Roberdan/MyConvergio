---
name: task-executor-selfheal
description: Self-healing module for task-executor. Auto-diagnose, auto-fix, engage specialists.
version: "1.0.0"
maturity: stable
providers:
  - claude
constraints: ["Reference module — not directly invocable"]
model: sonnet
tools: "All tools"
---

# Task Executor Selfheal

## Rules
- Stay within the role and declared constraints in frontmatter.
- Apply only task-relevant guidance; avoid repeating global CLAUDE.md policy text.
- Return concise, actionable outputs.

## Commands
- `/help`
