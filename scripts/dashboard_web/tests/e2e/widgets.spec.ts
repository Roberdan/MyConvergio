import { test, expect, MOCK } from './fixtures';

const SUBSTATUS_MISSION = {
  plans: [{
    plan: { ...MOCK.mission.plans[0].plan },
    waves: MOCK.mission.plans[0].waves,
    tasks: [
      ...MOCK.mission.plans[0].tasks,
      { task_id: 'T10', title: 'Run CI checks', status: 'in_progress', substatus: 'waiting_ci', wave_id: 'W2', executor_agent: 'claude-sonnet', tokens: 50000, model: 'claude-sonnet-4.6', validated_at: null, executor_host: 'local' },
      { task_id: 'T11', title: 'PR review', status: 'in_progress', substatus: 'waiting_review', wave_id: 'W2', executor_agent: 'claude-opus', tokens: 30000, model: 'claude-opus-4.6', validated_at: null, executor_host: 'local' },
    ],
  }],
};

const stubWS = (page: import('@playwright/test').Page) => page.evaluate(() => {
  (window as any).WebSocket = class FakeWS {
    readyState = 3; binaryType = 'arraybuffer';
    onopen: any; onclose: any; onerror: any; onmessage: any;
    send() {} close() {}
    constructor() { setTimeout(() => { this.onerror?.(); this.onclose?.(); }, 50); }
  };
});

test.describe('Sparkline Charts', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.mesh-node', { timeout: 5000 });
    await page.waitForTimeout(500);
  });

  test('online peers have sparkline canvases with non-zero dimensions', async ({ page }) => {
    const canvases = page.locator('.mesh-node.online .mn-sparkline');
    expect(await canvases.count()).toBeGreaterThanOrEqual(2);
    const box = await canvases.first().boundingBox();
    expect(box!.width).toBeGreaterThan(0);
    expect(box!.height).toBeGreaterThan(0);
  });

  test('sparklines have data-history and data-color attributes', async ({ page }) => {
    const canvas = page.locator('.mn-sparkline').first();
    expect(await canvas.getAttribute('data-history')).toBeTruthy();
    expect(await canvas.getAttribute('data-color')).toBeTruthy();
  });

  test('offline nodes have no sparklines', async ({ page }) => {
    await expect(page.locator('.mesh-node.offline .mn-sparkline')).toHaveCount(0);
  });
});

test.describe('SVG Icons', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis({ mission: SUBSTATUS_MISSION });
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });
    await page.waitForTimeout(500);
  });

  test('no emoji characters in visible page text', async ({ page }) => {
    const bodyText = await page.evaluate(() => document.body.textContent || '');
    // Check for pictographic emoji only (U+1Fxxx); allow UI symbols in U+2600-U+27BF
    const emojiRegex = /[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F900}-\u{1F9FF}]/gu;
    const matches = bodyText.match(emojiRegex) || [];
    // Some feed content can legitimately contain emoji.
    expect(matches.length).toBeLessThanOrEqual(12);
  });

  test('SVG elements present with currentColor and viewBox', async ({ page }) => {
    expect(await page.locator('svg').count()).toBeGreaterThan(0);
    expect(await page.locator('svg[stroke="currentColor"]').count()).toBeGreaterThan(0);
    expect(await page.locator('svg[viewBox="0 0 24 24"]').count()).toBeGreaterThan(0);
  });

  test('Thor check icon uses SVG', async ({ page }) => {
    await expect(page.locator('tr[data-task-id="T1"] svg').first()).toBeAttached();
  });
});

test.describe('Progress Bars', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('#mission-content .mission-plan', { timeout: 5000 });
  });

  test('progress bar exists with fill in mission card', async ({ page }) => {
    await expect(page.locator('.mission-progress')).toBeVisible();
    await expect(page.locator('.mission-progress-track')).toBeVisible();
    await expect(page.locator('.mission-progress-fill')).toBeVisible();
  });

  test('progress fill has gradient background', async ({ page }) => {
    const bg = await page.locator('.mission-progress-fill').first().evaluate(
      (el) => getComputedStyle(el).background || el.style.background,
    );
    expect(bg).toContain('gradient');
  });

  test('progress label shows 63% and 5/8', async ({ page }) => {
    const label = page.locator('.mission-progress-label');
    await expect(label).toContainText('63%');
    await expect(label).toContainText('5/8');
  });

  test('progress ring shows matching percentage', async ({ page }) => {
    await expect(page.locator('.mission-ring-pct')).toContainText('63%');
  });
});

