const { test, expect } = require('@playwright/test');

test('capture dashboard state', async ({ page }) => {
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  
  // Wait a bit for data to load
  await page.waitForTimeout(2000);
  
  // Take full page screenshot
  await page.screenshot({ path: 'test-results/dashboard-state.png', fullPage: true });
  
  // Check for console errors
  const errors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  
  // Output nav counts
  const kanbanCount = await page.locator('#navKanbanCount').textContent();
  const wavesCount = await page.locator('#navWavesCount').textContent();
  const issuesCount = await page.locator('#navIssuesCount').textContent();
  
  console.log('Nav counts:', { kanbanCount, wavesCount, issuesCount });
  
  // Verify data is loaded
  await expect(page.locator('#navWavesCount')).not.toBeEmpty({ timeout: 10000 });
});
