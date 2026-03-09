import { test, expect } from './fixtures';

test.describe('Dashboard Core', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });
  });

  test('page loads with title and header', async ({ page }) => {
    await expect(page).toHaveTitle('Convergio Control Room');
    await expect(page.locator('h1')).toHaveText('Convergio');
  });

  test('clock updates every second', async ({ page }) => {
    const clock = page.locator('#clock');
    const t1 = await clock.textContent();
    await page.waitForTimeout(1200);
    const t2 = await clock.textContent();
    expect(t1).not.toBe(t2);
  });

  test('KPI bar renders all cards with correct values', async ({ page }) => {
    const cards = page.locator('.kpi-bar .kpi-card');
    await expect(cards).toHaveCount(9);

    // Active plans
    await expect(cards.nth(0)).toContainText('Active');
    await expect(cards.nth(0).locator('.kpi-value')).toHaveText('3');

    // Total plans
    await expect(cards.nth(1)).toContainText('Plans');
    await expect(cards.nth(1).locator('.kpi-value')).toHaveText('12');

    // Mesh online
    await expect(cards.nth(2)).toContainText('Mesh');
    await expect(cards.nth(2).locator('.kpi-value')).toHaveText('2/3');

    // Tokens
    await expect(cards.nth(3)).toContainText('Tokens');
    await expect(cards.nth(3).locator('.kpi-value')).toContainText('85.0M');

    // Blocked / stuck
    await expect(cards.nth(4)).toContainText('STUCK');
    await expect(cards.nth(4).locator('.kpi-value')).toHaveText('1');
    await expect(cards.nth(4)).toHaveClass(/alert/);

    // GitHub KPI metrics
    await expect(cards.nth(5)).toContainText('Lines Changed');
    await expect(cards.nth(5).locator('.kpi-value')).toContainText('1.5K');
    await expect(cards.nth(6)).toContainText('Commits Today');
    await expect(cards.nth(6).locator('.kpi-value')).toHaveText('4');
    await expect(cards.nth(7)).toContainText('Open PRs');
    await expect(cards.nth(7).locator('.kpi-value')).toHaveText('3');
    await expect(cards.nth(8)).toContainText('PR Merge Velocity');
    await expect(cards.nth(8).locator('.kpi-value')).toHaveText('1.5/day');
  });

  test('KPI card click scrolls to target widget', async ({ page }) => {
    const tokensCard = page.locator('.kpi-card', { hasText: 'Tokens' });
    await tokensCard.click();
    // Widget should get flash class
    await expect(page.locator('#widget-tokens')).toHaveClass(/widget-flash/);
  });

  test('zoom controls adjust body zoom', async ({ page }) => {
    const zoomIn = page.locator('.header-ctrl-btn', { hasText: '+' });
    const zoomOut = page.locator('.header-ctrl-btn', { hasText: '−' });
    const label = page.locator('#zoom-level');

    await expect(label).toHaveText('100%');
    await zoomIn.click();
    await expect(label).toHaveText('110%');
    await zoomOut.click();
    await zoomOut.click();
    await expect(label).toHaveText('90%');

    // Reset
    const reset = page.locator('.header-ctrl-btn', { hasText: 'R' });
    await reset.click();
    await expect(label).toHaveText('100%');
  });

  test('refresh rate stepper changes interval', async ({ page }) => {
    const label = page.locator('#refresh-label');
    await expect(label).toHaveText('30s');

    // Increase
    await page.locator('.stepper-btn', { hasText: '▶' }).click();
    await expect(label).toHaveText('1m');

    // Decrease twice
    await page.locator('.stepper-btn', { hasText: '◀' }).click();
    await page.locator('.stepper-btn', { hasText: '◀' }).click();
    await expect(label).toHaveText('15s');
  });

  test('last update timestamp appears after load', async ({ page }) => {
    await expect(page.locator('#last-update')).toContainText('Updated:');
  });

  test('two-column layout renders left and right columns', async ({ page }) => {
    await expect(page.locator('.dash-col-left')).toBeVisible();
    await expect(page.locator('.dash-col-right')).toBeVisible();
    // Left: mission panel, task pipeline, distribution, kanban
    expect(await page.locator('.dash-col-left .widget').count()).toBeGreaterThanOrEqual(4);
    // Right: mesh, brain, agent-org, live-system, event-feed, nightly, tokens, cost, history
    expect(await page.locator('.dash-col-right .widget').count()).toBeGreaterThanOrEqual(9);
  });
});
