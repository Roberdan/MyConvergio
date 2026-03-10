import { test, expect } from './fixtures';

test.describe('Header Navigation', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });
  });

  test('header renders with centered Convergio title', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Convergio');
  });

  test('header nav includes Overview, Admin, Planner and Idea Jar', async ({ page }) => {
    const navItems = page.locator('.header-nav-item');
    const labels = await navItems.allTextContents();
    expect(labels.length).toBeGreaterThanOrEqual(4);
    expect(labels.join(' ')).toContain('Overview');
    expect(labels.join(' ')).toContain('Admin');
    expect(labels.join(' ')).toContain('Planner');
    expect(labels.join(' ')).toContain('Idea Jar');
  });

  test('Overview nav item is active by default', async ({ page }) => {
    const overviewItem = page.locator('.header-nav-item', { hasText: 'Overview' });
    await expect(overviewItem).toHaveClass(/active/);
  });

  test('clicking Idea Jar switches section', async ({ page }) => {
    await page.route('**/api/ideas**', route =>
      route.fulfill({ status: 200, contentType: 'application/json', body: '[]' }),
    );
    const ideaJar = page.locator('.header-nav-item', { hasText: 'Idea Jar' });
    await ideaJar.click();
    await expect(ideaJar).toHaveClass(/active/);
    await expect(page.locator('#dashboard-ideajar-section')).toBeVisible();
  });

  test('clicking Planner switches section', async ({ page }) => {
    const planner = page.locator('.header-nav-item', { hasText: 'Planner' });
    await planner.click();
    await expect(planner).toHaveClass(/active/);
    await expect(page.locator('#dashboard-chat-section')).toBeVisible();
  });

  test('switching back to Overview restores dashboard', async ({ page }) => {
    await page.route('**/api/ideas**', route =>
      route.fulfill({ status: 200, contentType: 'application/json', body: '[]' }),
    );
    await page.locator('.header-nav-item', { hasText: 'Idea Jar' }).click();
    await expect(page.locator('#dashboard-ideajar-section')).toBeVisible();
    await page.locator('.header-nav-item', { hasText: 'Overview' }).click();
    await expect(page.locator('#dashboard-main-section')).toBeVisible();
  });

  test('terminal button is visible in header', async ({ page }) => {
    await expect(page.locator('.header-term-btn')).toBeVisible();
  });

  test('header controls (zoom, refresh, theme) are present', async ({ page }) => {
    const controls = page.locator('.header-ctrl-btn');
    const count = await controls.count();
    expect(count).toBeGreaterThanOrEqual(3);
  });
});
