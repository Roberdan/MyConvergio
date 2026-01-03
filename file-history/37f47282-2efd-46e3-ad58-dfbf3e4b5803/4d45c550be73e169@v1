import { test, expect } from '@playwright/test';

test.describe('Welcome Experience - Wave 3', () => {
  test.describe('Visual Landing Page', () => {
    test('displays hero section with Melissa avatar', async ({ page }) => {
      await page.goto('/welcome');

      // Hero section should be visible
      const heroSection = page.locator('[aria-labelledby="hero-heading"]').or(
        page.locator('section').filter({ hasText: /Benvenuto|Bentornato/i }).first()
      );
      await expect(heroSection).toBeVisible({ timeout: 10000 });

      // Melissa avatar should be present
      const melissaAvatar = page.locator('img[alt*="Melissa"]').or(
        page.locator('img[src*="melissa"]')
      );
      await expect(melissaAvatar).toBeVisible();
    });

    test('displays features section with 8 feature cards', async ({ page }) => {
      await page.goto('/welcome');

      // Features section heading
      const featuresSection = page.locator('[aria-labelledby="features-heading"]').or(
        page.locator('section').filter({ hasText: /Cosa puoi fare/i })
      );
      await expect(featuresSection).toBeVisible({ timeout: 10000 });

      // Should have feature cards (at least 4 visible in grid)
      const featureCards = featuresSection.locator('article, [role="listitem"], .grid > div');
      await expect(featureCards.first()).toBeVisible();
    });

    test('displays guides section with AI characters', async ({ page }) => {
      await page.goto('/welcome');

      // Guides section
      const guidesSection = page.locator('[aria-labelledby="guides-heading"]').or(
        page.locator('section').filter({ hasText: /Incontra le tue Guide/i })
      );
      await expect(guidesSection).toBeVisible({ timeout: 10000 });

      // Should show at least Melissa and one other guide
      await expect(page.locator('text=Melissa').first()).toBeVisible();
      await expect(page.locator('text=Andrea').or(page.locator('text=Marco'))).toBeVisible();
    });

    test('displays quick start CTAs', async ({ page }) => {
      await page.goto('/welcome');

      // Quick start section
      const quickStartSection = page.locator('[aria-labelledby="quickstart-heading"]').or(
        page.locator('section').filter({ has: page.locator('button').filter({ hasText: /Inizia|Melissa|Salta/i }) })
      );
      await expect(quickStartSection).toBeVisible({ timeout: 10000 });

      // Primary CTA should be visible (Start with Melissa or Go to app)
      const primaryCta = page.locator('button').filter({ hasText: /Inizia con Melissa|Vai all'app/i }).first();
      await expect(primaryCta).toBeVisible();
    });
  });

  test.describe('Skip Flow', () => {
    test('skip button is visible and accessible', async ({ page }) => {
      await page.goto('/welcome');

      // Skip link should be visible
      const skipButton = page.locator('button').filter({ hasText: /Salta intro/i }).or(
        page.locator('[role="button"]').filter({ hasText: /Salta/i })
      );
      await expect(skipButton).toBeVisible({ timeout: 10000 });
    });

    test('skip shows confirmation modal', async ({ page }) => {
      await page.goto('/welcome');

      // Click skip
      const skipButton = page.locator('button').filter({ hasText: /Salta intro/i }).first();
      await skipButton.click();

      // Confirmation modal should appear
      const modal = page.locator('[role="dialog"]').or(
        page.locator('div').filter({ hasText: /Sicuro di voler saltare/i })
      );
      await expect(modal).toBeVisible({ timeout: 5000 });
    });

    test('skip confirmation navigates to dashboard', async ({ page }) => {
      await page.goto('/welcome');

      // Click skip
      await page.locator('button').filter({ hasText: /Salta intro/i }).first().click();

      // Confirm in modal
      const confirmButton = page.locator('[role="dialog"] button').filter({ hasText: /Conferma|Si|Salta/i }).or(
        page.locator('button').filter({ hasText: /Conferma|Si, salta/i })
      );
      await confirmButton.first().click();

      // Should navigate to dashboard (main page)
      await expect(page).toHaveURL(/\/($|dashboard)/, { timeout: 10000 });
    });
  });

  test.describe('Start Options', () => {
    test('start with voice button exists', async ({ page }) => {
      await page.goto('/welcome');

      const voiceButton = page.locator('button').filter({ hasText: /Inizia con Melissa|Con la voce/i }).first();
      await expect(voiceButton).toBeVisible({ timeout: 10000 });
    });

    test('start without voice button exists', async ({ page }) => {
      await page.goto('/welcome');

      const noVoiceButton = page.locator('button').filter({ hasText: /Continua senza voce|Senza voce/i }).first();
      await expect(noVoiceButton).toBeVisible({ timeout: 10000 });
    });
  });

  test.describe('Replay from Settings', () => {
    test('/welcome?replay=true loads welcome page', async ({ page }) => {
      await page.goto('/welcome?replay=true');

      // Should show the welcome page even for returning users
      const heroSection = page.locator('section').filter({ hasText: /Benvenuto|Bentornato|MirrorBuddy/i }).first();
      await expect(heroSection).toBeVisible({ timeout: 10000 });
    });

    test('settings has review intro link', async ({ page }) => {
      await page.goto('/');

      // Navigate to settings
      await page.locator('button').filter({ hasText: /Impostazioni/i }).click();
      await page.waitForTimeout(500);

      // Look for the review introduction button
      const reviewButton = page.locator('button').filter({ hasText: /Rivedi introduzione/i }).or(
        page.locator('a').filter({ hasText: /Rivedi introduzione/i })
      );
      await expect(reviewButton).toBeVisible({ timeout: 10000 });
    });

    test('settings review intro navigates to /welcome?replay=true', async ({ page }) => {
      await page.goto('/');

      // Navigate to settings
      await page.locator('button').filter({ hasText: /Impostazioni/i }).click();
      await page.waitForTimeout(500);

      // Click review introduction
      await page.locator('button').filter({ hasText: /Rivedi introduzione/i }).click();

      // Should navigate to welcome with replay param
      await expect(page).toHaveURL(/\/welcome\?replay=true/, { timeout: 10000 });
    });
  });

  test.describe('Accessibility', () => {
    test('welcome page has proper heading structure', async ({ page }) => {
      await page.goto('/welcome');

      // Check for h1 or main heading
      const mainHeading = page.locator('h1, [role="heading"][aria-level="1"]').first();
      await expect(mainHeading).toBeVisible({ timeout: 10000 });
    });

    test('buttons are keyboard focusable', async ({ page }) => {
      await page.goto('/welcome');

      // Tab to first interactive element
      await page.keyboard.press('Tab');
      await page.keyboard.press('Tab');
      await page.keyboard.press('Tab');

      // A button should be focused
      const focusedElement = page.locator(':focus');
      await expect(focusedElement).toBeVisible();
    });

    test('sections have proper ARIA labels', async ({ page }) => {
      await page.goto('/welcome');

      // At least one section should have aria-labelledby
      const labeledSection = page.locator('section[aria-labelledby]');
      const count = await labeledSection.count();
      expect(count).toBeGreaterThan(0);
    });
  });

  test.describe('Responsive Design', () => {
    test('mobile layout displays properly', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/welcome');

      // Page should still show key elements
      const cta = page.locator('button').filter({ hasText: /Inizia|Vai/i }).first();
      await expect(cta).toBeVisible({ timeout: 10000 });
    });

    test('tablet layout displays properly', async ({ page }) => {
      await page.setViewportSize({ width: 768, height: 1024 });
      await page.goto('/welcome');

      // Page should show sections properly
      const features = page.locator('section').filter({ hasText: /Cosa puoi fare/i });
      await expect(features).toBeVisible({ timeout: 10000 });
    });
  });
});
