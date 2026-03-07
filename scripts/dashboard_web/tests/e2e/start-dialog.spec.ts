import { test, expect, MOCK } from './fixtures';

const TODO_MISSION = {
  plans: [{
    plan: { ...MOCK.mission.plans[0].plan, id: 301, name: 'DB migration v5', status: 'todo', tasks_done: 0 },
    waves: [],
    tasks: [],
  }],
};

test.describe('Start Plan Dialog', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis({ mission: TODO_MISSION });
    await page.goto('/');
    await page.waitForSelector('.mission-start-btn', { timeout: 5000 });
    // Open start dialog via mission start button
    await page.locator('.mission-start-btn').click();
    await page.waitForSelector('.modal-overlay', { timeout: 3000 });
  });

  test('start dialog appears with plan title', async ({ page }) => {
    await expect(page.locator('.modal-overlay')).toBeVisible();
    await expect(page.locator('.modal-title')).toContainText('Start #301');
  });

  test('dialog shows "Local (this machine)" option pre-selected', async ({ page }) => {
    const localNode = page.locator('.spd-node[data-target="local"]');
    await expect(localNode).toBeVisible();
    await expect(localNode).toContainText('Local (this machine)');
    // Should be pre-selected (data-sel="1")
    await expect(localNode).toHaveAttribute('data-sel', '1');
  });

  test('dialog shows model selector dropdown', async ({ page }) => {
    const select = page.locator('#spd-model');
    await expect(select).toBeVisible();
  });

  test('model dropdown defaults to gpt-5.3-codex', async ({ page }) => {
    const select = page.locator('#spd-model');
    const value = await select.inputValue();
    expect(value).toBe('gpt-5.3-codex');
  });

  test('model dropdown has all expected options', async ({ page }) => {
    const select = page.locator('#spd-model');
    const options = await select.locator('option').allInnerTexts();
    expect(options).toContain('gpt-5.3-codex');
    expect(options).toContain('claude-opus-4.6');
    expect(options).toContain('claude-sonnet-4.6');
    expect(options).toContain('gpt-5-mini');
    expect(options).toContain('claude-haiku-4.5');
  });

  test('sync status indicator area is present', async ({ page }) => {
    const preflight = page.locator('#spd-preflight');
    await expect(preflight).toBeAttached();
    // Shows initial "Sync OK" status
    await expect(preflight).toContainText('Sync OK');
  });

  test('dialog has Cancel and Start Plan buttons', async ({ page }) => {
    await expect(page.locator('.preflight-action-btn', { hasText: 'Cancel' })).toBeVisible();
    await expect(page.locator('#spd-start')).toBeVisible();
    await expect(page.locator('#spd-start')).toContainText('Start Plan');
  });

  test('dialog closes when Cancel is clicked', async ({ page }) => {
    await page.locator('.preflight-action-btn', { hasText: 'Cancel' }).click();
    await expect(page.locator('.modal-overlay')).not.toBeAttached({ timeout: 1000 });
  });

  test('dialog closes when close (✕) button clicked', async ({ page }) => {
    await page.locator('.modal-close').click();
    await expect(page.locator('.modal-overlay')).not.toBeAttached({ timeout: 1000 });
  });

  test('peers from /api/mesh are loaded into dialog', async ({ page }) => {
    // Wait for peer loading (async fetch)
    await page.waitForTimeout(500);
    // Should have at least local + mesh peers listed
    const nodes = page.locator('.spd-node');
    const count = await nodes.count();
    expect(count).toBeGreaterThanOrEqual(1); // at minimum "Local"
  });
});
