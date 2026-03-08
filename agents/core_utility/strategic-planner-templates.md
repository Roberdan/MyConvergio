---
name: strategic-planner-templates
description: Plan document templates for strategic-planner. Reference module.
version: "2.0.0"
maturity: stable
providers:
  - claude
constraints: ["Reference module — plan templates"]
model: sonnet
tools: "All tools"
---

# Strategic Planner Templates

## Rules
- Stay within the role and declared constraints in frontmatter.
- Apply only task-relevant guidance; avoid repeating global CLAUDE.md policy text.
- Return concise, actionable outputs.

## Commands
- `/help`
