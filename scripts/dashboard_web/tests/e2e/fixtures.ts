import { test as base, Page, Route } from '@playwright/test';

/** Canonical mock data for all dashboard API endpoints. */
export const MOCK = {
  overview: {
    plans_total: 12, plans_active: 3, plans_done: 9,
    agents_running: 2, blocked: 1,
    total_tokens: 85_000_000, total_cost: 342.50,
    today_tokens: 4_200_000, today_cost: 18.30,
    mesh_online: 2, mesh_total: 3,
  },
  mission: {
    plans: [{
      plan: {
        id: 300, name: 'Auth refactor', status: 'doing',
        tasks_done: 5, tasks_total: 8, human_summary: 'JWT token rotation',
        execution_host: '', execution_peer: 'local',
        parallel_mode: null, project_id: 'proj-1', project_name: 'VirtualBPM',
        project_path: '/tmp',
      },
      waves: [
        { wave_id: 'W1', name: 'Setup', status: 'done', tasks_done: 3, tasks_total: 3, position: 1, validated_at: '2026-03-01' },
        { wave_id: 'W2', name: 'Core', status: 'in_progress', tasks_done: 2, tasks_total: 5, position: 2, validated_at: null },
      ],
      tasks: [
        { task_id: 'T1', title: 'Create auth module', status: 'done', executor_agent: 'claude-sonnet', executor_host: 'local', tokens: 120000, validated_at: '2026-03-01', model: 'claude-sonnet-4.6', wave_id: 'W1' },
        { task_id: 'T2', title: 'Add JWT middleware', status: 'done', executor_agent: 'claude-sonnet', executor_host: 'local', tokens: 95000, validated_at: '2026-03-01', model: 'claude-sonnet-4.6', wave_id: 'W1' },
        { task_id: 'T3', title: 'Write auth tests', status: 'done', executor_agent: 'claude-haiku', executor_host: 'local', tokens: 45000, validated_at: '2026-03-01', model: 'claude-haiku-4.5', wave_id: 'W1' },
        { task_id: 'T4', title: 'Token refresh endpoint', status: 'in_progress', executor_agent: 'gpt-5.3-codex', executor_host: 'local', tokens: 80000, validated_at: null, model: 'gpt-5.3-codex', wave_id: 'W2' },
        { task_id: 'T5', title: 'Rate limiting', status: 'done', executor_agent: 'claude-sonnet', executor_host: 'local', tokens: 60000, validated_at: '2026-03-02', model: 'claude-sonnet-4.6', wave_id: 'W2' },
        { task_id: 'T6', title: 'Session invalidation', status: 'blocked', executor_agent: '', executor_host: '', tokens: null, validated_at: null, model: null, wave_id: 'W2' },
        { task_id: 'T7', title: 'RBAC integration', status: 'pending', executor_agent: '', executor_host: '', tokens: null, validated_at: null, model: null, wave_id: 'W2' },
        { task_id: 'T8', title: 'Audit logging', status: 'pending', executor_agent: '', executor_host: '', tokens: null, validated_at: null, model: null, wave_id: 'W2' },
      ],
    }],
  },
  tokensDaily: [
    { day: '2026-02-26', input: 5_000_000, output: 4_700_000, cost: 38.5 },
    { day: '2026-02-27', input: 11_400_000, output: 16_780_000, cost: 112.3 },
    { day: '2026-02-28', input: 3_200_000, output: 10_100_000, cost: 65.8 },
    { day: '2026-03-01', input: 1_150_000, output: 1_900_000, cost: 14.2 },
    { day: '2026-03-02', input: 8_600_000, output: 4_900_000, cost: 52.1 },
    { day: '2026-03-03', input: 6_300_000, output: 3_100_000, cost: 35.7 },
    { day: '2026-03-04', input: 7_800_000, output: 5_200_000, cost: 48.9 },
    { day: '2026-03-05', input: 4_200_000, output: 2_800_000, cost: 28.4 },
  ],
  tokensModels: [
    { model: 'claude-sonnet-4.6', tokens: 42_000_000, cost: 180.50 },
    { model: 'claude-opus-4.6', tokens: 18_000_000, cost: 95.20 },
    { model: 'claude-haiku-4.5', tokens: 15_000_000, cost: 22.80 },
    { model: 'gpt-5.3-codex', tokens: 10_000_000, cost: 44.00 },
  ],
  mesh: [
    { peer_name: 'm3max', role: 'coordinator', is_online: true, is_local: true, os: 'macos', capabilities: 'claude,copilot,ollama', cpu: 35, active_tasks: 2, dns_name: 'Mac.lan', plans: [{ id: 300, name: 'Auth refactor', status: 'doing', tasks_done: 5, tasks_total: 8, active_tasks: [{ title: 'Token refresh', status: 'in_progress' }] }] },
    { peer_name: 'omarchy', role: 'worker', is_online: true, is_local: false, os: 'linux', capabilities: 'claude,copilot', cpu: 72, mem_used_gb: 12.1, mem_total_gb: 16, active_tasks: 1, dns_name: 'omarchy.lan', plans: [] },
    { peer_name: 'm1mario', role: 'worker', is_online: false, is_local: false, os: 'macos', capabilities: 'claude', cpu: 0, active_tasks: 0, dns_name: '', plans: [] },
  ],
  meshSyncStatus: [
    { peer_name: 'm3max', reachable: true, config_synced: true, last_heartbeat_age_sec: 5 },
    { peer_name: 'omarchy', reachable: true, config_synced: false, last_heartbeat_age_sec: 120 },
    { peer_name: 'm1mario', reachable: false, config_synced: null, last_heartbeat_age_sec: -1 },
  ],
  history: [
    { id: 299, name: 'DB migration', status: 'done', tasks_done: 6, tasks_total: 6, project_id: 'proj-1', started_at: '2026-02-28', completed_at: '2026-03-01', human_summary: 'Migrated to v5 schema', lines_added: 420, lines_removed: 180 },
    { id: 298, name: 'CI pipeline', status: 'done', tasks_done: 4, tasks_total: 4, project_id: 'proj-1', started_at: '2026-02-25', completed_at: '2026-02-27', human_summary: null, lines_added: 200, lines_removed: 50 },
  ],
  taskDist: [
    { status: 'done', count: 5 },
    { status: 'in_progress', count: 1 },
    { status: 'blocked', count: 1 },
    { status: 'pending', count: 2 },
  ],
  events: [
    { id: 1, event_type: 'task_status_changed', plan_id: 300, source_peer: 'm3max', payload: '{}', status: 'delivered', created_at: Math.floor(Date.now() / 1000) - 120 },
    { id: 2, event_type: 'wave_completed', plan_id: 300, source_peer: 'm3max', payload: '{}', status: 'delivered', created_at: Math.floor(Date.now() / 1000) - 3600 },
  ],
  notifications: [],
  planDetail: {
    plan: { id: 300, name: 'Auth refactor', status: 'doing', tasks_done: 5, tasks_total: 8, project_id: 'proj-1', human_summary: 'JWT token rotation', started_at: '2026-03-01', completed_at: null, parallel_mode: null, lines_added: 340, lines_removed: 80, execution_host: '' },
    waves: [
      { wave_id: 'W1', name: 'Setup', status: 'done', tasks_done: 3, tasks_total: 3, branch_name: 'plan/300-auth', pr_number: 42, pr_url: 'https://github.com/test/repo/pull/42', position: 1, validated_at: '2026-03-01' },
      { wave_id: 'W2', name: 'Core', status: 'in_progress', tasks_done: 2, tasks_total: 5, branch_name: 'plan/300-auth-w2', pr_number: null, pr_url: null, position: 2, validated_at: null },
    ],
    tasks: [
      { task_id: 'T1', title: 'Create auth module', status: 'done', executor_agent: 'claude-sonnet', executor_host: 'local', tokens: 120000, started_at: '2026-03-01', completed_at: '2026-03-01', validated_at: '2026-03-01', model: 'claude-sonnet-4.6', wave_id: 'W1' },
      { task_id: 'T4', title: 'Token refresh endpoint', status: 'in_progress', executor_agent: 'gpt-5.3-codex', executor_host: 'local', tokens: 80000, started_at: '2026-03-04', completed_at: null, validated_at: null, model: 'gpt-5.3-codex', wave_id: 'W2' },
    ],
    cost: { cost: 52.30, tokens: 520000 },
  },
  pullDb: { count: 0, synced: [] },
  githubStats: {
    ok: true,
    plan_id: 300,
    lines_changed: 1520,
    commits_today: 4,
    open_prs: 3,
    pr_merge_velocity: 1.5,
    commit_totals: { lines_added: 1100, lines_removed: 420, files_changed: 80, commit_count: 12 },
  },
  githubEvents: {
    ok: true,
    project_id: 'proj-1',
    repo: 'test/repo',
    local_events: [
      {
        id: 11,
        plan_id: 300,
        task_id: 'T4',
        event_type: 'task_status_changed',
        event_action: 'in_progress',
        status: 'processed',
        event_at: '2026-03-06T09:08:00Z',
      },
      {
        id: 10,
        plan_id: 300,
        task_id: 'W2',
        event_type: 'wave_completed',
        event_action: 'done',
        status: 'processed',
        event_at: '2026-03-06T08:30:00Z',
      },
    ],
    remote_events: [
      {
        id: 'evt-1',
        type: 'ReleaseEvent',
        actor: { login: 'Roberdan' },
        created_at: '2026-03-06T10:00:00Z',
        payload: {
          action: 'published',
          release: { tag_name: 'v10.17.1', html_url: 'https://github.com/test/repo/releases/tag/v10.17.1' },
        },
      },
      {
        id: 'evt-2',
        type: 'PullRequestReviewEvent',
        actor: { login: 'review-bot' },
        created_at: '2026-03-06T09:55:00Z',
        payload: {
          review: { state: 'APPROVED' },
          pull_request: { number: 42, html_url: 'https://github.com/test/repo/pull/42' },
        },
      },
      {
        id: 'evt-3',
        type: 'CheckSuiteEvent',
        actor: { login: 'github-actions[bot]' },
        created_at: '2026-03-06T09:50:00Z',
        payload: {
          check_suite: { conclusion: 'success' },
        },
      },
      {
        id: 'evt-4',
        type: 'PullRequestEvent',
        actor: { login: 'Roberdan' },
        created_at: '2026-03-06T09:45:00Z',
        payload: {
          action: 'opened',
          pull_request: { number: 43, title: 'Add GitHub activity widget', html_url: 'https://github.com/test/repo/pull/43' },
        },
      },
      {
        id: 'evt-5',
        type: 'PushEvent',
        actor: { login: 'Roberdan' },
        created_at: '2026-03-06T09:40:00Z',
        payload: {
          size: 3,
          ref: 'refs/heads/plan/100025-convergio-evolution',
          commits: [{ url: 'https://github.com/test/repo/commit/abc123' }],
        },
      },
    ],
  },
  nightlyJobs: {
    ok: true,
    latest: {
      id: 910,
      run_id: 'mirrorbuddy-nightly-20260308-023000',
      job_name: 'guardian',
      started_at: '2026-03-08T02:30:00Z',
      finished_at: '2026-03-08T03:02:00Z',
      host: 'omarchy',
      status: 'action_required',
      sentry_unresolved: 4,
      github_open_issues: 7,
      processed_items: 5,
      fixed_items: 3,
      branch_name: 'nightly/guardian-20260308-0230',
      pr_url: 'https://github.com/test/repo/pull/91',
      summary: 'Fix PR opened for high-impact Sentry/GitHub regressions.',
      report_json: '{"sentry_unresolved":4,"github_open_issues":7,"top_sentry_issues":[{"id":"123","short":"MB-1K","title":"Error: WebRTC failed","level":"error"}],"top_github_issues":[],"deploy":{"status":"ready"}}',
      duration_sec: 1920,
      trigger_source: 'scheduled',
      exit_code: 0,
      error_detail: null,
      log_file_path: '/data/nightly-jobs/logs/mirrorbuddy-nightly-20260308-023000.log',
      parent_run_id: null,
      config_snapshot: '{"MIRRORBUDDY_RUN_FIXES":"true","MIRRORBUDDY_MODEL":"gpt-5.3-codex"}',
    },
    history: [
      { id: 910, run_id: 'mirrorbuddy-nightly-20260308-023000', job_name: 'guardian', status: 'action_required', started_at: '2026-03-08T02:30:00Z', host: 'omarchy', processed_items: 5, fixed_items: 3, pr_url: 'https://github.com/test/repo/pull/91', duration_sec: 1920, trigger_source: 'scheduled', exit_code: 0 },
      { id: 909, run_id: 'mirrorbuddy-nightly-20260307-023000', job_name: 'guardian', status: 'ok', started_at: '2026-03-07T02:30:00Z', host: 'omarchy', processed_items: 0, fixed_items: 0, pr_url: null, duration_sec: 45, trigger_source: 'scheduled', exit_code: 0 },
      { id: 908, run_id: 'mirrorbuddy-nightly-20260306-023000', job_name: 'guardian', status: 'failed', started_at: '2026-03-06T02:30:00Z', host: 'omarchy', processed_items: 3, fixed_items: 0, pr_url: null, duration_sec: 3600, trigger_source: 'scheduled', exit_code: 1, error_detail: 'npm run ci:summary:full failed with exit code 1' },
    ],
    definitions: [
      { id: 1, name: 'guardian', description: 'Nightly triage + auto-fix', schedule: '0 2 * * *', script_path: 'scripts/mirrorbuddy-nightly-guardian.sh', target_host: 'omarchy', enabled: 1, run_fixes: 1, timeout_sec: 5400 },
    ],
    page: 1,
    per_page: 50,
    total: 3,
  },
  sessions: [
    { session_id: 'sess-001', plan_id: 300, agent_id: 'agent-001', model: 'gpt-5.3-codex', host: 'm3max', status: 'running', started_at: Date.now() / 1000 - 142 },
    { session_id: 'sess-002', plan_id: 300, agent_id: 'agent-002', model: 'claude-opus-4.6', host: 'omarchy', status: 'running', started_at: Date.now() / 1000 - 38 },
  ],
  /* --- Kanban: plans with varied statuses --- */
  kanbanPlans: [
    { id: 300, name: 'Auth refactor', status: 'doing', tasks_done: 5, tasks_total: 8, project_id: 'proj-1', human_summary: 'JWT token rotation' },
    { id: 301, name: 'DB migration v5', status: 'todo', tasks_done: 0, tasks_total: 4, project_id: 'proj-1', human_summary: 'Schema upgrade' },
    { id: 302, name: 'CI pipeline', status: 'done', tasks_done: 6, tasks_total: 6, project_id: 'proj-2', human_summary: 'GitHub Actions' },
    { id: 303, name: 'Hotfix auth', status: 'doing', tasks_done: 2, tasks_total: 3, project_id: 'proj-1', human_summary: null },
  ],
  /* --- Tasks with substatus values --- */
  substatusTasks: [
    { task_id: 'T10', title: 'Run CI checks', status: 'in_progress', substatus: 'waiting_ci', wave_id: 'W2', executor_agent: 'claude-sonnet', tokens: 50000, model: 'claude-sonnet-4.6', validated_at: null },
    { task_id: 'T11', title: 'PR review', status: 'in_progress', substatus: 'waiting_review', wave_id: 'W2', executor_agent: 'claude-opus', tokens: 30000, model: 'claude-opus-4.6', validated_at: null },
    { task_id: 'T12', title: 'Thor validation', status: 'in_progress', substatus: 'waiting_thor', wave_id: 'W2', executor_agent: 'claude-sonnet', tokens: 20000, model: 'claude-sonnet-4.6', validated_at: null },
    { task_id: 'T13', title: 'Code generation', status: 'in_progress', substatus: 'agent_running', wave_id: 'W2', executor_agent: 'gpt-5.3-codex', tokens: 80000, model: 'gpt-5.3-codex', validated_at: null },
  ],
  /* --- Agent activity for brain visualization --- */
  agents: {
    running: [
      { agent_id: 'agent-001', type: 'task-executor', model: 'gpt-5.3-codex', description: 'Implementing auth module', task_db_id: 4, plan_id: 300, host: 'm3max', region: 'local', duration_s: 142.5 },
      { agent_id: 'agent-002', type: 'code-review', model: 'claude-opus-4.6', description: 'Reviewing PR #42', task_db_id: 5, plan_id: 300, host: 'omarchy', region: 'remote', duration_s: 38.2 },
    ],
    recent: [
      { agent_id: 'agent-000', status: 'completed', duration_s: 210.3, tokens_total: 145000, cost_usd: 0.62, type: 'task-executor', model: 'claude-sonnet-4.6', completed_at: '2026-03-05T14:30:00' },
      { agent_id: 'agent-099', status: 'failed', duration_s: 15.1, tokens_total: 8000, cost_usd: 0.03, type: 'explore', model: 'claude-haiku-4.5', completed_at: '2026-03-05T14:25:00' },
    ],
    stats: { total_tokens: 2_500_000, total_cost: 12.80, active_count: 2, completed_today: 14, by_model: { 'gpt-5.3-codex': 1_200_000, 'claude-opus-4.6': 800_000, 'claude-sonnet-4.6': 500_000 } },
  },
  /* --- Peer heartbeats with CPU/RAM for sparklines --- */
  peerHeartbeats: [
    { peer_name: 'm3max', cpu_pct: 35, mem_used_gb: 18.2, mem_total_gb: 36, load_avg: 2.4, last_seen: Date.now() / 1000 },
    { peer_name: 'omarchy', cpu_pct: 72, mem_used_gb: 12.1, mem_total_gb: 16, load_avg: 5.8, last_seen: Date.now() / 1000 - 120 },
    { peer_name: 'm1mario', cpu_pct: 0, mem_used_gb: 0, mem_total_gb: 16, load_avg: 0, last_seen: Date.now() / 1000 - 86400 },
  ],
};

