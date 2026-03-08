---
name: thor-validation-gates
description: Validation gates module for Thor. Reference only.
version: "3.3.0"
maturity: stable
providers:
  - claude
constraints: ["Reference module — validation rules"]
model: sonnet
tools: "All tools"
---

# Thor Validation Gates

## Rules
- Stay within the role and declared constraints in frontmatter.
- Apply only task-relevant guidance; avoid repeating global CLAUDE.md policy text.
- Return concise, actionable outputs.

## Commands
- `/help`
