import { test, expect, MOCK } from './fixtures';

/** Multi-plan mission data for Kanban board testing. */
const KANBAN_MISSION = {
  plans: [
    {
      plan: { id: 301, name: 'DB migration v5', status: 'todo', tasks_done: 0, tasks_total: 4, human_summary: 'Schema upgrade', execution_host: '', execution_peer: '', parallel_mode: null, project_id: 'proj-1', project_name: 'VirtualBPM', project_path: '/tmp' },
      waves: [], tasks: [],
    },
    {
      plan: { id: 300, name: 'Auth refactor', status: 'doing', tasks_done: 5, tasks_total: 8, human_summary: 'JWT token rotation', execution_host: '', execution_peer: 'local', parallel_mode: null, project_id: 'proj-1', project_name: 'VirtualBPM', project_path: '/tmp' },
      waves: MOCK.mission.plans[0].waves,
      tasks: MOCK.mission.plans[0].tasks,
    },
    {
      plan: { id: 303, name: 'Hotfix auth', status: 'doing', tasks_done: 2, tasks_total: 3, human_summary: null, execution_host: '', execution_peer: 'm3max', parallel_mode: null, project_id: 'proj-1', project_name: 'VirtualBPM', project_path: '/tmp' },
      waves: [], tasks: [{ task_id: 'TH1', title: 'Fix token expiry', status: 'in_progress', executor_agent: 'claude-sonnet', executor_host: 'local', tokens: 40000, validated_at: null, model: 'claude-sonnet-4.6', wave_id: 'W1' }],
    },
    {
      plan: { id: 302, name: 'CI pipeline', status: 'done', tasks_done: 6, tasks_total: 6, human_summary: 'GitHub Actions', execution_host: '', execution_peer: '', parallel_mode: null, project_id: 'proj-2', project_name: 'Infra', project_path: '/tmp' },
      waves: [], tasks: [],
    },
  ],
};

