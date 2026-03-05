import { test as base, Page, Route } from '@playwright/test';

/** Canonical mock data for all dashboard API endpoints. */
export const MOCK = {
  overview: {
    plans_total: 12, plans_active: 3, plans_done: 9,
    agents_running: 2, blocked: 1,
    total_tokens: 85_000_000, total_cost: 342.50,
    today_tokens: 4_200_000, today_cost: 18.30,
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
    { peer_name: 'omarchy', role: 'worker', is_online: true, is_local: false, os: 'linux', capabilities: 'claude,copilot', cpu: 72, active_tasks: 1, dns_name: 'omarchy.lan', plans: [] },
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
    '/api/plan/300': data.planDetail,
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