type MockOverrides = Partial<typeof MOCK>;

/** Install API route mocks on a Playwright page. */
export async function mockAllApis(page: Page, overrides: MockOverrides = {}) {
  const data = { ...MOCK, ...overrides };
  const routes: Record<string, unknown> = {
    '/api/overview': data.overview,
    '/api/mission': data.mission,
    '/api/tokens/daily': data.tokensDaily,
    '/api/tokens/models': data.tokensModels,
    '/api/mesh': data.mesh,
    '/api/mesh/sync-status': data.meshSyncStatus,
    '/api/history': data.history,
    '/api/tasks/distribution': data.taskDist,
    '/api/events': data.events,
    '/api/notifications': data.notifications,
    '/api/mesh/pull-db': data.pullDb,
    '/api/sessions': data.sessions,
    '/api/plan/300': data.planDetail,
    '/api/github/stats/300': data.githubStats,
    '/api/github/events/proj-1': data.githubEvents,
    '/api/nightly/jobs': data.nightlyJobs,
    '/api/agents': data.agents,
    '/api/peers/heartbeats': data.peerHeartbeats,
  };
  for (const [path, body] of Object.entries(routes)) {
    await page.route(`**${path}`, (route: Route) =>
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) }),
    );
  }
  // Catch any /api/plan/<id> request and return planDetail mock
  await page.route('**/api/plan/*', (route: Route) =>
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(data.planDetail) }),
  );
  // Block WS dashboard connection to avoid noise
  await page.route('**/ws/dashboard', (route: Route) => route.abort());
}

/** Extended test fixture with mockApis helper. */
export const test = base.extend<{ mockApis: (overrides?: MockOverrides) => Promise<void> }>({
  mockApis: async ({ page }, use) => {
    await use(async (overrides?: MockOverrides) => {
      await mockAllApis(page, overrides);
    });
  },
});

export { expect } from '@playwright/test';
