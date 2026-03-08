---
name: strategic-planner-thor
description: Thor validation gates for strategic-planner. Reference module.
version: "2.1.0"
maturity: stable
providers:
  - claude
constraints: ["Reference module — validation rules"]
model: sonnet
tools: "All tools"
---

# Strategic Planner Thor

## Rules
- Stay within the role and declared constraints in frontmatter.
- Apply only task-relevant guidance; avoid repeating global CLAUDE.md policy text.
- Return concise, actionable outputs.

## Commands
- `/help`
