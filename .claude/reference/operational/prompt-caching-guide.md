<!-- v1.0.0 -->

# Prompt Caching Guide

## How It Works (Claude Code)

| Aspect               | Detail                                                     |
| -------------------- | ---------------------------------------------------------- |
| What is cached       | System prompt (frozen per session)                         |
| What changes         | User/assistant messages per turn                           |
| Configuration needed | None — Claude Code caches automatically                    |
| Cache scope          | Per model — Opus/Sonnet/Haiku have **separate** caches     |
| Cache TTL            | 5 min default, refreshed on each use; 1h via API parameter |

## Cost Math

| Operation   | Multiplier | vs base           |
| ----------- | ---------- | ----------------- |
| Cache write | 1.25x base | +25%              |
| Cache read  | 0.10x base | -90%              |
| Break-even  | ~2 reads   | covers write cost |

**Rule**: Long system prompts called repeatedly → significant savings. Single-use calls → no benefit.

## Best Practices (Maximize Cache Hits)

| Practice                                        | Reason                                                   |
| ----------------------------------------------- | -------------------------------------------------------- |
| No timestamps in system prompt                  | Dynamic content busts cache every turn                   |
| No dynamic MCP tool config mid-session          | Tool list changes invalidate cache                       |
| Keep agent .md files stable                     | First 4K tokens must be identical across calls           |
| Stable frontmatter (name, version, description) | Frontmatter is in first tokens — any change = cache miss |
| Dynamic content in user messages                | User messages are NOT cached — safe for dynamic data     |

## Cache Invalidation Triggers

| Trigger                      | Effect                                                  |
| ---------------------------- | ------------------------------------------------------- |
| Model switch (Sonnet → Opus) | Full cache miss — separate per-model caches             |
| Any change to system prompt  | Cache bust for that position and all tokens after it    |
| Adding/removing MCP tools    | Tool descriptions in system prompt → cache invalidation |
| Agent .md rewrite            | If first 4K tokens change, cache miss                   |

## Agent .md Files Guidelines

| Rule                         | Detail                                                         |
| ---------------------------- | -------------------------------------------------------------- |
| Stable frontmatter           | `name`, `version`, `description` — no per-session injections   |
| No timestamps in frontmatter | `last_updated: {date}` busts cache every session               |
| Dynamic context placement    | Inject in user messages, not system prompt                     |
| First 4K token discipline    | Most critical for cache; keep stable, high-signal content here |

## Environment Variable

```bash
DISABLE_PROMPT_CACHING=1  # Set to disable caching entirely (debug/testing)
```

## Reference

Anthropic docs: https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching
