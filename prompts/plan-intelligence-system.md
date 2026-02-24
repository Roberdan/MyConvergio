# Plan Intelligence System

## Context

The plan workflow currently lacks pre-execution review and post-execution learning. Thor validates code quality after execution, but no agent validates the plan itself before execution. No business value assessment exists. No structured learnings are captured. Token estimates are not compared with actuals.

## Requirements

### F-01: Plan Reviewer Agent (Technical)

Create an agent (`plan-reviewer`) that reviews plan specs with fresh context (context_isolation: true). The agent receives ONLY the spec JSON and codebase access (no planner context).

**Must validate:**
- Every F-xx in the prompt has at least one task that fully implements it (not partially)
- No task produces a stub, placeholder, or partial implementation
- Wave dependencies are correct (no circular, no missing)
- File references exist in the codebase
- Verify criteria are machine-checkable (not vague)
- Task granularity is appropriate (no mega-tasks >3 files, no trivial single-line tasks)

**Must suggest (value-add):**
- Edge cases the requester may not have considered
- Missing error handling, validation, or security tasks
- Performance implications of the proposed changes
- UX/DX improvements if applicable
- Test coverage gaps

**Output format:** Structured verdict (APPROVED / NEEDS_REVISION) with:
- fxx_coverage_score (0-100%)
- completeness_score (0-100%)
- gaps[] (issues found)
- suggestions[] (value-add proposals)
- risk_assessment (low/medium/high)

### F-02: Business Advisor Integration

Create an agent (`plan-business-advisor`) that assesses business value with fresh context. Receives spec JSON + project context.

**Must produce:**
- traditional_effort_days: estimated person-days if done without AI (by a senior dev)
- complexity_rating: 1-5 scale with justification
- business_value_score: 1-10 based on impact, reach, risk reduction
- risk_assessment: technical risks, dependency risks, scope risks
- roi_projection: traditional_effort / estimated_ai_effort

### F-03: Learnings Archive

Create a structured learnings system populated at plan completion.

**Automatic capture (from existing data):**
- Thor rejection count per task (from validation_report)
- Token variance >100% (from token_usage vs estimates)
- Tasks that went done->in_progress (rework)
- PR retry count (from CI data if available)
- Wave merge conflicts

**Agent post-mortem (new agent or planner extension):**
- Analyze all Thor rejects for patterns
- Identify tasks with effort >> estimated
- Capture what_worked and what_failed
- Produce actionable learnings with categories

**Categories:** pr_friction, thor_rejection, estimation_miss, token_blowup, what_worked, user_time, process, architecture, testing

### F-04: Token Estimation and Tracking

**Pre-execution:** Planner generates token estimates per task based on:
- effort level (1/2/3) mapped to historical token ranges
- model assignment
- Historical data from similar tasks (query plan_learnings + plan_token_estimates)

**Post-execution:** task-executor already reports tokens. Add:
- variance_pct calculation (automatic)
- Flagging when variance >100% (creates automatic learning)
- Calibration: update estimation model from actuals

### F-05: DB Schema Extensions

New tables in dashboard.db (via init-db.sql migration):

```sql
CREATE TABLE IF NOT EXISTS plan_reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL,
    reviewer_agent TEXT NOT NULL,
    verdict TEXT NOT NULL CHECK(verdict IN ('APPROVED', 'NEEDS_REVISION')),
    fxx_coverage_score INTEGER,
    completeness_score INTEGER,
    suggestions TEXT,
    gaps TEXT,
    risk_assessment TEXT,
    raw_report TEXT,
    reviewed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS plan_business_assessments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL,
    traditional_effort_days REAL,
    complexity_rating INTEGER CHECK(complexity_rating BETWEEN 1 AND 5),
    business_value_score INTEGER CHECK(business_value_score BETWEEN 1 AND 10),
    risk_assessment TEXT,
    roi_projection REAL,
    assessed_by TEXT,
    assessed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS plan_learnings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL,
    category TEXT NOT NULL,
    severity TEXT NOT NULL CHECK(severity IN ('insight', 'warning', 'critical')),
    title TEXT NOT NULL,
    detail TEXT,
    task_id TEXT,
    wave_id TEXT,
    tags TEXT,
    actionable INTEGER DEFAULT 0,
    action_taken TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS plan_token_estimates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL,
    scope TEXT NOT NULL CHECK(scope IN ('task', 'wave', 'plan')),
    scope_id TEXT NOT NULL,
    estimated_tokens INTEGER,
    estimated_cost_usd REAL,
    actual_tokens INTEGER,
    actual_cost_usd REAL,
    variance_pct REAL,
    model TEXT,
    executor_agent TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME,
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS plan_actuals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL UNIQUE,
    total_tokens INTEGER,
    total_cost_usd REAL,
    ai_duration_minutes REAL,
    user_spec_minutes REAL,
    total_tasks INTEGER,
    tasks_revised_by_thor INTEGER,
    thor_rejection_rate REAL,
    actual_roi REAL,
    completed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);
```

