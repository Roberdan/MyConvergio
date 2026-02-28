# Plan 149 TokenOptimization Running Notes

## W0: Baseline + Format Definition

- Decision: Compact Markdown (not YAML, not JSON) — universal LLM compatibility
- Baseline: 39,047 tokens / 52 files (26,116 global, 12,931 MirrorBuddy)
- Top consumers: planner.md (3,652), thor agent (2,314), CLAUDE.md (1,821)
- Research: LLMLingua 20x, CompactPrompt 60%, SuperClaude symbols INCREASE tokens
- Key insight: @imports + progressive disclosure + max 150 instructions

## W1: Workflow Integrity

- Decision: Validation gate enforcement (agent self-report cannot bypass Thor verification)
- Issue: `validate-task` without guards could be invoked by any agent, skipping required Thor checks
- Fix: Added `--force` flag to `cmd_validate_task()` — standard validation requires 'thor' or 'thor-quality-assurance-guardian' as validated_by
- Issue: Wave validation could pass even if individual tasks lacked validated_at timestamps
- Fix: Added per-task `validated_at` check in `cmd_validate_wave()` — blocks wave completion if any done task has NULL validated_at
- Issue: Developers could commit code with unvalidated tasks (broke Gate 9 Constitution checks)
- Fix: Created pre-commit hook `scripts/hooks/thor-commit-guard.sh` (49 lines) — blocks commit if any task in plan lacks validated_at
- Issue: Documentation for `file-lock.sh` was incomplete/incorrect (mentioned non-existent 'release-all')
- Fix: Updated `plan-scripts.md` with complete command reference (release-task for single task, not release-all)
- Learning: Three-layer validation (per-task + per-wave + pre-commit) prevents self-report loopholes

## W2: Core Global Files

- Decision: Dense reference library over monolithic instructions. @imports + progressive disclosure enables context reuse without bloat.
- Insight: CLAUDE.md 153→57 lines (-62.7%) via @imports shows that ~73% of system prompt is reference material better served on-demand. Baseline: 1,821 tokens. Post-optimization: ~540 tokens. Delta: -1,281 tokens per session.
- Insight: Three-file extraction strategy: workflow-details.md (process phase diagram), thor-gate-details.md (Gate 1-9 matrix), agent-routing.md (routing table). Each @imported only when needed.
- Insight: guardian.md + coding-standards.md now versioned (v2.0.0) with keyword-dense bullets. Enabled dense tagging (Done Criteria [x]/[ ], F-xx format, Gate matrix). Average -27% reduction.
- Insight: Operational reference lib (11 files) versioned v2.0.0. Pattern: 1-line description + keyword table + example. Enables fast lookup (< 5 sec scan). copilot-alignment -26%, tool-preferences -13%, worktree-discipline -10%.
- Learning: Dense markup (tables, bullets, cross-references) compresses better than prose. Prose-based instructions bloat during refinement; structured markup scales.

## W3: Commands & Agents

- Decision: planner.md required 3 passes to reach <160 line target; tables are the biggest token saver for structured rules
- Pattern: Commands already compact (prompt.md, prepare.md) saw minimal reduction; larger files benefit most
- Issue: copilot-agents had many files with similar structure → bulk rewrite approach more efficient
- Insight: @imports in planner.md (module refs) follow same progressive disclosure as CLAUDE.md

## W4: MirrorBuddy Project Files

- Decision: Apply same compact format (ADR 0009) to MirrorBuddy project files — consistency across repos
- Files: copilot-instructions.md, 9 instructions, 9 agents, 6 prompts, CLAUDE.md = 26 files total
- Pattern: MirrorBuddy agents/instructions had verbose prose; compact format with tables + keyword-dense bullets
- Insight: Project-level CLAUDE.md benefits most from compact format — loaded every session
- Learning: Bulk rewrite (agents, instructions, prompts) more efficient than individual optimization

## W5: Validation & Measurement

- Decision: Use tiktoken cl100k_base (same as baseline) for accurate comparison; Python script for automation
- Measurement: 26 global files, 26,116→22,074 tokens (15.5% reduction), 4,645→2,437 lines (47.5% reduction)
- Status: BELOW 40-60% target due to scope limitations and structural constraints
- Best performers: CLAUDE.md (64.3% reduction, 1,821→651 tokens), execute.md (42.4%, 1,872→1,079)
- Unchanged files (5): thor-quality-assurance-guardian.md (2,314), thor-validation-gates.md (1,431), PLANNER-QUICKREF.md (1,450), PLANNER-ARCHITECTURE.md (856), guardian.md (311). Total: 8,366 tokens (32% of baseline) not optimized.
- Increased files (10): plan-scripts.md (+19.6%), codegraph.md (+9.5%), execution-optimization.md (+6.8%), external-services.md (+5.0%), coding-standards.md (+4.1%), continuous-optimization.md (+3.6%), validate.agent.md (+3.2%), concurrency-control.md (+2.7%), digest-scripts.md (+0.8%), prepare.md (+1.1%). Total: +282 tokens. Cause: Structural additions (tables, cross-refs) and clarifications added during prior waves.
- Insight: Token reduction != line reduction. Dense tables and cross-references compress lines but may increase tokens (tokenizer sees more symbols/punctuation).
- Insight: ~73% of reduction came from 2 files (CLAUDE.md, execute.md). Remaining 24 files averaged 6.8% reduction.
- Smoke test: All markdown valid, all @import refs resolve, all JSON valid. Single warning: memory file ref in memory-protocol.md (expected — not in worktree).
- Learning: Aggressive optimization requires broad scope. 5 unchanged high-value files (32% of tokens) limited overall impact.
- Learning: Files already compact (<600 tokens) resist further optimization without sacrificing clarity.
- Recommendation: Phase 2 needed for thor files (3,745 tokens), PLANNER-QUICKREF (1,450), and review of 10 increased files.

## W4b: Quality Gates (MirrorBuddy)

- Decision: Move i18n:check to pre-commit unconditional execution — translation issues caught earlier than pre-push
- Pattern: Pre-commit hooks should run fast checks (<15s); vitest related mode enables per-file test execution
- Insight: smart-test.sh exits 0 if no staged src files — avoids unnecessary test runs on config/doc changes
- Issue: Environment variables scattered across 3 places (.env.example, validate-pre-deploy.ts, GH workflows) — easy to miss one
- Fix: env-var-audit.sh checks all process.env.X references in src/, verifies existence in all 3 locations
- Issue: Sentry config duplicated across client/server/edge with subtle differences — risk of drift
- Pattern: Extract shared logic to lib module, export functions, import in config files
- Result: Sentry env detection now centralized in src/lib/sentry/env.ts — getEnvironment(), isEnabled(), getDsn(), getRelease()
- Verification: 23 unit tests confirm all 3 configs (client/server/edge) agree on environment/enabled/DSN/release logic
- Issue: Duplicate commit messages in last 5 commits can indicate rebasing accidents or copy-paste mistakes
- Fix: pre-push checks for duplicate messages via 'git log --oneline -5 | sort | uniq -d'
- Learning: Git hooks are the last line of defense — unconditional checks (i18n, env vars) prevent silent drift
- Learning: Shared module extraction requires comprehensive tests to prove equivalence across consumers
