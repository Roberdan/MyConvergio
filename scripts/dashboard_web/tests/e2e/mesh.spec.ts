import { test, expect } from './fixtures';

test.describe('Mesh Network', () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto('/');
    await page.waitForSelector('.mesh-node', { timeout: 5000 });
  });

  test('renders all mesh nodes', async ({ page }) => {
    const nodes = page.locator('.mesh-node');
    await expect(nodes).toHaveCount(3);
  });

  test('online nodes have .online class', async ({ page }) => {
    await expect(page.locator('.mesh-node.online')).toHaveCount(2);
    await expect(page.locator('.mesh-node.offline')).toHaveCount(1);
  });

  test('coordinator node has .coordinator class', async ({ page }) => {
    await expect(page.locator('.mesh-node.coordinator')).toHaveCount(1);
    const coord = page.locator('.mesh-node.coordinator');
    await expect(coord).toContainText('m3max');
    await expect(coord).toContainText('COORDINATOR');
  });

  test('node names are displayed', async ({ page }) => {
    const names = await page.locator('.mn-name').allTextContents();
    expect(names).toEqual(expect.arrayContaining(['omarchy', 'm1mario', 'm3max']));
  });

  test('online nodes show CPU stats', async ({ page }) => {
    const onlineNode = page.locator('.mesh-node.online', { hasText: 'omarchy' });
    await expect(onlineNode.locator('.mn-stats')).toContainText('CPU 72%');
  });

  test('offline node shows "No heartbeat"', async ({ page }) => {
    const offNode = page.locator('.mesh-node.offline');
    await expect(offNode.locator('.mn-stats')).toContainText('No heartbeat');
  });

  test('online nodes show action buttons', async ({ page }) => {
    const onlineNode = page.locator('.mesh-node.online', { hasText: 'omarchy' });
    const actions = onlineNode.locator('.mn-act-btn');
    // terminal, sync, heartbeat, auth, status, movehere, reboot = 7
    await expect(actions).toHaveCount(7);
  });

  test('offline nodes show wake button only', async ({ page }) => {
    const offNode = page.locator('.mesh-node.offline');
    const actions = offNode.locator('.mn-act-btn');
    await expect(actions).toHaveCount(1);
    await expect(actions.first()).toHaveAttribute('data-action', 'wake');
  });

  test('capabilities are shown as badges', async ({ page }) => {
    const coord = page.locator('.mesh-node.coordinator');
    await expect(coord.locator('.mn-cap')).toHaveCount(3);
    await expect(coord.locator('.mn-cap', { hasText: 'ollama' })).toHaveClass(/accent/);
  });

  test('mesh header shows online count and action buttons', async ({ page }) => {
    await expect(page.locator('#mesh-online-count')).toContainText('2/3 online');
    await expect(page.locator('.mesh-toolbar-btn[title="Full Sync"]')).toBeVisible();
    await expect(page.locator('.mesh-toolbar-btn[title="Push"]')).toBeVisible();
  });

  test('coordinator node shows active plan', async ({ page }) => {
    const coord = page.locator('.mesh-node.coordinator');
    await expect(coord.locator('.mn-plan')).toHaveCount(1);
    await expect(coord.locator('.mn-plan')).toContainText('#300');
    await expect(coord.locator('.mn-plan')).toContainText('Auth refactor');
  });

  test('hub layout with spokes container exists', async ({ page }) => {
    await expect(page.locator('.mesh-hub')).toBeVisible();
    await expect(page.locator('.mesh-hub-coord')).toBeVisible();
    await expect(page.locator('#mesh-flow-cvs')).toBeVisible();
  });

  test('sync badges are applied after load', async ({ page }) => {
    await page.waitForSelector('.mesh-node.coordinator .mn-sync-dot', { timeout: 5000 });
    // m3max should have green sync dot
    const coord = page.locator('.mesh-node.coordinator');
    await expect(coord.locator('.mn-sync-green')).toHaveCount(1);
    // omarchy should have yellow (out of sync)
    const omarchy = page.locator('.mesh-node', { hasText: 'omarchy' });
    await expect(omarchy.locator('.mn-sync-yellow')).toHaveCount(1);
  });

  test('terminal action button triggers terminal open', async ({ page }) => {
    // Stub WebSocket
    await page.evaluate(() => {
      (window as any).WebSocket = class FakeWS {
        readyState = 3; binaryType = 'arraybuffer';
        onopen: any; onclose: any; onerror: any; onmessage: any;
        send() {} close() {}
        constructor() { setTimeout(() => { this.onerror?.(); this.onclose?.(); }, 50); }
      };
    });

    const termBtn = page.locator('.mesh-node.online', { hasText: 'omarchy' })
      .locator('.mn-act-btn[data-action="terminal"]');
    await termBtn.click();

    await page.waitForSelector('#term-main.open', { timeout: 3000 });
    await expect(page.locator('.term-tab')).toContainText('omarchy');
  });
});