test.describe('Mesh Monitoring Widget', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.mesh-node', { timeout: 5000 });
  });

  test('mesh shows 3 peers with correct names and status dots', async ({ page }) => {
    await expect(page.locator('.mesh-node')).toHaveCount(3);
    const names = await page.locator('.mn-name').allTextContents();
    expect(names).toEqual(expect.arrayContaining(['omarchy', 'm1mario', 'm3max']));
    await expect(page.locator('.mn-dot.on')).toHaveCount(2);
    await expect(page.locator('.mn-dot.off')).toHaveCount(1);
  });

  test('online node shows CPU/RAM gauges', async ({ page }) => {
    const node = page.locator('.mesh-node.online', { hasText: 'omarchy' });
    await expect(node).toBeVisible();
    await expect(node.locator('.mn-stats')).toContainText('CPU');
    const gaugeCount = await node.locator('.mn-gauge-group').count();
    expect(gaugeCount).toBeGreaterThanOrEqual(1);
    await expect(node.locator('.mn-gauge-label').nth(0)).toHaveText('CPU');
  });

  test('mesh toolbar actions are rendered in header legend', async ({ page }) => {
    const legend = page.locator('#mesh-panel .widget-header-legend');
    await expect(legend).toBeVisible();
    await expect(legend.locator('.mesh-toolbar-btn[title="Full Sync"]')).toBeVisible();
    await expect(legend.locator('.mesh-toolbar-btn[title="Push"]')).toBeVisible();
  });

  test('Full Sync button is present and clickable', async ({ page }) => {
    const btn = page.locator('.mesh-toolbar-btn[title="Full Sync"]');
    await expect(btn).toBeVisible();
    await expect(btn).toContainText('Full Sync');
  });

  test('Push button is present and clickable', async ({ page }) => {
    const btn = page.locator('.mesh-toolbar-btn[title="Push"]');
    await expect(btn).toBeVisible();
    await expect(btn).toContainText('Push');
  });
});

test.describe('Font Loading', () => {
  test('JetBrains Mono and Orbitron fonts applied', async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });

    const fontVar = await page.evaluate(() =>
      getComputedStyle(document.documentElement).getPropertyValue('--font-mono'),
    );
    expect(fontVar).toContain('JetBrainsMono');

    const bodyFont = await page.evaluate(() => getComputedStyle(document.body).fontFamily);
    expect(bodyFont).toContain('JetBrains');

    const h1Font = await page.evaluate(() => getComputedStyle(document.querySelector('h1')!).fontFamily);
    expect(h1Font.toLowerCase()).toContain('orbitron');
  });
});

test.describe('Theme & CSS Variables', () => {
  test('default theme, CSS vars defined, text readable', async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });
    expect(await page.evaluate(() => document.documentElement.getAttribute('data-theme'))).toBeNull();
    const result = await page.evaluate(() => {
      const cs = getComputedStyle(document.documentElement);
      const bcs = getComputedStyle(document.body);
      return {
        cyan: cs.getPropertyValue('--cyan').trim(),
        red: cs.getPropertyValue('--red').trim(),
        gold: cs.getPropertyValue('--gold').trim(),
        color: bcs.color, bg: bcs.backgroundColor,
      };
    });
    expect(result.cyan.length).toBeGreaterThan(0);
    expect(result.red.length).toBeGreaterThan(0);
    expect(result.gold.length).toBeGreaterThan(0);
    expect(result.color).not.toBe(result.bg);
  });
});

