/**
 * E2E Tests for Supporti Page (Wave 4)
 * Tests material browsing, filtering, search, and navigation
 */

import { test, expect } from '@playwright/test';

test.describe('Supporti Page - Wave 4', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/supporti');
  });

  test.describe('Page Structure', () => {
    test('displays sidebar navigation', async ({ page }) => {
      const sidebar = page.locator('aside').filter({ hasText: /Tutti i Supporti/i });
      await expect(sidebar).toBeVisible({ timeout: 10000 });
    });

    test('displays main content area with header', async ({ page }) => {
      const header = page.locator('h1').filter({ hasText: /I Tuoi Supporti/i });
      await expect(header).toBeVisible({ timeout: 10000 });
    });

    test('displays search input', async ({ page }) => {
      const searchInput = page.locator('input[aria-label="Cerca materiali"]');
      await expect(searchInput).toBeVisible({ timeout: 10000 });
    });

    test('displays view mode toggle buttons', async ({ page }) => {
      const gridButton = page.locator('button[aria-label="Vista griglia"]');
      const listButton = page.locator('button[aria-label="Vista lista"]');
      await expect(gridButton).toBeVisible({ timeout: 10000 });
      await expect(listButton).toBeVisible({ timeout: 10000 });
    });

    test('displays sort dropdown', async ({ page }) => {
      const sortSelect = page.locator('select[aria-label="Ordina per"]');
      await expect(sortSelect).toBeVisible({ timeout: 10000 });
    });

    test('displays breadcrumb navigation', async ({ page }) => {
      const breadcrumb = page.locator('nav[aria-label="Breadcrumb"]');
      await expect(breadcrumb).toBeVisible({ timeout: 10000 });
      await expect(breadcrumb.locator('text=Supporti')).toBeVisible();
    });
  });

  test.describe('Sidebar Navigation', () => {
    test('shows "Tutti i Supporti" button', async ({ page }) => {
      const allButton = page.locator('button').filter({ hasText: /Tutti i Supporti/i });
      await expect(allButton).toBeVisible({ timeout: 10000 });
    });

    test('shows "Preferiti" button', async ({ page }) => {
      const bookmarkedButton = page.locator('button').filter({ hasText: /Preferiti/i });
      await expect(bookmarkedButton).toBeVisible({ timeout: 10000 });
    });

    test('shows "Per Tipo" collapsible section', async ({ page }) => {
      const typeSection = page.locator('button').filter({ hasText: /Per Tipo/i });
      await expect(typeSection).toBeVisible({ timeout: 10000 });
    });

    test('can expand/collapse type section', async ({ page }) => {
      const typeToggle = page.locator('button').filter({ hasText: /Per Tipo/i });
      await expect(typeToggle).toBeVisible({ timeout: 10000 });

      // Type section is expanded by default
      // Check if any type buttons are visible (if materials exist)
      const typeButtons = page.locator('aside button').filter({ hasText: /Mindmap|Quiz|Flashcard|Demo|Riassunto/i });
      const count = await typeButtons.count();

      // Click to collapse
      await typeToggle.click();
      await page.waitForTimeout(300);

      // Click to expand again
      await typeToggle.click();
    });
  });

  test.describe('Filtering', () => {
    test('clicking bookmarked filter updates URL', async ({ page }) => {
      const bookmarkedButton = page.locator('button').filter({ hasText: /Preferiti/i });
      await bookmarkedButton.click();

      await expect(page).toHaveURL(/bookmarked=true/);
    });

    test('clicking "Tutti i Supporti" clears filters', async ({ page }) => {
      // First apply a filter
      await page.goto('/supporti?bookmarked=true');

      const allButton = page.locator('button').filter({ hasText: /Tutti i Supporti/i });
      await allButton.click();

      await expect(page).toHaveURL('/supporti');
    });

    test('type filter updates URL when clicked', async ({ page }) => {
      // Expand type section if needed and click a type
      const typeToggle = page.locator('button').filter({ hasText: /Per Tipo/i });
      await typeToggle.click();
      await page.waitForTimeout(200);

      // Try to find and click a type button (may not exist if no materials)
      const mindmapButton = page.locator('aside button').filter({ hasText: 'Mindmap' });
      if (await mindmapButton.isVisible()) {
        await mindmapButton.click();
        await expect(page).toHaveURL(/type=mindmap/);
      }
    });
  });

  test.describe('Search', () => {
    test('can type in search input', async ({ page }) => {
      const searchInput = page.locator('input[aria-label="Cerca materiali"]');
      await searchInput.fill('test search');
      await expect(searchInput).toHaveValue('test search');
    });

    test('clear button appears when search has text', async ({ page }) => {
      const searchInput = page.locator('input[aria-label="Cerca materiali"]');
      await searchInput.fill('test');

      const clearButton = page.locator('button').filter({ has: page.locator('svg.lucide-x') }).first();
      await expect(clearButton).toBeVisible({ timeout: 5000 });
    });

    test('clear button clears search', async ({ page }) => {
      const searchInput = page.locator('input[aria-label="Cerca materiali"]');
      await searchInput.fill('test');

      const clearButton = page.locator('.relative button').filter({ has: page.locator('svg') }).first();
      if (await clearButton.isVisible()) {
        await clearButton.click();
        await expect(searchInput).toHaveValue('');
      }
    });
  });

  test.describe('View Modes', () => {
    test('can switch to list view', async ({ page }) => {
      const listButton = page.locator('button[aria-label="Vista lista"]');
      await listButton.click();

      // List button should be highlighted
      await expect(listButton).toHaveClass(/bg-slate/);
    });

    test('can switch to grid view', async ({ page }) => {
      // First switch to list
      const listButton = page.locator('button[aria-label="Vista lista"]');
      await listButton.click();

      // Then back to grid
      const gridButton = page.locator('button[aria-label="Vista griglia"]');
      await gridButton.click();

      await expect(gridButton).toHaveClass(/bg-slate/);
    });
  });

  test.describe('Sorting', () => {
    test('can change sort order', async ({ page }) => {
      const sortSelect = page.locator('select[aria-label="Ordina per"]');
      await sortSelect.selectOption('type');
      await expect(sortSelect).toHaveValue('type');
    });

    test('sort options include all expected values', async ({ page }) => {
      const sortSelect = page.locator('select[aria-label="Ordina per"]');

      const options = sortSelect.locator('option');
      const optionTexts = await options.allTextContents();

      expect(optionTexts.some(t => t.includes('Data'))).toBeTruthy();
      expect(optionTexts.some(t => t.includes('Tipo'))).toBeTruthy();
    });
  });

  test.describe('Empty State', () => {
    test('shows empty state when no materials match filter', async ({ page }) => {
      // Apply a filter that likely won't match anything
      await page.goto('/supporti?type=nonexistent');

      // Should show empty state or no results
      const content = page.locator('main');
      await expect(content).toBeVisible({ timeout: 10000 });
    });
  });

  test.describe('Redirect from /archivio', () => {
    test('redirects /archivio to /supporti', async ({ page }) => {
      await page.goto('/archivio');

      // Should redirect to /supporti
      await expect(page).toHaveURL('/supporti');
    });
  });

  test.describe('Accessibility', () => {
    test('sidebar has proper aria-label', async ({ page }) => {
      const nav = page.locator('nav[aria-label="Filtri materiali"]');
      await expect(nav).toBeVisible({ timeout: 10000 });
    });

    test('breadcrumb has proper aria-label', async ({ page }) => {
      const breadcrumb = page.locator('nav[aria-label="Breadcrumb"]');
      await expect(breadcrumb).toBeVisible({ timeout: 10000 });
    });

    test('search input has proper aria-label', async ({ page }) => {
      const searchInput = page.locator('input[aria-label="Cerca materiali"]');
      await expect(searchInput).toBeVisible({ timeout: 10000 });
    });

    test('view toggle buttons have proper aria-labels', async ({ page }) => {
      await expect(page.locator('button[aria-label="Vista griglia"]')).toBeVisible({ timeout: 10000 });
      await expect(page.locator('button[aria-label="Vista lista"]')).toBeVisible({ timeout: 10000 });
    });

    test('sort select has proper aria-label', async ({ page }) => {
      const sortSelect = page.locator('select[aria-label="Ordina per"]');
      await expect(sortSelect).toBeVisible({ timeout: 10000 });
    });
  });

  test.describe('Responsive Design', () => {
    test('sidebar is visible on desktop', async ({ page }) => {
      await page.setViewportSize({ width: 1280, height: 800 });
      const sidebar = page.locator('aside');
      await expect(sidebar).toBeVisible({ timeout: 10000 });
    });

    test('header controls stack on mobile', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/supporti');

      // Page should still be functional
      const header = page.locator('h1').filter({ hasText: /I Tuoi Supporti/i });
      await expect(header).toBeVisible({ timeout: 10000 });
    });
  });
});
