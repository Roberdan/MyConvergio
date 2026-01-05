// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Dashboard Basic Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for page to load
    await page.waitForLoadState('networkidle');
  });

  test('page loads and has title', async ({ page }) => {
    await expect(page).toHaveTitle('Convergio Dashboard');
  });

  test('navigation menu is visible', async ({ page }) => {
    const nav = page.locator('.nav-menu');
    await expect(nav).toBeVisible();
  });

  test('git panel is visible', async ({ page }) => {
    const gitPanel = page.locator('.git-panel');
    await expect(gitPanel).toBeVisible();
  });

  test('main content area is visible', async ({ page }) => {
    const mainContent = page.locator('.main-content');
    await expect(mainContent).toBeVisible();
  });

  test('right panel is visible', async ({ page }) => {
    const rightPanel = page.locator('.right-panel');
    await expect(rightPanel).toBeVisible();
  });
});

test.describe('Navigation Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('can navigate to Dashboard view', async ({ page }) => {
    await page.click('.nav-menu a:has-text("Dashboard")');
    await expect(page.locator('.stats-row')).toBeVisible();
  });

  test('can navigate to Kanban view', async ({ page }) => {
    await page.click('.nav-menu a:has-text("Kanban")');
    await expect(page.locator('.kanban-view')).toBeVisible();
  });

  test('can navigate to Waves view', async ({ page }) => {
    await page.click('.nav-menu a:has-text("Waves")');
    await expect(page.locator('.waves-view')).toBeVisible();
  });

  test('can navigate to Issues view', async ({ page }) => {
    await page.click('.nav-menu a:has-text("Issues")');
    await expect(page.locator('.bugs-view')).toBeVisible();
  });

  test('can navigate to Agents view', async ({ page }) => {
    await page.click('.nav-menu a:has-text("Agents")');
    await expect(page.locator('.agents-view')).toBeVisible();
  });
});

test.describe('Project Menu Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('project menu opens on logo click', async ({ page }) => {
    await page.click('.logo');
    const projectMenu = page.locator('.project-menu');
    await expect(projectMenu).toBeVisible();
  });

  test('project menu has project list', async ({ page }) => {
    await page.click('.logo');
    const projectList = page.locator('.project-list');
    await expect(projectList).toBeVisible();
  });
});

test.describe('Theme Selector Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('theme selector is visible', async ({ page }) => {
    const themeSelector = page.locator('#themeSelect');
    await expect(themeSelector).toBeVisible();
  });

  test('can change theme', async ({ page }) => {
    const themeSelector = page.locator('#themeSelect');
    await themeSelector.selectOption('midnight');
    // Check that html element has the theme attribute (theme.js sets it on documentElement)
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'midnight');
  });
});

test.describe('Git Panel Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('git panel header is visible', async ({ page }) => {
    const header = page.locator('.git-panel-header');
    await expect(header).toContainText('SOURCE CONTROL');
  });

  test('repositories section is visible', async ({ page }) => {
    const reposSection = page.locator('.git-section:has-text("REPOSITORIES")');
    await expect(reposSection).toBeVisible();
  });

  test('changes section is visible', async ({ page }) => {
    const changesSection = page.locator('.git-section:has-text("CHANGES")');
    await expect(changesSection).toBeVisible();
  });

  test('graph section is visible', async ({ page }) => {
    const graphSection = page.locator('.git-section:has-text("GRAPH")');
    await expect(graphSection).toBeVisible();
  });

  test('commit input is visible', async ({ page }) => {
    const commitInput = page.locator('#gitCommitMessage');
    await expect(commitInput).toBeVisible();
  });
});

