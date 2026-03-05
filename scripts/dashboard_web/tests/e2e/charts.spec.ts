import { test, expect } from './fixtures';

test.describe('Charts', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('#token-chart', { timeout: 5000 });
    // Wait for Chart.js to render
    await page.waitForTimeout(500);
  });

  test('token burn chart renders with data points', async ({ page }) => {
    const canvas = page.locator('#token-chart');
    await expect(canvas).toBeVisible();
    // Chart.js populates canvas — verify it has non-zero dimensions
    const box = await canvas.boundingBox();
    expect(box!.width).toBeGreaterThan(100);
    expect(box!.height).toBeGreaterThan(50);
    // Verify chart instance exists in window
    const hasChart = await page.evaluate(() => {
      const c = (window as any).Chart?.getChart?.('token-chart');
      return c && c.data.datasets.length === 2;
    });
    expect(hasChart).toBe(true);
  });

  test('token burn chart has Input and Output datasets', async ({ page }) => {
    const labels = await page.evaluate(() => {
      const c = (window as any).Chart.getChart('token-chart');
      return c.data.datasets.map((d: any) => d.label);
    });
    expect(labels).toEqual(['Input', 'Output']);
  });

  test('token burn chart has 8 data points from mock data', async ({ page }) => {
    const count = await page.evaluate(() => {
      const c = (window as any).Chart.getChart('token-chart');
      return c.data.labels.length;
    });
    expect(count).toBe(8);
  });

  test('token burn chart x-axis shows date labels', async ({ page }) => {
    const labels = await page.evaluate(() => {
      const c = (window as any).Chart.getChart('token-chart');
      return c.data.labels;
    });
    expect(labels).toContain('02-26');
    expect(labels).toContain('03-05');
  });

  test('token chart zoom reset button works', async ({ page }) => {
    const resetBtn = page.locator('#widget-tokens .widget-action-btn');
    await expect(resetBtn).toBeVisible();
    // Click should not throw
    await resetBtn.click();
  });

  test('cost by model doughnut chart renders', async ({ page }) => {
    const canvas = page.locator('#model-chart');
    await expect(canvas).toBeVisible();
    const hasChart = await page.evaluate(() => {
      const c = (window as any).Chart?.getChart?.('model-chart');
      return c && c.config.type === 'doughnut';
    });
    expect(hasChart).toBe(true);
  });

  test('cost by model shows total in header', async ({ page }) => {
    const header = page.locator('#widget-cost .widget-title');
    await expect(header).toContainText('Total: $342.50');
  });

  test('cost by model chart has 4 model segments', async ({ page }) => {
    const count = await page.evaluate(() => {
      const c = (window as any).Chart.getChart('model-chart');
      return c.data.labels.length;
    });
    expect(count).toBe(4);
  });

  test('task distribution bar chart renders', async ({ page }) => {
    const canvas = page.locator('#dist-chart');
    await expect(canvas).toBeVisible();
    const info = await page.evaluate(() => {
      const c = (window as any).Chart?.getChart?.('dist-chart');
      return { type: c?.config.type, labels: c?.data.labels };
    });
    expect(info.type).toBe('bar');
    expect(info.labels).toContain('done');
    expect(info.labels).toContain('blocked');
  });

  test('charts handle empty data gracefully', async ({ page, mockApis }) => {
    // Override with empty arrays
    await mockApis({ tokensDaily: [], tokensModels: [], taskDist: [] });
    await page.goto('/');
    await page.waitForTimeout(800);
    // Page should load without JS errors
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.waitForTimeout(500);
    expect(errors).toHaveLength(0);
  });
});
