import { test, expect, MOCK } from './fixtures';

test.describe('KPI Bar', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });
  });

  test('renders 8-9 KPI cards', async ({ page }) => {
    const cards = page.locator('.kpi-bar .kpi-card');
    const count = await cards.count();
    // 5 base + 4 github OR 5 base + 3 fallback
    expect(count).toBeGreaterThanOrEqual(8);
    expect(count).toBeLessThanOrEqual(9);
  });

  test('shows Active plans count', async ({ page }) => {
    const card = page.locator('.kpi-card', { hasText: 'Active' });
    await expect(card.locator('.kpi-value')).toHaveText('3');
  });

  test('shows total Plans count with done sub', async ({ page }) => {
    const cards = page.locator('.kpi-bar .kpi-card');
    // Plans card is the second one (index 1)
    const plansCard = cards.nth(1);
    await expect(plansCard).toContainText('Plans');
    await expect(plansCard.locator('.kpi-value')).toHaveText('12');
    await expect(plansCard.locator('.kpi-sub')).toContainText('9 done');
  });

  test('shows Mesh nodes online', async ({ page }) => {
    const card = page.locator('.kpi-card', { hasText: 'Mesh' });
    await expect(card.locator('.kpi-value')).toHaveText('2/3');
  });

  test('shows Tokens with today sub', async ({ page }) => {
    const card = page.locator('.kpi-card', { hasText: 'Tokens' });
    await expect(card.locator('.kpi-value')).toContainText('85.0M');
  });

  test('blocked card has alert class when > 0', async ({ page }) => {
    // overview mock has blocked: 1
    const card = page.locator('.kpi-card', { hasText: /STUCK|Blocked/ });
    await expect(card).toHaveClass(/alert/);
  });

  test('shows operational KPI cards', async ({ page }) => {
    const linesCard = page.locator('.kpi-card', { hasText: 'Lines Today' });
    await expect(linesCard).toBeVisible();
    await expect(linesCard.locator('.kpi-value')).toHaveText('0');

    const weeklyCard = page.locator('.kpi-card', { hasText: 'Lines / Week' });
    await expect(weeklyCard).toBeVisible();
    await expect(weeklyCard.locator('.kpi-value')).toHaveText('0');

    const costCard = page.locator('.kpi-card', { hasText: 'Cost Today' });
    await expect(costCard).toBeVisible();

    const agentsCard = page.locator('.kpi-card', { hasText: 'Agents Today' });
    await expect(agentsCard).toBeVisible();
  });

  test('clicking KPI card scrolls and flashes target widget', async ({ page }) => {
    const tokensCard = page.locator('.kpi-card', { hasText: 'Tokens' });
    await tokensCard.click();
    // Check flash class applied
    await expect(page.locator('#widget-tokens')).toHaveClass(/widget-flash/);
  });
});

test.describe('KPI Bar — zero line metrics', () => {
  test('shows zero values when line metrics are not provided', async ({ page, mockApis }) => {
    await mockApis({
      overview: {
        ...MOCK.overview,
        today_lines_changed: 0,
        week_lines_changed: 0,
      },
    });
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });

    const linesToday = page.locator('.kpi-card', { hasText: 'Lines Today' });
    await expect(linesToday.locator('.kpi-value')).toHaveText('0');
    const linesWeek = page.locator('.kpi-card', { hasText: 'Lines / Week' });
    await expect(linesWeek.locator('.kpi-value')).toHaveText('0');
  });
});
