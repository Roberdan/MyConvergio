# @reference/ Import Loading Test Result

## RESULT: NOT lazy-loaded — always in context

## METHOD
Documentation review + operational observation

## EVIDENCE
Claude Code expands `@reference/` imports in CLAUDE.md into the system prompt at session initialization. All @-referenced files are included in the context window from turn 1, not loaded on-demand. This is observable from agent behavior: specialized agents immediately access content from @referenced files without explicit file reads.

## IMPLICATION
Each `@reference/` import contributes to token cost on every turn, regardless of whether that file's content is used. Large reference files should be consolidated or separated into truly lazy-loaded modules to minimize context bloat.

## Recommendation
- Audit `.copilot-tracking/CLAUDE.md` for oversized references
- Consolidate infrequently-referenced content into appendices
- Keep critical operational docs in main context; move supplementary docs to separate README or wiki
