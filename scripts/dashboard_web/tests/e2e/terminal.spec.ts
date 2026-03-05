import { test, expect } from './fixtures';

/**
 * Helper: termMgr is a top-level `const` (not on `window`).
 * Use page.evaluate with string expression to access it from the script scope.
 */
const evalTerm = (page: import('@playwright/test').Page, expr: string) =>
  page.evaluate(expr);

/** Stub WebSocket so no real connection is attempted. */
async function stubWS(page: import('@playwright/test').Page, opts: { opensSuccessfully?: boolean; closeDelay?: number } = {}) {
  const { opensSuccessfully = false, closeDelay = 50 } = opts;
  await evalTerm(page, `
    window._FakeWSOpened = ${opensSuccessfully};
    window._FakeWSCloseDelay = ${closeDelay};
    window.WebSocket = class FakeWS {
      readyState = ${opensSuccessfully ? 1 : 3};
      binaryType = 'arraybuffer';
      onopen = null; onclose = null; onerror = null; onmessage = null;
      send() {} close() { if (this.onclose) this.onclose(); }
      constructor() {
        const self = this;
        if (window._FakeWSOpened) {
          setTimeout(() => { if (self.onopen) self.onopen(); }, 20);
          setTimeout(() => { if (self.onclose) self.onclose(); }, window._FakeWSCloseDelay);
        } else {
          setTimeout(() => { if (self.onerror) self.onerror(); }, 20);
          setTimeout(() => { if (self.onclose) self.onclose(); }, 40);
        }
      }
    };
  `);
}

test.describe('Terminal Manager', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });
  });

  test('terminal container is hidden on page load', async ({ page }) => {
    // _build() creates #term-main with display:none on DOMContentLoaded
    const display = await page.locator('#term-main').evaluate(el => getComputedStyle(el).display);
    expect(display).toBe('none');
  });

  test('terminal opens when termMgr.open is called', async ({ page }) => {
    await stubWS(page);
    await evalTerm(page, `termMgr.open('local', 'test')`);
    await page.waitForSelector('#term-main.open', { timeout: 2000 });
    await expect(page.locator('#term-main')).toBeVisible();
  });

  test('terminal stays open on WS failure — shows error message', async ({ page }) => {
    await stubWS(page, { opensSuccessfully: false });
    await evalTerm(page, `termMgr.open('local', 'local')`);
    await page.waitForSelector('#term-main.open', { timeout: 2000 });
    // Wait for WS error sequence
    await page.waitForTimeout(200);
    // Container should STILL be visible (the fix prevents auto-close)
    await expect(page.locator('#term-main')).toBeVisible();
    await expect(page.locator('#term-main')).toHaveClass(/open/);
    // Tab should still exist
    await expect(page.locator('.term-tab')).toHaveCount(1);
  });

  test('terminal auto-removes tab on normal session close (after successful open)', async ({ page }) => {
    await stubWS(page, { opensSuccessfully: true, closeDelay: 150 });
    await evalTerm(page, `termMgr.open('local', 'local')`);
    await page.waitForSelector('#term-main.open', { timeout: 2000 });
    // Wait for open + close sequence
    await page.waitForTimeout(400);
    // After successful open then close, container should auto-hide
    await expect(page.locator('#term-main')).not.toHaveClass(/open/);
  });

  test('terminal tabs show correct label', async ({ page }) => {
    await stubWS(page);
    await evalTerm(page, `termMgr.open('omarchy', 'omarchy')`);
    await page.waitForSelector('.term-tab', { timeout: 2000 });
    await expect(page.locator('.term-tab').first()).toContainText('omarchy');
  });

  test('multiple tabs can be created', async ({ page }) => {
    await stubWS(page);
    await evalTerm(page, `termMgr.open('local', 'Local')`);
    await evalTerm(page, `termMgr.open('omarchy', 'Omarchy')`);
    await page.waitForTimeout(150);
    const tabs = page.locator('.term-tab');
    await expect(tabs).toHaveCount(2);
    await expect(tabs.nth(0)).toContainText('Local');
    await expect(tabs.nth(1)).toContainText('Omarchy');
  });

  test('tab close button removes the tab', async ({ page }) => {
    await stubWS(page);
    await evalTerm(page, `termMgr.open('tab1', 'Tab 1')`);
    await evalTerm(page, `termMgr.open('tab2', 'Tab 2')`);
    await page.waitForTimeout(150);
    await expect(page.locator('.term-tab')).toHaveCount(2);
    // Close first tab
    await page.locator('.term-tab-close').first().click();
    await expect(page.locator('.term-tab')).toHaveCount(1);
    await expect(page.locator('.term-tab').first()).toContainText('Tab 2');
  });

  test('close button hides entire terminal', async ({ page }) => {
    await stubWS(page);
    await evalTerm(page, `termMgr.open('local', 'local')`);
    await page.waitForSelector('#term-main.open', { timeout: 2000 });
    await page.locator('.term-ctrl-close').click();
    await page.waitForTimeout(400);
    await expect(page.locator('#term-main')).not.toHaveClass(/open/);
  });

  test('terminal mode switching: dock → float → grid → full', async ({ page }) => {
    await stubWS(page);
    await evalTerm(page, `termMgr.open('local', 'local')`);
    await page.waitForSelector('#term-main', { timeout: 2000 });

    await expect(page.locator('#term-main')).toHaveClass(/term-dock/);
    await evalTerm(page, `termMgr.setMode('float')`);
    await expect(page.locator('#term-main')).toHaveClass(/term-float/);
    await evalTerm(page, `termMgr.setMode('grid')`);
    await expect(page.locator('#term-main')).toHaveClass(/term-grid/);
    await evalTerm(page, `termMgr.setMode('full')`);
    await expect(page.locator('#term-main')).toHaveClass(/term-full/);
  });

  test('tmux session label shows in tab', async ({ page }) => {
    await stubWS(page);
    await evalTerm(page, `termMgr.open('omarchy', 'omarchy', 'Convergio')`);
    await page.waitForSelector('.term-tab', { timeout: 2000 });
    await expect(page.locator('.term-tab').first()).toContainText('omarchy [Convergio]');
  });
});