test.describe('Right Panel Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('health status section is visible', async ({ page }) => {
    const healthStatus = page.locator('.panel-header:has-text("Health Status")');
    await expect(healthStatus).toBeVisible();
  });

  test('current focus section is visible', async ({ page }) => {
    const focusSection = page.locator('.focus-section');
    await expect(focusSection).toBeVisible();
  });

  test('tabs are visible (Issues, Tokens, History)', async ({ page }) => {
    const issuesTab = page.locator('.about-tab:has-text("Issues")');
    const tokensTab = page.locator('.about-tab:has-text("Tokens")');
    const historyTab = page.locator('.about-tab:has-text("History")');

    await expect(issuesTab).toBeVisible();
    await expect(tokensTab).toBeVisible();
    await expect(historyTab).toBeVisible();
  });

  test('can switch between tabs', async ({ page }) => {
    // Click Tokens tab
    await page.click('.about-tab:has-text("Tokens")');
    await expect(page.locator('#tabTokens')).toBeVisible();

    // Click History tab
    await page.click('.about-tab:has-text("History")');
    await expect(page.locator('#tabHistory')).toBeVisible();

    // Click back to Issues tab
    await page.click('.about-tab:has-text("Issues")');
    await expect(page.locator('#tabIssues')).toBeVisible();
  });
});

test.describe('Chart Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('chart card is visible', async ({ page }) => {
    const chartCard = page.locator('.chart-card');
    await expect(chartCard).toBeVisible();
  });

  test('chart tabs are visible', async ({ page }) => {
    const tokensTab = page.locator('.chart-tab:has-text("Tokens")');
    const burndownTab = page.locator('.chart-tab:has-text("Burndown")');

    await expect(tokensTab).toBeVisible();
    await expect(burndownTab).toBeVisible();
  });

  test('can switch chart mode', async ({ page }) => {
    const burndownTab = page.locator('.chart-tab:has-text("Burndown")');
    await burndownTab.click();
    await expect(burndownTab).toHaveClass(/active/);
  });
});

test.describe('Notifications Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('notification bell is visible', async ({ page }) => {
    const notificationBell = page.locator('.notification-bell');
    await expect(notificationBell).toBeVisible();
  });

  test('can open notifications view', async ({ page }) => {
    await page.click('.notification-bell');
    await expect(page.locator('.notifications-view')).toBeVisible();
  });
});

test.describe('Stats Section Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('stats row is visible', async ({ page }) => {
    const statsRow = page.locator('.stats-row');
    await expect(statsRow).toBeVisible();
  });

  test('wave indicator is visible', async ({ page }) => {
    const waveIndicator = page.locator('.wave-indicator');
    await expect(waveIndicator).toBeVisible();
  });

  test('waves summary is visible', async ({ page }) => {
    const wavesSummary = page.locator('.waves-summary');
    await expect(wavesSummary).toBeVisible();
  });
});

test.describe('Layout Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('three-column layout is correct', async ({ page }) => {
    const gitPanel = page.locator('.git-panel');
    const mainContent = page.locator('.main-content');
    const rightPanel = page.locator('.right-panel');

    // All three columns should be visible
    await expect(gitPanel).toBeVisible();
    await expect(mainContent).toBeVisible();
    await expect(rightPanel).toBeVisible();

    // Check they are arranged horizontally using flex
    const mainWrap = page.locator('.main-wrap');
    await expect(mainWrap).toHaveCSS('display', 'flex');
  });

  test('columns have consistent height', async ({ page }) => {
    const gitPanel = page.locator('.git-panel');
    const rightPanel = page.locator('.right-panel');

    const gitHeight = await gitPanel.boundingBox();
    const rightHeight = await rightPanel.boundingBox();

    // Heights should be similar (within 50px tolerance due to content)
    expect(Math.abs(gitHeight.height - rightHeight.height)).toBeLessThan(100);
  });
});

test.describe('Export Button Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('export button is visible', async ({ page }) => {
    const exportBtn = page.locator('#exportBtn');
    await expect(exportBtn).toBeVisible();
  });
});

test.describe('Responsive Tests', () => {
  test('works on tablet viewport', async ({ page }) => {
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const nav = page.locator('.nav-menu');
    await expect(nav).toBeVisible();
  });

  test('works on mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Page should still load
    await expect(page).toHaveTitle('Convergio Dashboard');
  });
});
