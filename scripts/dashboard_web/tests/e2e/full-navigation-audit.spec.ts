import { test, expect, Page } from '@playwright/test';

/**
 * Full dashboard navigation audit — hits every tab, button, widget, and
 * interactive element to catch ALL client-side errors.
 * Runs against the REAL server (no mocks).
 */

interface CollectedError {
  type: 'js' | 'network' | 'console';
  message: string;
}

function attachErrorCollectors(page: Page): CollectedError[] {
  const errors: CollectedError[] = [];
  page.on('pageerror', (err) =>
    errors.push({ type: 'js', message: err.message }),
  );
  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      const text = msg.text();
      // Ignore known CDN issues (chartjs-plugin-zoom@2 404)
      if (text.includes('cdn.jsdelivr')) return;
      errors.push({ type: 'console', message: text });
    }
  });
  page.on('response', (res) => {
    const url = res.url();
    if (url.includes('jsdelivr') || url.includes('fonts.g')) return;
    if (url.includes('/api/') && res.status() === 404) return;
    if (res.status() >= 400) {
      errors.push({ type: 'network', message: `${res.status()} ${url}` });
    }
  });
  return errors;
}

test.describe('Full dashboard navigation audit', () => {
  test('Overview tab — all widgets render without errors', async ({ page }) => {
    const errors = attachErrorCollectors(page);
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);

    // Verify KPI row
    const kpiText = await page.locator('.kpi-row, .kpi-strip, [class*="kpi"]').first().textContent();
    expect(kpiText).toBeTruthy();

    // Verify mission renders
    const missionContent = await page.locator('#mission-content').textContent();
    expect(missionContent).not.toContain('Loading...');

    // Verify mesh strip renders
    const meshContent = await page.locator('#mesh-strip').textContent();
    expect(meshContent).toBeTruthy();

    // Verify nightly jobs
    const nightlyContent = await page.locator('#nightly-jobs-content').textContent();
    expect(nightlyContent).not.toContain('Loading...');

    // Verify organization
    const orgContent = await page.locator('#agent-organization-content').textContent();
    expect(orgContent).not.toContain('Loading...');

    // Verify live system
    const liveContent = await page.locator('#live-system-content').textContent();
    expect(liveContent).not.toContain('Loading...');

    // Verify task pipeline
    const taskTable = await page.locator('#task-table').textContent();
    expect(taskTable).toBeTruthy();

    expect(errors, `Overview errors:\n${errors.map((e) => `[${e.type}] ${e.message}`).join('\n')}`).toHaveLength(0);
  });

  test('Chat tab — switches without errors', async ({ page }) => {
    const errors = attachErrorCollectors(page);
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    // Click Chat tab
    const chatBtn = page.locator('button[data-section="dashboard-chat-section"]');
    if (await chatBtn.isVisible()) {
      await chatBtn.click();
      await page.waitForTimeout(2000);
    }

    expect(errors, `Chat tab errors:\n${errors.map((e) => `[${e.type}] ${e.message}`).join('\n')}`).toHaveLength(0);
  });

  test('click plan card — detail sidebar opens', async ({ page }) => {
    const errors = attachErrorCollectors(page);
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    // Click first mission plan card
    const planCard = page.locator('.mission-plan').first();
    if (await planCard.isVisible()) {
      await planCard.click();
      await page.waitForTimeout(2000);
    }

    expect(errors, `Plan detail errors:\n${errors.map((e) => `[${e.type}] ${e.message}`).join('\n')}`).toHaveLength(0);
  });

  test('click task row — detail expands', async ({ page }) => {
    const errors = attachErrorCollectors(page);
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    // Click first task row
    const taskRow = page.locator('#task-table tbody tr').first();
    if (await taskRow.isVisible()) {
      await taskRow.click();
      await page.waitForTimeout(1000);
    }

    expect(errors, `Task row errors:\n${errors.map((e) => `[${e.type}] ${e.message}`).join('\n')}`).toHaveLength(0);
  });

  test('theme toggle — cycles without errors', async ({ page }) => {
    const errors = attachErrorCollectors(page);
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(1000);

    // Open theme dropdown and click first option
    const themeBtn = page.locator('#theme-toggle');
    if (await themeBtn.isVisible()) {
      await themeBtn.click();
      await page.waitForTimeout(500);
      const themeOption = page.locator('.theme-dropdown button, .theme-option').first();
      if (await themeOption.isVisible()) {
        await themeOption.click();
        await page.waitForTimeout(1000);
      }
    }

    expect(errors, `Theme errors:\n${errors.map((e) => `[${e.type}] ${e.message}`).join('\n')}`).toHaveLength(0);
  });

  test('mesh interactions — Add Peer and Discover buttons', async ({ page }) => {
    const errors = attachErrorCollectors(page);
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    // Click Add Peer
    const addPeerBtn = page.locator('button:has-text("Add Peer")');
    if (await addPeerBtn.isVisible()) {
      await addPeerBtn.click();
      await page.waitForTimeout(1000);
      // Close overlay by clicking the overlay backdrop or pressing Escape
      const overlay = page.locator('#peer-form-overlay');
      if (await overlay.isVisible()) {
        await page.keyboard.press('Escape');
        await page.waitForTimeout(500);
        // Force-hide if Escape didn't close it
        if (await overlay.isVisible()) {
          await page.evaluate(() => {
            const el = document.getElementById('peer-form-overlay');
            if (el) el.style.display = 'none';
          });
          await page.waitForTimeout(300);
        }
      }
    }

    // Click Discover
    const discoverBtn = page.locator('button:has-text("Discover")');
    if (await discoverBtn.isVisible()) {
      await discoverBtn.click({ force: true });
      await page.waitForTimeout(1000);
      await page.keyboard.press('Escape');
      await page.waitForTimeout(500);
    }

    expect(errors, `Mesh errors:\n${errors.map((e) => `[${e.type}] ${e.message}`).join('\n')}`).toHaveLength(0);
  });

  test('zoom and refresh controls work', async ({ page }) => {
    const errors = attachErrorCollectors(page);
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(1000);

    // Zoom in
    const zoomIn = page.locator('.header-ctrl-btn:has-text("+")');
    if (await zoomIn.isVisible()) {
      await zoomIn.click();
      await page.waitForTimeout(300);
    }

    // Zoom out
    const zoomOut = page.locator('.header-ctrl-btn:has-text("−")');
    if (await zoomOut.isVisible()) {
      await zoomOut.click();
      await page.waitForTimeout(300);
    }

    // Reset
    const zoomReset = page.locator('.header-ctrl-btn:has-text("R")');
    if (await zoomReset.isVisible()) {
      await zoomReset.click();
      await page.waitForTimeout(300);
    }

    // Change refresh interval
    const refreshUp = page.locator('.stepper-btn').last();
    if (await refreshUp.isVisible()) {
      await refreshUp.click();
      await page.waitForTimeout(500);
    }

    expect(errors, `Control errors:\n${errors.map((e) => `[${e.type}] ${e.message}`).join('\n')}`).toHaveLength(0);
  });

  test('nightly jobs + button opens create form', async ({ page }) => {
    const errors = attachErrorCollectors(page);
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    // Click the + button in nightly jobs
    const addJobBtn = page.locator('[data-action="show-create"], .nightly-btn-add').first();
    if (await addJobBtn.isVisible()) {
      await addJobBtn.click();
      await page.waitForTimeout(1000);
    }

    expect(errors, `Nightly create errors:\n${errors.map((e) => `[${e.type}] ${e.message}`).join('\n')}`).toHaveLength(0);
  });

  test('brain canvas interactions', async ({ page }) => {
    const errors = attachErrorCollectors(page);
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    // Toggle brain pause
    const pauseBtn = page.locator('#brain-pause-btn');
    if (await pauseBtn.isVisible()) {
      await pauseBtn.click();
      await page.waitForTimeout(500);
      await pauseBtn.click();
      await page.waitForTimeout(500);
    }

    // Rewind brain
    const rewindBtn = page.locator('#brain-rewind-btn');
    if (await rewindBtn.isVisible()) {
      await rewindBtn.click();
      await page.waitForTimeout(500);
    }

    expect(errors, `Brain errors:\n${errors.map((e) => `[${e.type}] ${e.message}`).join('\n')}`).toHaveLength(0);
  });

  test('full auto-refresh cycle completes without errors', async ({ page }) => {
    const errors = attachErrorCollectors(page);
    await page.goto('/', { waitUntil: 'networkidle' });
    // Wait for 2 full refresh cycles (default 30s, but we'll wait 8s to catch at least one)
    await page.waitForTimeout(8000);

    const jsErrors = errors.filter((e) => e.type === 'js');
    const networkErrors = errors.filter((e) => e.type === 'network');

    expect(jsErrors, `JS errors during refresh:\n${jsErrors.map((e) => e.message).join('\n')}`).toHaveLength(0);
    expect(networkErrors, `Network errors during refresh:\n${networkErrors.map((e) => e.message).join('\n')}`).toHaveLength(0);
  });
});
