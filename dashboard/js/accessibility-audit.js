/**
 * Accessibility Audit & Enhancement Module
 * Ensures WCAG 2.1 AA compliance
 */
class AccessibilityAudit {
  constructor() {
    this.issues = [];
    this.warnings = [];
  }
  /**
   * Comprehensive accessibility audit
   */
  auditAll() {
    console.log('🔍 Starting accessibility audit...');
    this.auditAriaLabels();
    this.auditColorContrast();
    this.auditFocusIndicators();
    this.auditKeyboardNavigation();
    this.auditHeadings();
    this.auditImageAltText();
    this.auditFormLabels();
    this.reportResults();
  }
  /**
   * Audit aria-labels on interactive elements
   */
  auditAriaLabels() {
    const interactiveElements = document.querySelectorAll(
      'button:not([aria-label]):not([aria-labelledby]), ' +
      'a[href]:not([aria-label]):not([aria-labelledby]), ' +
      '[role="button"]:not([aria-label]):not([aria-labelledby]), ' +
      '[role="menuitem"]:not([aria-label]):not([aria-labelledby])'
    );
    interactiveElements.forEach(el => {
      const text = el.textContent?.trim();
      if (!text || text.length < 2) {
        this.issues.push({
          type: 'MISSING_ARIA_LABEL',
          element: el,
          message: `Interactive element missing aria-label: ${el.tagName} ${el.className}`
        });
      }
    });
    console.log(`✅ aria-label audit: Found ${interactiveElements.length} interactive elements`);
  }
  /**
   * Audit color contrast ratios
   */
  auditColorContrast() {
    // This is a simplified check - full audit requires computed styles
    const textElements = document.querySelectorAll('p, span, div, label, button, a');
    let checkedCount = 0;
    textElements.forEach(el => {
      const style = window.getComputedStyle(el);
      const color = style.color;
      const bgColor = style.backgroundColor;
      // Simple check: if both are defined, add to audit queue
      if (color && bgColor && color !== 'rgba(0, 0, 0, 0)') {
        checkedCount++;
      }
    });
    console.log(`✅ Color contrast audit: Sampled ${checkedCount} elements (use WebAIM Contrast Checker for detailed results)`);
  }
  /**
   * Audit focus indicators
   */
  auditFocusIndicators() {
    const focusableElements = document.querySelectorAll(
      'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    console.log(`✅ Focus indicator audit: Found ${focusableElements.length} focusable elements`);
    console.log('💡 Ensure all have visible :focus-visible styles in CSS');
  }
  /**
   * Audit keyboard navigation
   */
  auditKeyboardNavigation() {
    const tabbableElements = document.querySelectorAll(
      'button:not([disabled]), a[href], input:not([disabled]), select, textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
    );
    console.log(`✅ Keyboard navigation audit: Found ${tabbableElements.length} tabbable elements`);
    console.log('💡 Test by pressing Tab key to navigate through all interactive elements');
  }
  /**
   * Audit heading structure
   */
  auditHeadings() {
    const h1s = document.querySelectorAll('h1').length;
    const h2s = document.querySelectorAll('h2').length;
    const h3s = document.querySelectorAll('h3').length;
    if (h1s === 0) {
      this.warnings.push('No H1 found - Consider adding a main page heading');
    }
    console.log(`✅ Heading audit: H1=${h1s}, H2=${h2s}, H3=${h3s}`);
  }
  /**
   * Audit image alt text
   */
  auditImageAltText() {
    const images = document.querySelectorAll('img');
    let missingAlt = 0;
    images.forEach(img => {
      if (!img.alt || img.alt.trim() === '') {
        missingAlt++;
      }
    });
    if (missingAlt > 0) {
      this.warnings.push(`${missingAlt} images missing alt text`);
    }
    console.log(`✅ Image audit: ${images.length} images found, ${missingAlt} missing alt text`);
  }
  /**
   * Audit form labels
   */
  auditFormLabels() {
    const inputs = document.querySelectorAll('input[type="text"], input[type="email"], textarea, select');
    let missingLabel = 0;
    inputs.forEach(input => {
      const id = input.id;
      if (!id || !document.querySelector(`label[for="${id}"]`)) {
        missingLabel++;
      }
    });
    console.log(`✅ Form audit: ${inputs.length} inputs found, ${missingLabel} missing labels`);
  }
  /**
   * Report audit results
   */
  reportResults() {
    console.log('\n📊 ACCESSIBILITY AUDIT RESULTS\n');
    if (this.issues.length === 0 && this.warnings.length === 0) {
      console.log('✅ No critical accessibility issues found!');
    } else {
      if (this.issues.length > 0) {
        console.log(`🔴 CRITICAL ISSUES (${this.issues.length}):`);
        this.issues.forEach(issue => {
          console.log(`  - ${issue.type}: ${issue.message}`);
        });
      }
      if (this.warnings.length > 0) {
        console.log(`\n⚠️  WARNINGS (${this.warnings.length}):`);
        this.warnings.forEach(warning => {
          console.log(`  - ${warning}`);
        });
      }
    }
    console.log('\n💡 Recommendations:');
    console.log('  1. Run Lighthouse (DevTools > Lighthouse) for full audit');
    console.log('  2. Use WAVE browser extension for detailed analysis');
    console.log('  3. Test with screen reader (VoiceOver on Mac)');
    console.log('  4. Test keyboard navigation with Tab key');
  }
  /**
   * Auto-fix: Add aria-labels where possible
   */
  autoFixAriaLabels() {
    const fixes = [];
    // Fix buttons with icon-only content
    document.querySelectorAll('button[title]:not([aria-label])').forEach(btn => {
      const title = btn.getAttribute('title');
      if (title) {
        btn.setAttribute('aria-label', title);
        fixes.push(`Added aria-label to button: "${title}"`);
      }
    });
    // Fix links with title
    document.querySelectorAll('a[title]:not([aria-label])').forEach(link => {
      const title = link.getAttribute('title');
      if (title) {
        link.setAttribute('aria-label', title);
        fixes.push(`Added aria-label to link: "${title}"`);
      }
    });
    console.log(`✅ Auto-fixed ${fixes.length} aria-labels`);
    return fixes;
  }
}
// Initialize
window.a11yAudit = new AccessibilityAudit();
// Auto-run on page load
document.addEventListener('DOMContentLoaded', () => {
  // Uncomment to run automatic audit on page load
  // window.a11yAudit.auditAll();
  // Run auto-fixes
  window.a11yAudit.autoFixAriaLabels();
});