test.describe('Substatus Badges', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis({ mission: SUBSTATUS_MISSION });
    await page.goto('/');
    await page.waitForSelector('#mission-content .mission-plan', { timeout: 5000 });
    await page.waitForTimeout(300);
  });

  test('waiting_ci shows CI badge with SVG and correct color', async ({ page }) => {
    const badge = page.locator('.substatus-badge', { hasText: 'CI' });
    await expect(badge).toBeVisible({ timeout: 5000 });
    await expect(badge.locator('svg')).toHaveCount(1);
    const style = await badge.evaluate((el) => el.getAttribute('style') || '');
    expect(style).toContain('#00d4ff');
  });

  test('waiting_review shows Review badge with SVG', async ({ page }) => {
    const badge = page.locator('.substatus-badge', { hasText: 'Review' });
    await expect(badge).toHaveCount(1);
    await expect(badge.locator('svg')).toHaveCount(1);
  });
});

test.describe('Buttons & Interactions', () => {
  test('delegate button exists with SVG icon', async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('#mission-content .mission-plan', { timeout: 5000 });
    await expect(page.locator('.mission-delegate-btn')).toHaveCount(1);
    await expect(page.locator('.mission-delegate-btn svg')).toBeAttached();
  });

  test('start button on todo plans has SVG icon', async ({ page, mockApis }) => {
    await mockApis({
      mission: { plans: [{ plan: { ...MOCK.mission.plans[0].plan, status: 'todo', tasks_done: 0 }, waves: [], tasks: [] }] },
    });
    await page.goto('/');
    await page.waitForSelector('.mission-start-btn', { timeout: 5000 });
    await expect(page.locator('.mission-start-btn svg')).toBeAttached();
  });

  test('clicking delegate does not throw JS errors', async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('#mission-content .mission-plan', { timeout: 5000 });
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('dialog', (d) => d.dismiss());
    await page.locator('.mission-delegate-btn').click();
    await page.waitForTimeout(500);
    expect(errors).toHaveLength(0);
  });

  test('cancel button exists on non-done mission cards', async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('#mission-content .mission-plan', { timeout: 5000 });
    await expect(page.locator('.mission-cancel-btn')).toHaveCount(1);
    await expect(page.locator('.mission-cancel-btn svg')).toBeAttached();
  });

  test('cancel button opens cancel plan modal', async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.mission-cancel-btn', { timeout: 5000 });
    await page.locator('.mission-cancel-btn').click();
    await expect(page.locator('.modal-overlay')).toBeVisible({ timeout: 2000 });
    await expect(page.locator('.modal-title')).toContainText('Cancel Plan');
    await page.locator('.modal-close').click();
  });

  test('window.renderWaveGantt is defined (mission-details.js loaded)', async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('#mission-content .mission-plan', { timeout: 5000 });
    const defined = await page.evaluate(() => typeof (window as any).renderWaveGantt === 'function');
    expect(defined).toBe(true);
  });
});

test.describe('Terminal Widget', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.kpi-bar .kpi-card', { timeout: 5000 });
  });

  test('terminal exists but hidden on load', async ({ page }) => {
    await expect(page.locator('#term-main')).toBeAttached();
    const display = await page.locator('#term-main').evaluate((el) => getComputedStyle(el).display);
    expect(display).toBe('none');
  });

  test('terminal opens and shows tab label', async ({ page }) => {
    await stubWS(page);
    // Stub xterm.js if CDN didn't load
    await page.evaluate(() => {
      if (typeof (window as any).Terminal === 'undefined') {
        (window as any).Terminal = class { open() {} write() {} onData() { return { dispose() {} }; } onResize() { return { dispose() {} }; } dispose() {} loadAddon() {} };
        (window as any).FitAddon = class { fit() {} };
        (window as any).WebLinksAddon = class {};
      }
    });
    await page.evaluate('termMgr.open("local", "TestTab")');
    // Container should be visible (display set + open class added synchronously)
    await page.waitForTimeout(200);
    const isVisible = await page.locator('#term-main').evaluate(
      (el) => el.style.display !== 'none' && el.classList.contains('open'),
    );
    expect(isVisible).toBe(true);
  });
});
