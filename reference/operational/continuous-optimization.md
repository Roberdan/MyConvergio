<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Continuous Optimization

Monthly checklist for Claude Code configuration health.

## Automated Audit (Monthly)

Run `~/.claude/scripts/context-audit.sh` and address all WARN/FAIL items.

### 10-Point Checklist

1. **Global CLAUDE.md** — Under 100 lines, no duplication with rules
2. **Rules files** — Each under 30 lines, no cross-file phrase duplication
3. **Agent files** — No boilerplate >200 lines, constitution injected via hook
4. **Claude Code version** — Latest stable from npm
5. **Hook health** — All hooks pass dry-run with empty JSON input
6. **Token usage** — Review 30-day trend, investigate spikes
7. **Project CLAUDE.md** — Each under 100 lines, project-specific content only
8. **Settings.json** — All hooks registered, status line working
9. **On-demand docs** — Referenced docs exist, no stale references
10. **Changelog review** — Check Claude Code release notes for new features

## Manual Review Process

### Configuration Review

- Read each rules file — still relevant? Any outdated references?
- Read each agent file — matches current project needs?
- Check settings.json — permissions, env vars, plugins current?

### Cross-Project Alignment

- Verify global conventions apply across all active projects
- Check project CLAUDE.md files don't duplicate global config
- Ensure project rules don't contradict global rules

### Token Usage Analysis

```bash
sqlite3 ~/.claude/data/dashboard.db "
  SELECT date(created_at) as day, SUM(input_tokens + output_tokens) as tokens,
         printf('%.2f', SUM(cost_usd)) as cost
  FROM token_usage
  WHERE created_at >= datetime('now', '-30 days')
  GROUP BY day ORDER BY day;
"
```

**Targets**: Cost per session trending down. Context window usage <80% average.

### Changelog Review Procedure

1. Check `claude --version` against npm latest
2. Review release notes for new hook events, settings, features
3. Update configuration to leverage new capabilities
4. Test hooks after any Claude Code update

## Optimization Triggers

Run audit immediately when:

- Claude Code major/minor version update
- New project onboarded
- Agent files modified
- Hook behavior changes observed
- Context window warnings appear frequently
