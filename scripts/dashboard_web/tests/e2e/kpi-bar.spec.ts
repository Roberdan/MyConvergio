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

  test('shows GitHub KPI cards when stats available', async ({ page }) => {
    // Mock has githubStats with data, so GitHub KPIs should show
    const linesCard = page.locator('.kpi-card', { hasText: 'Lines Changed' });
    await expect(linesCard).toBeVisible();
    await expect(linesCard.locator('.kpi-value')).toContainText('1.5K');

    const commitsCard = page.locator('.kpi-card', { hasText: 'Commits Today' });
    await expect(commitsCard).toBeVisible();
    await expect(commitsCard.locator('.kpi-value')).toHaveText('4');

    const prsCard = page.locator('.kpi-card', { hasText: 'Open PRs' });
    await expect(prsCard).toBeVisible();
    await expect(prsCard.locator('.kpi-value')).toHaveText('3');
  });

  test('clicking KPI card scrolls and flashes target widget', async ({ page }) => {
    const tokensCard = page.locator('.kpi-card', { hasText: 'Tokens' });
    await tokensCard.click();
    // Check flash class applied
    await expect(page.locator('#widget-tokens')).toHaveClass(/widget-flash/);
  });
});

test.describe('KPI Bar — Fallback (no GitHub data)', () => {
  test('shows fallback KPIs when GitHub stats are zero', async ({ page, mockApis }) => {
    await mockApis({
      githubStats: {
        ok: true,
        plan_id: 300,
        lines_changed: 0,
        commits_today: 0,
        open_prs: 0,
        pr_merge_velocity: 0,
        commit_totals: { lines_added: 0, lines_removed: 0, files_changed: 0, commit_count: 0 },
      },
    });
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });

    // Fallback cards: Plans Done, Cost Today, Total Cost
    const doneCard = page.locator('.kpi-card', { hasText: 'Plans Done' });
    await expect(doneCard).toBeVisible();
    await expect(doneCard.locator('.kpi-value')).toHaveText('9');

    const costCard = page.locator('.kpi-card', { hasText: 'Cost Today' });
    await expect(costCard).toBeVisible();
  });
});
