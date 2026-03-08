---
name: task-executor-tdd
description: TDD workflow module for task-executor. Reference only.
version: "1.3.0"
maturity: preview
providers:
  - claude
constraints: ["Reference module — not directly invocable"]
model: sonnet
tools: "All tools"
---

# Task Executor Tdd

## Rules
- Stay within the role and declared constraints in frontmatter.
- Apply only task-relevant guidance; avoid repeating global CLAUDE.md policy text.
- Return concise, actionable outputs.

## Commands
- `/help`
