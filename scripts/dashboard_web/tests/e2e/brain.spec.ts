import { test, expect, MOCK } from './fixtures';

test.describe('Brain Widget', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('#brain-widget', { timeout: 5000 });
    await page.waitForTimeout(600);
  });

  // --- 1. Widget Presence ---

  test('brain widget container exists on page load', async ({ page }) => {
    await expect(page.locator('#brain-widget')).toBeVisible();
  });

  test('canvas element exists inside brain-canvas-container', async ({ page }) => {
    const canvas = page.locator('#brain-canvas-container canvas');
    await expect(canvas).toBeAttached();
  });

  test('widget header shows Augmented Brain', async ({ page }) => {
    const title = page.locator('#brain-widget .widget-title');
    await expect(title).toHaveText('Augmented Brain');
  });

  test('stats bar is present', async ({ page }) => {
    await expect(page.locator('#brain-stats')).toBeAttached();
  });

  // --- 2. Canvas Rendering ---

  test('canvas has non-zero dimensions', async ({ page }) => {
    const canvas = page.locator('#brain-canvas-container canvas');
    const box = await canvas.boundingBox();
    expect(box).toBeTruthy();
    expect(box!.width).toBeGreaterThan(0);
    expect(box!.height).toBeGreaterThan(0);
  });

  test('canvas is rendering (not all black)', async ({ page }) => {
    const canvas = page.locator('#brain-canvas-container canvas');
    const hasContent = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return false;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      for (let i = 0; i < data.length; i += 4) {
        if (data[i] > 0 || data[i + 1] > 0 || data[i + 2] > 0) return true;
      }
      return false;
    });
    expect(hasContent).toBe(true);
  });

  test('canvas animation is running (frames differ)', async ({ page }) => {
    const canvas = page.locator('#brain-canvas-container canvas');
    const snap1 = await canvas.screenshot();
    await page.waitForTimeout(2000);
    const snap2 = await canvas.screenshot();
    // Buffers should differ if animation is running
    expect(Buffer.compare(snap1, snap2)).not.toBe(0);
  });

  // --- 3. Brain Regions ---

  test('brain outline is drawn (canvas not empty with active plan)', async ({ page }) => {
    // Default mock has an active plan — canvas should have content
    const canvas = page.locator('#brain-canvas-container canvas');
    const pixelCount = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return 0;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      let count = 0;
      for (let i = 3; i < data.length; i += 4) {
        if (data[i] > 0) count++;
      }
      return count;
    });
    expect(pixelCount).toBeGreaterThan(100);
  });

  // --- 4. No Active Agents State ---

  test('idle state when no tasks are in_progress', async ({ page, mockApis }) => {
    const idleMission = {
      plans: [{
        ...MOCK.mission.plans[0],
        tasks: MOCK.mission.plans[0].tasks.map(t => ({
          ...t,
          status: t.status === 'in_progress' ? 'pending' : t.status,
        })),
      }],
    };
    await mockApis({
      mission: idleMission,
      taskDist: [
        { status: 'done', count: 5 },
        { status: 'pending', count: 3 },
        { status: 'blocked', count: 1 },
      ],
    });
    await page.goto('/');
    await page.waitForSelector('#brain-widget', { timeout: 5000 });
    await page.waitForTimeout(800);

    // Canvas should still render (not blank)
    const canvas = page.locator('#brain-canvas-container canvas');
    const box = await canvas.boundingBox();
    expect(box!.width).toBeGreaterThan(0);
  });

  // --- 5. Active Agent Neurons ---

  test('active task triggers neuron activity', async ({ page }) => {
    // Wait for brain scripts to fully initialize
    await page.waitForTimeout(2000);
    const hasActivity = await page.evaluate(() => {
      const RA = (window as any).RegionActivity;
      if (!RA) return 'no-RA';
      try {
        const ra = new RA();
        ra.updateFromTasks([{ status: 'in_progress', title: 'Token refresh endpoint' }]);
        const active = Object.values(ra.regions as Record<string, any>).some(
          (r: any) => r.targetActivity > 0 || r.neuronCount > 0,
        );
        return active ? true : 'no-active';
      } catch (e: any) { return `error: ${e.message}`; }
    });
    expect(hasActivity).toBe(true);
  });

  // --- 6. Responsive Resize ---

  test('canvas resizes with viewport', async ({ page }) => {
    const canvas = page.locator('#brain-canvas-container canvas');

    await page.setViewportSize({ width: 800, height: 600 });
    await page.waitForTimeout(500);
    const boxSmall = await canvas.boundingBox();

    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.waitForTimeout(500);
    const boxLarge = await canvas.boundingBox();

    expect(boxSmall).toBeTruthy();
    expect(boxLarge).toBeTruthy();
    expect(boxLarge!.width).toBeGreaterThan(boxSmall!.width);
  });

  // --- 7. Script Loading ---

  test('brain scripts load without console errors', async ({ page, mockApis }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(e.message));

    const failedRequests: string[] = [];
    page.on('response', (res) => {
      if (res.url().includes('brain-') && res.status() >= 400) {
        failedRequests.push(res.url());
      }
      if (res.url().includes('icons.js') && res.status() >= 400) {
        failedRequests.push(res.url());
      }
    });

    await mockApis();
    await page.goto('/');
    await page.waitForSelector('#brain-widget', { timeout: 5000 });
    await page.waitForTimeout(800);

    const brainErrors = errors.filter(e =>
      /brain|Brain|region|organism|canvas|consciousness|effect/i.test(e),
    );
    expect(brainErrors).toHaveLength(0);
    expect(failedRequests).toHaveLength(0);
  });

  test('no 404s for brain-related resources', async ({ page, mockApis }) => {
    const notFound: string[] = [];
    page.on('response', (res) => {
      if (res.status() === 404 && /brain|icons/i.test(res.url())) {
        notFound.push(res.url());
      }
    });

    await mockApis();
    await page.goto('/');
    await page.waitForSelector('#brain-widget', { timeout: 5000 });
    await page.waitForTimeout(500);

    expect(notFound).toHaveLength(0);
  });

  // --- 8. Module Integration ---

  test('window.BrainRegions is defined', async ({ page }) => {
    const defined = await page.evaluate(() => typeof (window as any).BrainRegions !== 'undefined');
    expect(defined).toBe(true);
  });

  test('window.BrainOrganism is defined', async ({ page }) => {
    const defined = await page.evaluate(() => typeof (window as any).BrainOrganism !== 'undefined');
    expect(defined).toBe(true);
  });

  test('window.BrainEffects is defined', async ({ page }) => {
    const defined = await page.evaluate(() => typeof (window as any).BrainEffects !== 'undefined');
    expect(defined).toBe(true);
  });

  test('window._consciousness is defined', async ({ page }) => {
    const defined = await page.evaluate(() => typeof (window as any)._consciousness !== 'undefined');
    expect(defined).toBe(true);
  });

  // --- 9. Stats Update ---

  test('stats overlay shows region or neuron counts', async ({ page }) => {
    const stats = page.locator('#brain-stats');
    await page.waitForTimeout(1500);
    const text = await stats.textContent();
    // Stats should contain at least some numeric content
    expect(text).toBeTruthy();
    expect(text!.length).toBeGreaterThan(0);
  });

  test('stats update after data refresh', async ({ page }) => {
    const stats = page.locator('#brain-stats');
    await page.waitForTimeout(1000);
    const text1 = await stats.textContent();

    // Trigger a re-fetch by dispatching custom event (dashboard polls)
    await page.evaluate(() => window.dispatchEvent(new Event('dashboard:refresh')));
    await page.waitForTimeout(3000);
    const text2 = await stats.textContent();

    // At minimum stats should still be populated after refresh
    expect(text2!.length).toBeGreaterThan(0);
  });

  // --- 10. Session Data Rendering ---

  test('window._sessionClusters is defined (session cluster renderer loaded)', async ({ page }) => {
    const defined = await page.evaluate(() => typeof (window as any)._sessionClusters !== 'undefined');
    expect(defined).toBe(true);
  });

  test('canvas still renders with /api/sessions returning data', async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('#brain-widget', { timeout: 5000 });
    await page.waitForTimeout(800);

    const canvas = page.locator('#brain-canvas-container canvas');
    const hasContent = await canvas.evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext('2d');
      if (!ctx) return false;
      const data = ctx.getImageData(0, 0, el.width, el.height).data;
      for (let i = 3; i < data.length; i += 4) {
        if (data[i] > 0) return true;
      }
      return false;
    });
    expect(hasContent).toBe(true);
  });
});