test.describe('Plan Kanban Board', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis({ mission: KANBAN_MISSION });
    await page.route('**/api/plan-status', (route) =>
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ ok: true }) }),
    );
    await page.goto('/');
    await page.waitForSelector('#plan-kanban-widget', { timeout: 5000 });
    await page.waitForTimeout(300);
  });

  // --- Widget & Structure ---

  test('kanban widget exists on page', async ({ page }) => {
    await expect(page.locator('#plan-kanban-widget')).toBeVisible();
  });

  test('3 columns present with correct data-status', async ({ page }) => {
    const cols = page.locator('.kanban-col');
    await expect(cols).toHaveCount(3, { timeout: 10000 });
    await expect(cols.nth(0)).toHaveAttribute('data-status', 'todo');
    await expect(cols.nth(1)).toHaveAttribute('data-status', 'doing');
    await expect(cols.nth(2)).toHaveAttribute('data-status', 'done');
  });

  test('column headers show correct text', async ({ page }) => {
    const headers = page.locator('.kanban-col-header');
    await expect(headers).toHaveCount(3, { timeout: 10000 });
    await expect(headers.nth(0)).toContainText('Pipeline');
    await expect(headers.nth(1)).toContainText('Executing');
    await expect(headers.nth(2)).toContainText('Done');
  });

  test('column headers have status dot indicators', async ({ page }) => {
    await expect(page.locator('.kanban-dot.todo')).toHaveCount(1);
    await expect(page.locator('.kanban-dot.doing')).toHaveCount(1);
    await expect(page.locator('.kanban-dot.done')).toHaveCount(1);
  });

  // --- Card Placement ---

  test('todo plan appears in Pipeline column', async ({ page }) => {
    const todoCards = page.locator('#kanban-todo .kanban-card');
    await expect(todoCards).toHaveCount(1);
    await expect(todoCards.first()).toContainText('#301');
    await expect(todoCards.first()).toContainText('DB migration v5');
  });

  test('doing plans appear in Executing column', async ({ page }) => {
    const doingCards = page.locator('#kanban-doing .kanban-card');
    await expect(doingCards).toHaveCount(2);
    await expect(page.locator('#kanban-doing')).toContainText('#300');
    await expect(page.locator('#kanban-doing')).toContainText('#303');
  });

  test('done plan appears in Done column', async ({ page }) => {
    const doneCards = page.locator('#kanban-done .kanban-card');
    await expect(doneCards).toHaveCount(1);
    await expect(doneCards.first()).toContainText('#302');
    await expect(doneCards.first()).toContainText('CI pipeline');
  });

  // --- Card Content ---

  test('cards show plan name and ID', async ({ page }) => {
    const card = page.locator('.kanban-card[data-plan-id="300"]');
    await expect(card.locator('.kanban-plan-id')).toHaveText('#300');
    await expect(card.locator('.kanban-plan-name')).toContainText('Auth refactor');
  });

  test('cards show task count', async ({ page }) => {
    const card = page.locator('.kanban-card[data-plan-id="300"]');
    await expect(card.locator('.kanban-card-meta')).toContainText('5/8 tasks');
  });

  test('doing cards have progress bar', async ({ page }) => {
    const card = page.locator('.kanban-card[data-plan-id="300"]');
    await expect(card.locator('.kanban-progress')).toBeVisible();
    await expect(card.locator('.kanban-progress-fill')).toBeVisible();
  });

  test('progress bar has gradient background', async ({ page }) => {
    const fill = page.locator('.kanban-card[data-plan-id="300"] .kanban-progress-fill');
    const bg = await fill.evaluate((el) => el.style.background);
    expect(bg).toContain('linear-gradient');
  });

  test('cards have draggable attribute', async ({ page }) => {
    const cards = page.locator('.kanban-card');
    const count = await cards.count();
    for (let i = 0; i < count; i++) {
      await expect(cards.nth(i)).toHaveAttribute('draggable', 'true');
    }
  });

  test('card uses SVG icon for running indicator (not emoji)', async ({ page }) => {
    const card = page.locator('.kanban-card[data-plan-id="300"]');
    const running = card.locator('.kanban-running');
    if (await running.count() > 0) {
      await expect(running.locator('svg')).toHaveCount(1);
    }
  });

  // --- Drag & Drop ---

  test('drag card from Pipeline to Executing shows start dialog (not direct API)', async ({ page }) => {
    const todoCard = page.locator('#kanban-todo .kanban-card').first();
    const doingCol = page.locator('.kanban-col[data-status="doing"]');

    // No API should fire — drag to doing opens start dialog
    let apiCalled = false;
    page.on('request', (req) => {
      if (req.url().includes('/api/plan-status') && req.method() === 'POST') apiCalled = true;
    });

    await todoCard.dragTo(doingCol);
    await page.waitForTimeout(400);

    // Start dialog modal should appear
    await expect(page.locator('.modal-overlay')).toBeVisible();
    await expect(page.locator('.modal-title')).toContainText('Start #301');
    expect(apiCalled).toBe(false);

    // Dismiss dialog
    await page.locator('.modal-close').click();
  });

  test('drag card from Executing to Pipeline triggers confirm and API', async ({ page }) => {
    page.on('dialog', (d) => d.accept());
    const doingCard = page.locator('#kanban-doing .kanban-card').first();
    const todoCol = page.locator('.kanban-col[data-status="todo"]');

    const [request] = await Promise.all([
      page.waitForRequest((req) => req.url().includes('/api/plan-status') && req.method() === 'POST'),
      doingCard.dragTo(todoCol),
    ]);
    const body = JSON.parse(request.postData()!);
    expect(body.status).toBe('todo');
  });

  test('API POST body has correct shape (doing→todo drag)', async ({ page }) => {
    page.on('dialog', (d) => d.accept());
    const doingCard = page.locator('#kanban-doing .kanban-card').first();
    const todoCol = page.locator('.kanban-col[data-status="todo"]');

    const [request] = await Promise.all([
      page.waitForRequest((req) => req.url().includes('/api/plan-status')),
      doingCard.dragTo(todoCol),
    ]);
    const body = JSON.parse(request.postData()!);
    expect(body).toHaveProperty('plan_id');
    expect(body).toHaveProperty('status');
    expect(typeof body.plan_id).toBe('number');
  });

  // --- Empty State ---

  test('empty columns show "No plans" message', async ({ page, mockApis }) => {
    await mockApis({ mission: { plans: [] } });
    await page.goto('/');
    await page.waitForSelector('#plan-kanban-widget', { timeout: 5000 });
    await page.waitForTimeout(500);

    const empties = page.locator('.kanban-empty');
    await expect(empties).toHaveCount(3);
    for (let i = 0; i < 3; i++) {
      await expect(empties.nth(i)).toContainText('No plans');
    }
  });

  // --- Sorting ---

  test('multiple doing plans render in order', async ({ page }) => {
    const doingCards = page.locator('#kanban-doing .kanban-card');
    await expect(doingCards).toHaveCount(2);
    const firstId = await doingCards.nth(0).getAttribute('data-plan-id');
    const secondId = await doingCards.nth(1).getAttribute('data-plan-id');
    // Both cards should be doing plans (300, 303)
    expect(['300', '303']).toContain(firstId);
    expect(['300', '303']).toContain(secondId);
    expect(firstId).not.toBe(secondId);
  });

  test('data-status attribute set on cards', async ({ page }) => {
    const todoCard = page.locator('#kanban-todo .kanban-card').first();
    await expect(todoCard).toHaveAttribute('data-status', 'todo');
    const doingCard = page.locator('#kanban-doing .kanban-card').first();
    await expect(doingCard).toHaveAttribute('data-status', 'doing');
  });

  test('drag-over class applied on dragover', async ({ page }) => {
    const col = page.locator('.kanban-col[data-status="doing"]');
    await col.evaluate((el) => {
      el.dispatchEvent(new DragEvent('dragover', { bubbles: true }));
    });
    await expect(col).toHaveClass(/drag-over/);
  });

  // --- Cancel / Trash Buttons ---

  test('cancel/trash button exists on todo card', async ({ page }) => {
    const todoCard = page.locator('#kanban-todo .kanban-card').first();
    await expect(todoCard.locator('.kanban-trash-btn')).toHaveCount(1);
    await expect(todoCard.locator('.kanban-trash-btn svg')).toBeAttached();
  });

  test('cancel/trash button exists on doing card', async ({ page }) => {
    const doingCard = page.locator('#kanban-doing .kanban-card').first();
    await expect(doingCard.locator('.kanban-trash-btn')).toHaveCount(1);
  });

  test('cancel/trash button does NOT exist on done card', async ({ page }) => {
    const doneCard = page.locator('#kanban-done .kanban-card').first();
    await expect(doneCard.locator('.kanban-trash-btn')).toHaveCount(0);
  });

  test('clicking cancel button opens confirmation modal (not native dialog)', async ({ page }) => {
    const trashBtn = page.locator('#kanban-todo .kanban-trash-btn').first();
    await trashBtn.click();
    await expect(page.locator('.modal-overlay')).toBeVisible({ timeout: 2000 });
    await expect(page.locator('.modal-title')).toContainText('Cancel Plan');
    // Dismiss
    await page.locator('.modal-close').click();
  });
});
