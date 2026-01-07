const { test, expect } = require('@playwright/test');

test('click plan card should load plan and show dashboard', async ({ page }) => {
  page.on('console', msg => {
    if (msg.type() === 'error') {
      console.log('Browser error:', msg.text());
    }
  });

  await page.goto('http://localhost:31415');
  await page.waitForSelector('.cc-plan-card', { timeout: 10000 });
  
  const cards = await page.locator('.cc-plan-card').all();
  console.log(`Found ${cards.length} plan cards`);
  
  // Click the first plan card
  await cards[0].click();
  await page.waitForTimeout(3000);
  
  // Check toast messages
  const toasts = await page.locator('.toast').all();
  for (const toast of toasts) {
    const text = await toast.textContent();
    console.log('Toast:', text.replace(/\s+/g, ' ').trim().substring(0, 80));
  }
  
  // Check if kanban is hidden (should be after switching to dashboard)
  const kanbanDisplay = await page.locator('#kanbanView').evaluate(e => e.style.display);
  console.log('kanbanView display:', kanbanDisplay);
  
  // Check if main-content is visible
  const mainContent = await page.locator('.main-content').evaluate(e => ({
    display: window.getComputedStyle(e).display,
    visibility: window.getComputedStyle(e).visibility
  }));
  console.log('main-content:', mainContent);
  
  // Check stats header visibility
  const statsHeader = await page.locator('.stats-header').evaluate(e => e.style.display).catch(() => 'not found');
  console.log('stats-header display:', statsHeader);
  
  // Check interactive-gantt visibility
  const gantt = await page.locator('.interactive-gantt').evaluate(e => ({
    display: window.getComputedStyle(e).display,
    id: e.id
  })).catch(() => ({ display: 'not found' }));
  console.log('interactive-gantt:', gantt);

  // Check currentView variable in browser
  const currentView = await page.evaluate(() => window.currentView);
  console.log('currentView:', currentView);
  
  // Check if project was loaded
  const projectId = await page.evaluate(() => window.currentProjectId);
  console.log('currentProjectId:', projectId);
  
  // Take screenshot
  await page.screenshot({ path: 'tests/screenshot-after-click.png' });
  console.log('Screenshot saved to tests/screenshot-after-click.png');
});
