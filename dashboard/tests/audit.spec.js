// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Dashboard Audit - Debug', () => {
  test('diagnose network issues', async ({ page }) => {
    const failedRequests = [];
    const consoleErrors = [];

    // Capture failed network requests
    page.on('requestfailed', request => {
      failedRequests.push({
        url: request.url(),
        failure: request.failure()?.errorText || 'unknown'
      });
    });

    // Capture console errors
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    // Navigate without waiting for networkidle
    await page.goto('/', { waitUntil: 'domcontentloaded' });

    // Wait a bit for network activity
    await page.waitForTimeout(5000);

    // Capture page state
    const title = await page.title();
    const url = page.url();

    console.log('=== NETWORK DIAGNOSTIC ===');
    console.log(`Title: ${title}`);
    console.log(`URL: ${url}`);
    console.log(`Failed Requests (${failedRequests.length}):`);
    failedRequests.forEach(req => {
      console.log(`  - ${req.url}: ${req.failure}`);
    });
    console.log(`Console Errors (${consoleErrors.length}):`);
    consoleErrors.forEach(err => {
      console.log(`  - ${err}`);
    });

    // Take screenshot
    await page.screenshot({ path: 'test-results/audit-diagnostic.png', fullPage: true });

    // Check if basic elements loaded
    const navExists = await page.locator('.nav-menu').count();
    const gitPanelExists = await page.locator('.git-panel').count();
    const mainContentExists = await page.locator('.main-content').count();

    console.log('=== ELEMENT COUNTS ===');
    console.log(`Nav menu: ${navExists}`);
    console.log(`Git panel: ${gitPanelExists}`);
    console.log(`Main content: ${mainContentExists}`);

    expect(title).toBe('Convergio Dashboard');
  });

  test('accessibility scan', async ({ page }) => {
    // Navigate without networkidle
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(3000);

    // Check color contrast issues
    const lowContrastElements = await page.evaluate(() => {
      const issues = [];
      const elements = document.querySelectorAll('*');

      elements.forEach(el => {
        const style = window.getComputedStyle(el);
        const color = style.color;
        const bgColor = style.backgroundColor;

        // Skip if no text content
        if (!el.textContent || el.textContent.trim().length === 0) return;

        // Simple contrast check (this is a basic approximation)
        if (color && bgColor && color !== bgColor) {
          // Check if colors are too similar (basic check)
          if (color.includes('rgb') && bgColor.includes('rgb')) {
            const colorMatch = color.match(/\d+/g);
            const bgMatch = bgColor.match(/\d+/g);

            if (colorMatch && bgMatch) {
              const colorSum = colorMatch.reduce((a, b) => parseInt(a) + parseInt(b), 0);
              const bgSum = bgMatch.reduce((a, b) => parseInt(a) + parseInt(b), 0);

              // Very basic contrast check
              if (Math.abs(colorSum - bgSum) < 150) {
                issues.push({
                  element: el.tagName,
                  class: el.className,
                  color,
                  bgColor
                });
              }
            }
          }
        }
      });

      return issues;
    });

    console.log('=== POTENTIAL CONTRAST ISSUES ===');
    console.log(`Found ${lowContrastElements.length} potential issues`);
    lowContrastElements.slice(0, 10).forEach(issue => {
      console.log(`  ${issue.element}.${issue.class}: ${issue.color} on ${issue.bgColor}`);
    });

    // Check for missing alt attributes on images
    const imagesWithoutAlt = await page.evaluate(() => {
      const images = Array.from(document.querySelectorAll('img'));
      return images
        .filter(img => !img.alt || img.alt.trim() === '')
        .map(img => ({
          src: img.src,
          parent: img.parentElement?.tagName
        }));
    });

    console.log('=== IMAGES WITHOUT ALT TEXT ===');
    console.log(`Found ${imagesWithoutAlt.length} images without alt`);
    imagesWithoutAlt.forEach(img => {
      console.log(`  ${img.src} (parent: ${img.parent})`);
    });

    // Check for buttons without accessible names
    const inaccessibleButtons = await page.evaluate(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      return buttons
        .filter(btn => {
          const hasText = btn.textContent && btn.textContent.trim().length > 0;
          const hasAriaLabel = btn.getAttribute('aria-label');
          const hasTitle = btn.getAttribute('title');
          return !hasText && !hasAriaLabel && !hasTitle;
        })
        .map(btn => ({
          class: btn.className,
          id: btn.id,
          html: btn.innerHTML
        }));
    });

    console.log('=== BUTTONS WITHOUT ACCESSIBLE NAME ===');
    console.log(`Found ${inaccessibleButtons.length} inaccessible buttons`);
    inaccessibleButtons.forEach(btn => {
      console.log(`  ${btn.class || btn.id}: ${btn.html.substring(0, 50)}`);
    });
  });

  test('keyboard navigation', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2000);

    // Test tab navigation
    const focusableElements = await page.evaluate(() => {
      const selectors = 'a, button, input, select, textarea, [tabindex]:not([tabindex="-1"])';
      const elements = Array.from(document.querySelectorAll(selectors));
      return elements.map(el => ({
        tag: el.tagName,
        id: el.id,
        class: el.className,
        tabindex: el.getAttribute('tabindex')
      }));
    });

    console.log('=== KEYBOARD FOCUSABLE ELEMENTS ===');
    console.log(`Total focusable: ${focusableElements.length}`);

    // Check focus indicators
    const elementsMissingFocusStyle = await page.evaluate(() => {
      const elements = [];
      document.querySelectorAll('a, button').forEach(el => {
        el.focus();
        const style = window.getComputedStyle(el);
        const outline = style.outline;
        const boxShadow = style.boxShadow;

        // If no visible focus indicator
        if (outline === 'none' && boxShadow === 'none') {
          elements.push({
            tag: el.tagName,
            class: el.className
          });
        }
      });
      return elements;
    });

    console.log('=== ELEMENTS WITHOUT FOCUS INDICATOR ===');
    console.log(`Found ${elementsMissingFocusStyle.length} elements without visible focus`);
  });

  test('responsive breakpoints', async ({ page }) => {
    const breakpoints = [
      { name: 'Mobile S', width: 320, height: 568 },
      { name: 'Mobile M', width: 375, height: 667 },
      { name: 'Mobile L', width: 425, height: 812 },
      { name: 'Tablet', width: 768, height: 1024 },
      { name: 'Laptop', width: 1024, height: 768 },
      { name: 'Desktop', width: 1440, height: 900 }
    ];

    for (const bp of breakpoints) {
      await page.setViewportSize({ width: bp.width, height: bp.height });
      await page.goto('/', { waitUntil: 'domcontentloaded' });
      await page.waitForTimeout(1000);

      // Check if layout adapts
      const isNavVisible = await page.locator('.nav-menu').isVisible().catch(() => false);
      const isGitPanelVisible = await page.locator('.git-panel').isVisible().catch(() => false);
      const isRightPanelVisible = await page.locator('.right-panel').isVisible().catch(() => false);

      console.log(`=== ${bp.name} (${bp.width}x${bp.height}) ===`);
      console.log(`  Nav visible: ${isNavVisible}`);
      console.log(`  Git panel visible: ${isGitPanelVisible}`);
      console.log(`  Right panel visible: ${isRightPanelVisible}`);

      await page.screenshot({
        path: `test-results/responsive-${bp.name.toLowerCase().replace(' ', '-')}.png`
      });
    }
  });

  test('performance metrics', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(3000);

    const metrics = await page.evaluate(() => {
      const perfData = window.performance.timing;
      const navigationStart = perfData.navigationStart;

      return {
        pageLoadTime: perfData.loadEventEnd - navigationStart,
        domReady: perfData.domContentLoadedEventEnd - navigationStart,
        responseTime: perfData.responseEnd - perfData.requestStart,
        renderTime: perfData.domComplete - perfData.domLoading
      };
    });

    console.log('=== PERFORMANCE METRICS ===');
    console.log(`Page Load Time: ${metrics.pageLoadTime}ms`);
    console.log(`DOM Ready: ${metrics.domReady}ms`);
    console.log(`Response Time: ${metrics.responseTime}ms`);
    console.log(`Render Time: ${metrics.renderTime}ms`);

    // Check resource count
    const resourceCount = await page.evaluate(() => {
      const resources = performance.getEntriesByType('resource');
      const byType = {};
      resources.forEach(r => {
        const type = r.initiatorType || 'other';
        byType[type] = (byType[type] || 0) + 1;
      });
      return { total: resources.length, byType };
    });

    console.log('=== RESOURCES LOADED ===');
    console.log(`Total: ${resourceCount.total}`);
    Object.entries(resourceCount.byType).forEach(([type, count]) => {
      console.log(`  ${type}: ${count}`);
    });
  });
});
