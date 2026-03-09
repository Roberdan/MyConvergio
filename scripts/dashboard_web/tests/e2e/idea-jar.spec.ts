import { test, expect } from './fixtures';

const MOCK_IDEAS = [
  { id: 1, title: 'Add dark mode', description: 'Support system-level dark mode', status: 'active', priority: 'P0', project: 'VirtualBPM', tags: 'ui,theme', created_at: '2026-03-01T10:00:00Z', updated_at: '2026-03-01T10:00:00Z' },
  { id: 2, title: 'API rate limiting', description: 'Prevent abuse on public endpoints', status: 'draft', priority: 'P1', project: '', tags: 'security', created_at: '2026-03-02T10:00:00Z', updated_at: '2026-03-02T10:00:00Z' },
  { id: 3, title: 'Mobile responsive', description: 'Make dashboard work on tablets', status: 'active', priority: 'P2', project: 'MyConvergio', tags: 'ui', created_at: '2026-03-03T10:00:00Z', updated_at: '2026-03-03T10:00:00Z' },
];

/** Setup: mock APIs and navigate to Idea Jar */
async function goToIdeaJar(page: import('@playwright/test').Page) {
  await page.route('**/api/ideas**', route => {
    if (route.request().method() === 'GET') {
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(MOCK_IDEAS) });
    }
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ ok: true, id: 99 }) });
  });
  await page.route('**/api/ideas/*/notes', route =>
    route.fulfill({ status: 200, contentType: 'application/json', body: '[]' }),
  );
  await page.locator('.header-nav-item', { hasText: 'Idea Jar' }).click();
  await page.waitForTimeout(500);
}

test.describe('Idea Jar', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });
  });

  test('idea jar section renders with idea cards', async ({ page }) => {
    await goToIdeaJar(page);
    await expect(page.locator('#dashboard-ideajar-section')).toBeVisible();
    const cards = page.locator('#dashboard-ideajar-section .mission-plan');
    await expect(cards).toHaveCount(3);
  });

  test('idea cards display title and priority badge', async ({ page }) => {
    await goToIdeaJar(page);
    const cards = page.locator('#dashboard-ideajar-section .mission-plan');
    await expect(cards.first()).toContainText('Add dark mode');
    await expect(cards.first()).toContainText('P0');
  });

  test('filter buttons are present', async ({ page }) => {
    await goToIdeaJar(page);
    const filters = page.locator('#dashboard-ideajar-section .widget-action-btn');
    const count = await filters.count();
    expect(count).toBeGreaterThanOrEqual(3);
  });

  test('idea cards show tags', async ({ page }) => {
    await goToIdeaJar(page);
    const firstCard = page.locator('#dashboard-ideajar-section .mission-plan').first();
    await expect(firstCard).toContainText('ui');
  });

  test('clicking idea card does not crash', async ({ page }) => {
    await goToIdeaJar(page);
    const firstCard = page.locator('#dashboard-ideajar-section .mission-plan').first();
    await firstCard.click();
    await page.waitForTimeout(300);
    // No crash — section still visible
    await expect(page.locator('#dashboard-ideajar-section')).toBeVisible();
  });
});