### F-06: Dashboard API and Views

**New API endpoints:**
- GET /api/plan/:id/review - plan review data
- GET /api/plan/:id/business-assessment - business assessment
- GET /api/plan/:id/learnings - learnings for a plan
- GET /api/plan/:id/token-estimates - estimates vs actuals
- GET /api/plan/:id/actuals - plan actuals summary
- GET /api/learnings/search?category=X&severity=Y - cross-plan search
- GET /api/analytics/roi-trend - ROI trend across plans
- GET /api/analytics/token-accuracy - estimation accuracy trend

**New views:**
- v_plan_roi: joins plans + business_assessments + actuals for ROI analysis
- v_learning_patterns: aggregated learnings across plans by category
- v_token_accuracy: estimation vs actual trends

### F-07: Planner Workflow Integration

Modify planner.md to add steps:

- **Step 3.1** (after import, before user approval): Launch plan-reviewer + plan-business-advisor in PARALLEL
- **Step 3.2**: Present both assessments to user alongside the plan
- **Step 4** (existing): User approves with full visibility (plan + technical review + business assessment)
- **Step 1.5 enhancement**: Query plan_learnings for relevant past insights before generating spec
- **Step 10 enhancement**: Trigger post-mortem agent after plan completion, populate plan_learnings + plan_actuals

### F-08: Knowledge Feedback Loop

- Planner queries `plan_learnings WHERE actionable = 1 AND action_taken IS NULL` at step 1.5
- Token estimates use `AVG(actual_tokens) FROM plan_token_estimates WHERE model = X AND effort = Y` for calibration
- Dashboard shows "unresolved actionable learnings" as notification via existing notifications table
- Post-mortem agent flags recurring patterns (same category + title appearing in 3+ plans)

### F-09: Cross-Platform Compatibility (Claude Code + Copilot CLI)

All agents, scripts, and workflow integrations must work on both Claude Code and Copilot CLI.

- **Agent .md files**: Add a "Cross-Platform Invocation" section documenting how to invoke from both platforms
- **Planner step 3.1**: Document both `Task(subagent_type='plan-reviewer')` for Claude Code and the Copilot CLI equivalent invocation
- **Bash scripts**: Already platform-agnostic (no changes needed)
- **Dashboard API**: Already platform-agnostic (HTTP endpoints)
- **Post-mortem trigger**: Document invocation from both platforms in planner step 10

### F-10: Dashboard Readability + Type Alignment

The dashboard currently shows the full `do` field (technical instructions) as task titles. This is unreadable for humans.

**Fix 1: Summary field support**
- Add optional `summary` field to `plan-spec-schema.json` task properties
- Modify `plan-db-import.sh`: if `summary` exists, use it as `title`; `do` always goes to `description`
- If no `summary`: current behavior (backward compatible)
- Planner must generate short human-readable `summary` for each task (5-10 words)

**Fix 2: Type enum alignment**
- Spec schema type enum: `feature, fix, refactor, test, config, documentation, chore`
- DB tasks type CHECK: `bug, feature, chore, doc, test`
- These don't match. Align by: updating the DB CHECK to include all spec types, OR mapping in the import script
- Recommended: update DB CHECK to match spec schema (superset)
