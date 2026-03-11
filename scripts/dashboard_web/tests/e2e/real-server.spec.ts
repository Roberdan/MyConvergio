import { test, expect } from '@playwright/test';

/**
 * Tests against the REAL running server (no mocks).
 * Catches: API 500s, missing fields, JS crashes, widgets stuck on "Loading..."
 */

const API_ENDPOINTS = [
  '/api/overview',
  '/api/mission',
  '/api/tokens/daily',
  '/api/tokens/models',
  '/api/mesh',
  '/api/history',
  '/api/tasks/distribution',
  '/api/nightly/jobs',
  '/api/projects',
  '/api/events',
  '/api/coordinator/status',
  '/api/notifications',
  '/api/tasks/blocked',
  '/api/plans/assignable',
  '/api/agents',
  '/api/sessions',
  '/api/peers',
  '/api/mesh/sync-status',
];

test.describe('Real server integration', () => {
  test.skip(!!process.env.CI, 'Requires real server — skipped on CI');
  test('all API endpoints return 200', async ({ request }) => {
    const failures: string[] = [];
    for (const ep of API_ENDPOINTS) {
      const res = await request.get(ep);
      if (res.status() !== 200) {
        const body = await res.text();
        failures.push(`${ep} → ${res.status()}: ${body.slice(0, 120)}`);
      }
    }
    expect(failures, `Failing endpoints:\n${failures.join('\n')}`).toHaveLength(0);
  });

  test('no JS console errors on page load', async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', (err) => errors.push(err.message));
    page.on('console', (msg) => {
      const text = msg.text();
      const ignorableWsError = text.includes('/ws/brain') && text.includes('WebSocket connection');
      if (msg.type() === 'error' && !text.includes('cdn.jsdelivr') && !ignorableWsError) {
        errors.push(msg.text());
      }
    });
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);
    expect(errors, `JS errors:\n${errors.join('\n')}`).toHaveLength(0);
  });

  test('no widgets stuck on Loading...', async ({ page }) => {
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForSelector('#kpi-bar .kpi-card', { timeout: 10000 });
    const widgets = await page.$$eval('.widget-body, [id$="-content"]', (els) =>
      els
        .filter((el) => {
          const textIsLoading = el.textContent?.trim() === 'Loading...';
          if (!textIsLoading) return false;
          const section = el.closest('section');
          const hidden = section?.getAttribute('hidden') !== null || section?.style.display === 'none';
          return !hidden;
        })
        .map((el) => el.id || el.parentElement?.querySelector('.widget-title')?.textContent || 'unknown'),
    );
    expect(widgets, `Widgets still loading:\n${widgets.join('\n')}`).toHaveLength(0);
  });

  test('no failed network requests (4xx/5xx)', async ({ page }) => {
    const failures: string[] = [];
    page.on('response', (res) => {
      const url = res.url();
      if (url.includes('/api/') && res.status() >= 400) {
        failures.push(`${res.status()} ${url}`);
      }
    });
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(4000);
    expect(failures, `Failed requests:\n${failures.join('\n')}`).toHaveLength(0);
  });

  test('API response shapes match frontend expectations', async ({ request }) => {
    const issues: string[] = [];
    const check = (name: string, data: unknown, fields: string[]) => {
      if (!data || typeof data !== 'object') {
        issues.push(`${name}: not an object`);
        return;
      }
      for (const f of fields) {
        if (!(f in (data as Record<string, unknown>))) {
          issues.push(`${name}: missing field "${f}"`);
        }
      }
    };

    const overview = await (await request.get('/api/overview')).json();
    check('overview', overview, ['plans_total', 'plans_active', 'mesh_online', 'mesh_total', 'total_tokens']);

    const mission = await (await request.get('/api/mission')).json();
    check('mission', mission, ['plans']);
    if (Array.isArray(mission.plans) && mission.plans.length > 0) {
      check('mission.plans[0]', mission.plans[0], ['plan', 'waves', 'tasks']);
    }

    const mesh = await (await request.get('/api/mesh')).json();
    if (Array.isArray(mesh) && mesh.length > 0) {
      check('mesh[0]', mesh[0], ['peer_name', 'is_online', 'role', 'cpu', 'active_tasks']);
    }

    const nightly = await (await request.get('/api/nightly/jobs')).json();
    check('nightly', nightly, ['ok', 'history', 'definitions']);

    const peers = await (await request.get('/api/peers')).json();
    check('peers', peers, ['peers']);
    if (Array.isArray(peers.peers) && peers.peers.length > 0) {
      check('peers.peers[0]', peers.peers[0], ['peer_name', 'role', 'is_online']);
    }

    const agents = await (await request.get('/api/agents')).json();
    check('agents', agents, ['running', 'recent', 'stats']);

    expect(issues, `Schema issues:\n${issues.join('\n')}`).toHaveLength(0);
  });
});
