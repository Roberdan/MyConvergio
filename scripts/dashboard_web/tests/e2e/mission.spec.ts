import { test, expect } from './fixtures';

test.describe('Active Missions & Task Pipeline', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('#mission-content .mission-plan', { timeout: 5000 });
  });

  test('mission panel shows active plan', async ({ page }) => {
    const missionPlans = page.locator('#mission-content .mission-plan');
    await expect(missionPlans).toHaveCount(1);
    await expect(missionPlans.locator('.mission-id')).toContainText('#300');
    await expect(missionPlans.locator('.mission-name')).toContainText('Auth refactor');
  });

  test('mission plan shows progress ring with correct percentage', async ({ page }) => {
    // 5/8 = 62% (Math.round(100*5/8) = 63%)
    await expect(page.locator('.mission-ring-pct')).toContainText('63%');
  });

  test('mission plan shows project badge', async ({ page }) => {
    await expect(page.locator('.badge-project')).toContainText('VirtualBPM');
  });

  test('mission summary is displayed', async ({ page }) => {
    await expect(page.locator('.mission-summary')).toContainText('JWT token rotation');
  });

  test('wave rows are rendered with progress bars', async ({ page }) => {
    const waves = page.locator('.wave-row');
    await expect(waves).toHaveCount(2);
    await expect(waves.nth(0)).toContainText('W1');
    await expect(waves.nth(1)).toContainText('W2');
  });

  test('live task flow shows in_progress tasks', async ({ page }) => {
    await expect(page.locator('.live-flow-section .task-flow')).toHaveCount(1);
    await expect(page.locator('.task-flow-id')).toContainText('T4');
  });

  test('task pipeline table renders all tasks', async ({ page }) => {
    const rows = page.locator('#task-table tbody tr:not(.task-wave-header)');
    await expect(rows).toHaveCount(8);
  });

  test('task pipeline shows wave headers', async ({ page }) => {
    const waveHeaders = page.locator('.task-wave-header');
    await expect(waveHeaders).toHaveCount(2);
    await expect(waveHeaders.nth(0)).toContainText('W1');
    await expect(waveHeaders.nth(1)).toContainText('W2');
  });

  test('task row shows status dot and thor icon', async ({ page }) => {
    // T1 is done + validated
    const t1Row = page.locator('tr[data-task-id="T1"]');
    await expect(t1Row.locator('.dot-done')).toHaveCount(1);
    await expect(t1Row.locator('svg[fill="#00cc55"]')).toHaveCount(1); // Thor validated

    // T6 is blocked
    const t6Row = page.locator('tr[data-task-id="T6"]');
    await expect(t6Row.locator('.dot-blocked')).toHaveCount(1);
  });

  test('clicking task row expands detail', async ({ page }) => {
    const row = page.locator('tr[data-task-id="T1"]');
    await row.click();
    await expect(page.locator('.task-detail-row')).toBeVisible();
    await expect(page.locator('.task-detail')).toContainText('T1');
    await expect(page.locator('.task-detail')).toContainText('Create auth module');
  });

  test('clicking expanded task collapses it', async ({ page }) => {
    const row = page.locator('tr[data-task-id="T1"]');
    await row.click();
    await expect(page.locator('.task-detail-row')).toBeVisible();
    await row.click();
    await expect(page.locator('.task-detail-row')).toHaveCount(0);
  });

  test('clicking mission plan filters task pipeline', async ({ page }) => {
    const plan = page.locator('#mission-content .mission-plan').first();
    await plan.click();
    const label = page.locator('#task-filter-label');
    await expect(label).toContainText('#300');
    await expect(page.locator('#task-filter-clear')).toBeVisible();
  });

  test('Show All button clears filter', async ({ page }) => {
    // First filter
    await page.locator('#mission-content .mission-plan').first().click();
    await expect(page.locator('#task-filter-clear')).toBeVisible();
    // Clear
    await page.locator('#task-filter-clear').click();
    await expect(page.locator('#task-filter-clear')).not.toBeVisible();
  });

  test('delegate button is visible on mission plan', async ({ page }) => {
    await expect(page.locator('.mission-delegate-btn')).toHaveCount(1);
  });
});

test.describe('Plan Detail Sidebar', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.history-row', { timeout: 5000 });
  });

  test('clicking history row opens plan sidebar', async ({ page }) => {
    await page.locator('.history-row').first().click();
    await expect(page.locator('#sidebar')).toHaveClass(/open/);
    await expect(page.locator('#sidebar-overlay')).toHaveClass(/open/);
    await expect(page.locator('#sb-title')).toContainText('#300');
  });

  test('sidebar shows plan metadata', async ({ page }) => {
    await page.locator('.history-row').first().click();
    const body = page.locator('#sb-body');
    await expect(body).toContainText('DOING');
    await expect(body).toContainText('5/8');
    await expect(body).toContainText('63%');
    await expect(body).toContainText('JWT token rotation');
    await expect(body).toContainText('+340');
    await expect(body).toContainText('-80');
    await expect(body).toContainText('$52.30');
  });

  test('sidebar shows waves with PR link', async ({ page }) => {
    await page.locator('.history-row').first().click();
    await expect(page.locator('.sb-wave')).toHaveCount(2);
    await expect(page.locator('#sb-body')).toContainText('PR #42');
  });

  test('sidebar shows tasks', async ({ page }) => {
    await page.locator('.history-row').first().click();
    await expect(page.locator('.sb-task')).toHaveCount(2);
  });

  test('sidebar close button works', async ({ page }) => {
    await page.locator('.history-row').first().click();
    await expect(page.locator('#sidebar')).toHaveClass(/open/);
    await page.locator('.sb-close').click();
    await expect(page.locator('#sidebar')).not.toHaveClass(/open/);
  });

  test('sidebar overlay click closes sidebar', async ({ page }) => {
    await page.locator('.history-row').first().click();
    await expect(page.locator('#sidebar')).toHaveClass(/open/);
    await page.locator('#sidebar-overlay').click({ force: true });
    await expect(page.locator('#sidebar')).not.toHaveClass(/open/);
  });
});

test.describe('History & Event Feed', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.history-row', { timeout: 5000 });
  });

  test('history renders completed plans', async ({ page }) => {
    const rows = page.locator('.history-row');
    await expect(rows).toHaveCount(2);
    await expect(rows.nth(0)).toContainText('#299');
    await expect(rows.nth(0)).toContainText('DB migration');
    await expect(rows.nth(0)).toContainText('6/6');
    await expect(rows.nth(0)).toContainText('done');
  });

  test('github activity feed renders mixed GitHub events', async ({ page }) => {
    await page.waitForSelector('.event-row', { timeout: 5000 });
    const events = page.locator('.event-row');
    await expect(events).toHaveCount(7);
    await expect(page.locator('#event-feed-content')).toContainText('Release published');
    await expect(page.locator('#event-feed-content')).toContainText('PR #43 opened');
    await expect(page.locator('#event-feed-content')).toContainText('CI status update');
    await expect(page.locator('#event-feed-content')).toContainText('Review approved');
    await expect(page.locator('#event-feed-content')).toContainText('commits pushed');
  });

  test('event with plan_id has clickable link', async ({ page }) => {
    await page.waitForSelector('.event-row', { timeout: 5000 });
    const event = page.locator('.event-row', { has: page.locator('.event-plan') }).first();
    await expect(event.locator('.event-plan')).toContainText('#300');
  });
});
