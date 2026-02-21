# @reference/ Token Impact Assessment (T2-04)

## Executive Summary

**Finding**: 9 @reference/ files consume **~5,371 tokens** on every turn
**Impact**: These tokens are ALWAYS loaded (not lazy) - wasted if unused
**Opportunity**: Compacting largest files could save 30-50% (1,500-2,500 tokens/turn)

## Context from T0-01

Test result confirmed: `@reference/` imports are **NOT lazy-loaded**
- Files are expanded into system prompt at session initialization
- All content is in context from turn 1 onwards
- Unused reference content = wasted tokens on every turn

## Current @reference/ Files in CLAUDE.md

| File                              | Lines | Words | Chars | Est. Tokens | % of Total |
|-----------------------------------|-------|-------|-------|-------------|------------|
| plan-db-schema.md                 | 226   | 1,329 | 7,420 | 1,727       | 32.1%      |
| tool-preferences.md               | 80    | 537   | 4,434 | 698         | 13.0%      |
| plan-scripts.md                   | 90    | 477   | 3,864 | 620         | 11.5%      |
| execution-optimization.md         | 82    | 430   | 3,481 | 559         | 10.4%      |
| concurrency-control.md            | 60    | 387   | 3,176 | 503         | 9.4%       |
| worktree-discipline.md            | 89    | 354   | 2,621 | 460         | 8.6%       |
| codegraph.md                      | 34    | 239   | 1,735 | 310         | 5.8%       |
| agent-routing.md                  | 51    | 197   | 1,815 | 256         | 4.8%       |
| digest-scripts.md                 | 27    | 182   | 1,354 | 236         | 4.4%       |
| **TOTAL**                         | **739** | **4,132** | **29,900** | **5,371** | **100%** |

## Priority Targets for Compaction (T2-05)

### High Priority (>500 tokens)
1. **plan-db-schema.md** (1,727 tokens, 32.1%)
   - Analysis: Contains detailed schema documentation
   - Opportunity: Remove verbose examples, consolidate table descriptions
   - Target: Reduce to ~800-1,000 tokens (save ~700-900 tokens)

2. **tool-preferences.md** (698 tokens, 13.0%)
   - Analysis: Tool usage guidelines and shell safety rules
   - Opportunity: Convert to compact reference table
   - Target: Reduce to ~400 tokens (save ~300 tokens)

3. **plan-scripts.md** (620 tokens, 11.5%)
   - Analysis: Script usage documentation
   - Opportunity: Remove redundant descriptions, use tighter formatting
   - Target: Reduce to ~400 tokens (save ~200 tokens)

### Medium Priority (400-500 tokens)
4. **execution-optimization.md** (559 tokens, 10.4%)
   - Opportunity: Consolidate best practices into bullet points

5. **concurrency-control.md** (503 tokens, 9.4%)
   - Opportunity: Remove examples, keep only core rules

6. **worktree-discipline.md** (460 tokens, 8.6%)
   - Opportunity: Compact workflow steps

### Low Priority (<400 tokens)
- codegraph.md (310 tokens) - Already compact
- agent-routing.md (256 tokens) - Already compact
- digest-scripts.md (236 tokens) - Already compact

## Token Savings Projection

| Scenario           | Files Targeted | Estimated Savings | New Total | Reduction |
|--------------------|----------------|-------------------|-----------|-----------|
| Conservative       | Top 3          | 1,200 tokens      | 4,171     | 22%       |
| Moderate           | Top 6          | 2,000 tokens      | 3,371     | 37%       |
| Aggressive         | All 9          | 2,500 tokens      | 2,871     | 47%       |

## Methodology

- **Token estimation**: 1.3 tokens per word (standard English approximation)
- **Line count**: `wc -l <file>`
- **Word count**: `wc -w <file>`
- **Verification**: Manual review of file content

## Recommendations for T2-05

1. **Start with top 3 files** (plan-db-schema, tool-preferences, plan-scripts)
2. **Compaction strategy**:
   - Remove verbose examples and explanations
   - Convert prose to tables/lists
   - Eliminate redundancy with CLAUDE.md core rules
   - Keep critical operational details
3. **Validation**: Ensure no workflow-critical content is lost (per rule #7)
4. **Measurement**: Document before/after token counts

## Related Tasks

- **T0-01**: Confirmed @reference/ imports are not lazy-loaded
- **T2-05**: Execute actual compaction of identified files
- **F-07**: Token optimization feature requirement

## Test Criteria Met

✅ Can read import test result: `cat .copilot-tracking/import-test-result.md`
✅ Documented which files are large and token impact
✅ Created assessment summary in .copilot-tracking/

---

**Generated**: 2024-02-21 22:30 CET
**Task**: T2-04 (db_id 3869)
**Plan**: 189 (EcosystemOptimization)
