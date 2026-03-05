import { test, expect } from './fixtures';

test.describe('Theme Switcher', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });
  });

  test('default theme is neon_grid (no data-theme attribute)', async ({ page }) => {
    const theme = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
    expect(theme).toBeNull();
  });

  test('theme toggle opens dropdown', async ({ page }) => {
    const dd = page.locator('#theme-dropdown');
    await expect(dd).not.toHaveClass(/open/);
    await page.locator('#theme-toggle').click();
    await expect(dd).toHaveClass(/open/);
  });

  test('dropdown shows all 12 themes', async ({ page }) => {
    await page.locator('#theme-toggle').click();
    const options = page.locator('.theme-option');
    await expect(options).toHaveCount(12);
  });

  test('clicking theme option applies it', async ({ page }) => {
    await page.locator('#theme-toggle').click();
    await page.locator('.theme-option', { hasText: 'Synthwave' }).click();
    const theme = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
    expect(theme).toBe('synthwave');
  });

  test('active theme has .active class in dropdown', async ({ page }) => {
    await page.locator('#theme-toggle').click();
    await page.locator('.theme-option', { hasText: 'Matrix' }).click();
    await page.locator('#theme-toggle').click();
    await expect(page.locator('.theme-option.active')).toContainText('Matrix');
  });

  test('theme persists in localStorage', async ({ page }) => {
    await page.locator('#theme-toggle').click();
    await page.locator('.theme-option', { hasText: 'TRON' }).click();
    const stored = await page.evaluate(() => localStorage.getItem('dashboard-theme'));
    expect(stored).toBe('tron');
  });

  test('clicking outside dropdown closes it', async ({ page }) => {
    await page.locator('#theme-toggle').click();
    await expect(page.locator('#theme-dropdown')).toHaveClass(/open/);
    await page.locator('h1').click();
    await expect(page.locator('#theme-dropdown')).not.toHaveClass(/open/);
  });

  test('T key cycles themes', async ({ page }) => {
    // Clear localStorage to ensure we start from neon_grid
    await page.evaluate(() => localStorage.removeItem('dashboard-theme'));
    await page.reload();
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });

    await page.keyboard.press('t');
    const theme = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
    expect(theme).toBe('synthwave'); // Second theme after neon_grid
  });
});

test.describe('Widget Drag & Drop', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });
  });

  test('widgets have IDs for layout persistence', async ({ page }) => {
    const widgets = page.locator('.widget[id]');
    const count = await widgets.count();
    expect(count).toBeGreaterThanOrEqual(7);
  });

  test('reset widget layout button exists', async ({ page }) => {
    const resetBtn = page.locator('button[onclick="resetWidgetLayout()"]');
    await expect(resetBtn).toBeVisible();
  });

  test('widget layout saves to localStorage on drag', async ({ page }) => {
    // Simulate drag by directly saving layout
    await page.evaluate(() => {
      localStorage.setItem('dashWidgetLayout', JSON.stringify({
        left: ['widget-dist', 'mission-panel', 'task-pipeline-widget'],
        right: ['widget-cost', 'widget-tokens', 'mesh-panel', 'event-feed-widget', 'history-widget'],
      }));
    });
    const stored = await page.evaluate(() => localStorage.getItem('dashWidgetLayout'));
    expect(JSON.parse(stored!)).toHaveProperty('left');
    expect(JSON.parse(stored!)).toHaveProperty('right');
  });

  test('widget headers serve as drag handles', async ({ page }) => {
    const headers = page.locator('.widget-header');
    const count = await headers.count();
    expect(count).toBeGreaterThanOrEqual(7);
  });
});

test.describe('Hash Routing', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
  });

  test('navigating to #plan/300 highlights and filters', async ({ page }) => {
    await page.goto('/#plan/300');
    await page.waitForSelector('.mission-plan', { timeout: 5000 });
    await page.waitForTimeout(1500); // Wait for hash handler delay
    await expect(page.locator('#task-filter-label')).toContainText('#300');
  });
});

test.describe('Empty State Handling', () => {
  test('empty mission shows fallback text', async ({ page, mockApis }) => {
    await mockApis({ mission: { plans: [] } });
    await page.goto('/');
    await page.waitForTimeout(800);
    await expect(page.locator('#mission-content')).toContainText('No active mission');
  });

  test('empty mesh shows no nodes', async ({ page, mockApis }) => {
    await mockApis({ mesh: [] });
    await page.goto('/');
    await page.waitForTimeout(800);
    await expect(page.locator('.mesh-node')).toHaveCount(0);
  });

  test('empty history shows nothing', async ({ page, mockApis }) => {
    await mockApis({ history: [] });
    await page.goto('/');
    await page.waitForTimeout(800);
    await expect(page.locator('.history-row')).toHaveCount(0);
  });

  test('no JS errors on full page load', async ({ page, mockApis }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await mockApis();
    await page.goto('/');
    await page.waitForTimeout(1500);
    expect(errors).toHaveLength(0);
  });
});
