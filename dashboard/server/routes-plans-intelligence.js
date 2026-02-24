// Plan Intelligence Routes (F-06, F-08)
// Reviews, assessments, learnings, token estimates, actuals, analytics

const { query, escapeSQL } = require('./db');

function validatePlanId(params) {
  const id = parseInt(params.id, 10);
  if (isNaN(id)) return { error: 'Invalid plan ID', id: null };
  return { error: null, id };
}

const routes = {
  // Plan review results from reviewer agents
  'GET /api/plan/:id/review': (params) => {
    const { error, id } = validatePlanId(params);
    if (error) return { error };
    try {
      return query(`
        SELECT id, plan_id, reviewer_agent, verdict,
               fxx_coverage_score, completeness_score,
               suggestions, gaps, risk_assessment, raw_report,
               reviewed_at
        FROM plan_reviews
        WHERE plan_id = ${id}
        ORDER BY reviewed_at DESC
      `);
    } catch (e) {
      return { error: 'Failed to fetch reviews: ' + e.message };
    }
  },

  // Business value assessment for a plan
  'GET /api/plan/:id/business-assessment': (params) => {
    const { error, id } = validatePlanId(params);
    if (error) return { error };
    try {
      return query(`
        SELECT id, plan_id, traditional_effort_days,
               complexity_rating, business_value_score,
               risk_assessment, roi_projection,
               assessed_by, assessed_at
        FROM plan_business_assessments
        WHERE plan_id = ${id}
        ORDER BY assessed_at DESC
      `);
    } catch (e) {
      return { error: 'Failed to fetch assessments: ' + e.message };
    }
  },

  // Learnings captured during plan execution
  'GET /api/plan/:id/learnings': (params) => {
    const { error, id } = validatePlanId(params);
    if (error) return { error };
    try {
      return query(`
        SELECT id, plan_id, category, severity, title, detail,
               task_id, wave_id, tags, actionable,
               action_taken, created_at
        FROM plan_learnings
        WHERE plan_id = ${id}
        ORDER BY created_at DESC
      `);
    } catch (e) {
      return { error: 'Failed to fetch learnings: ' + e.message };
    }
  },

  // Token estimates vs actuals per scope
  'GET /api/plan/:id/token-estimates': (params) => {
    const { error, id } = validatePlanId(params);
    if (error) return { error };
    try {
      return query(`
        SELECT id, plan_id, scope, scope_id,
               estimated_tokens, estimated_cost_usd,
               actual_tokens, actual_cost_usd,
               variance_pct, model, executor_agent, notes,
               created_at, completed_at
        FROM plan_token_estimates
        WHERE plan_id = ${id}
        ORDER BY scope, scope_id
      `);
    } catch (e) {
      return { error: 'Failed to fetch token estimates: ' + e.message };
    }
  },

  // Aggregated actuals for a plan
  'GET /api/plan/:id/actuals': (params) => {
    const { error, id } = validatePlanId(params);
    if (error) return { error };
    try {
      const row = query(`
        SELECT id, plan_id, total_tokens, total_cost_usd,
               ai_duration_minutes, user_spec_minutes,
               total_tasks, tasks_revised_by_thor,
               thor_rejection_rate, actual_roi, completed_at
        FROM plan_actuals
        WHERE plan_id = ${id}
      `);
      return row[0] || { plan_id: id, message: 'No actuals recorded yet' };
    } catch (e) {
      return { error: 'Failed to fetch actuals: ' + e.message };
    }
  },

  // Cross-plan learnings search with filtering
  'GET /api/learnings/search': (params, req, res, body, url) => {
    try {
      const searchParams = url?.searchParams || new URLSearchParams();
      const category = searchParams.get('category');
      const severity = searchParams.get('severity');
      const limit = Math.min(parseInt(searchParams.get('limit') || '100', 10), 500);
      const offset = parseInt(searchParams.get('offset') || '0', 10);

      const conditions = [];
      if (category) conditions.push(`pl.category = '${escapeSQL(category)}'`);
      if (severity) conditions.push(`pl.severity = '${escapeSQL(severity)}'`);

      const where = conditions.length > 0 ? 'WHERE ' + conditions.join(' AND ') : '';

      return query(`
        SELECT pl.id, pl.plan_id, pl.category, pl.severity,
               pl.title, pl.detail, pl.task_id, pl.wave_id,
               pl.tags, pl.actionable, pl.action_taken, pl.created_at,
               p.name AS plan_name
        FROM plan_learnings pl
        LEFT JOIN plans p ON p.id = pl.plan_id
        ${where}
        ORDER BY pl.created_at DESC
        LIMIT ${limit} OFFSET ${offset}
      `);
    } catch (e) {
      return { error: 'Failed to search learnings: ' + e.message };
    }
  },

  // ROI trend across plans (from v_plan_roi view)
  'GET /api/analytics/roi-trend': () => {
    try {
      return query(`SELECT * FROM v_plan_roi ORDER BY plan_id DESC`);
    } catch (e) {
      return { error: 'Failed to fetch ROI trend: ' + e.message };
    }
  },

  // Token estimation accuracy (from v_token_accuracy view)
  'GET /api/analytics/token-accuracy': () => {
    try {
      return query(`SELECT * FROM v_token_accuracy ORDER BY sample_count DESC`);
    } catch (e) {
      return { error: 'Failed to fetch token accuracy: ' + e.message };
    }
  },

  // Notify about actionable learnings (inserts into notifications)
  'POST /api/plan/:id/learnings/notify-actionable': (params, req, res, body) => {
    const { error, id } = validatePlanId(params);
    if (error) return { error };
    try {
      const data = JSON.parse(body || '{}');
      const learningIds = data.learningIds || [];

      if (!Array.isArray(learningIds) || learningIds.length === 0) {
        // Auto-detect: find all actionable learnings without action_taken
        const actionable = query(`
          SELECT id, title, category, severity
          FROM plan_learnings
          WHERE plan_id = ${id} AND actionable = 1
            AND action_taken IS NULL
        `);

        if (actionable.length === 0) {
          return { notified: 0, message: 'No actionable learnings pending' };
        }

        const plan = query(`
          SELECT p.name, p.project_id FROM plans p WHERE p.id = ${id}
        `)[0];

        let notified = 0;
        for (const l of actionable) {
          query(`
            INSERT INTO notifications (project_id, type, title, message, source)
            VALUES (
              '${escapeSQL(plan?.project_id || '')}',
              'warning',
              '${escapeSQL('Actionable: ' + l.title)}',
              '${escapeSQL('[' + l.severity + '] ' + l.category + ' — Plan ' + (plan?.name || id))}',
              'plan-intelligence'
            )
          `);
          notified++;
        }
        return { notified, plan_id: id };
      }

      // Specific learning IDs provided
      const plan = query(`
        SELECT p.name, p.project_id FROM plans p WHERE p.id = ${id}
      `)[0];

      let notified = 0;
      for (const lid of learningIds) {
        const numId = parseInt(lid, 10);
        if (isNaN(numId)) continue;
        const l = query(`
          SELECT id, title, category, severity
          FROM plan_learnings
          WHERE id = ${numId} AND plan_id = ${id}
        `)[0];
        if (!l) continue;

        query(`
          INSERT INTO notifications (project_id, type, title, message, source)
          VALUES (
            '${escapeSQL(plan?.project_id || '')}',
            'warning',
            '${escapeSQL('Actionable: ' + l.title)}',
            '${escapeSQL('[' + l.severity + '] ' + l.category + ' — Plan ' + (plan?.name || id))}',
            'plan-intelligence'
          )
        `);
        notified++;
      }
      return { notified, plan_id: id };
    } catch (e) {
      return { error: 'Failed to create notifications: ' + e.message };
    }
  }
};

module.exports = routes;
