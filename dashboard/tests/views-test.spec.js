// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('View Isolation Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('Waves view shows only waves content', async ({ page }) => {
    await page.click('text=Waves');
    await page.waitForTimeout(500);

    const wavesView = page.locator('#wavesView');
    const kanbanView = page.locator('#kanbanView');
    const bugsView = page.locator('#bugsView');
    const agentsView = page.locator('#agentsView');
    const wavesSummary = page.locator('#wavesSummary');

    await expect(wavesView).toBeVisible();
    await expect(kanbanView).not.toBeVisible();
    await expect(bugsView).not.toBeVisible();
    await expect(agentsView).not.toBeVisible();
    await expect(wavesSummary).not.toBeVisible();

    await page.screenshot({ path: 'test-results/waves-view.png', fullPage: true });
  });

  test('Issues view shows only issues content', async ({ page }) => {
    await page.click('text=Issues');
    await page.waitForTimeout(500);

    const bugsView = page.locator('#bugsView');
    const wavesView = page.locator('#wavesView');
    const agentsView = page.locator('#agentsView');

    await expect(bugsView).toBeVisible();
    await expect(wavesView).not.toBeVisible();
    await expect(agentsView).not.toBeVisible();

    await page.screenshot({ path: 'test-results/issues-view.png', fullPage: true });
  });

  test('Agents view shows only agents content', async ({ page }) => {
    await page.click('text=Agents');
    await page.waitForTimeout(500);

    const agentsView = page.locator('#agentsView');
    const wavesView = page.locator('#wavesView');
    const bugsView = page.locator('#bugsView');

    await expect(agentsView).toBeVisible();
    await expect(wavesView).not.toBeVisible();
    await expect(bugsView).not.toBeVisible();

    await page.screenshot({ path: 'test-results/agents-view.png', fullPage: true });
  });
});
