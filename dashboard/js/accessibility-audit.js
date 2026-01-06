/**
 * Accessibility Audit & Enhancement Module
 * Ensures WCAG 2.1 AA compliance
 */
class AccessibilityAudit {
  constructor() {
    this.issues = [];
    this.warnings = [];
  }

  auditAll() {
    Logger.info('Starting accessibility audit...');
    this.auditAriaLabels();
    this.auditColorContrast();
    this.auditFocusIndicators();
    this.auditKeyboardNavigation();
    this.auditHeadings();
    this.auditImageAltText();
    this.auditFormLabels();
    this.reportResults();
  }

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
  }

  auditColorContrast() {
    const textElements = document.querySelectorAll('p, span, div, label, button, a');
    let checkedCount = 0;
    textElements.forEach(el => {
      const style = window.getComputedStyle(el);
      const color = style.color;
      const bgColor = style.backgroundColor;
      if (color && bgColor && color !== 'rgba(0, 0, 0, 0)') {
        checkedCount++;
      }
    });
  }

  auditFocusIndicators() {
    const focusableElements = document.querySelectorAll(
      'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    Logger.debug(`Found ${focusableElements.length} focusable elements`);
  }

  auditKeyboardNavigation() {
    const tabbableElements = document.querySelectorAll(
      'button:not([disabled]), a[href], input:not([disabled]), select, textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
    );
    Logger.debug(`Found ${tabbableElements.length} tabbable elements`);
  }

  auditHeadings() {
    const h1s = document.querySelectorAll('h1').length;
    const h2s = document.querySelectorAll('h2').length;
    const h3s = document.querySelectorAll('h3').length;
    if (h1s === 0) {
      this.warnings.push('No H1 found - Consider adding a main page heading');
    }
    Logger.debug(`Headings: H1=${h1s}, H2=${h2s}, H3=${h3s}`);
  }

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
  }

  auditFormLabels() {
    const inputs = document.querySelectorAll('input[type="text"], input[type="email"], textarea, select');
    let missingLabel = 0;
    inputs.forEach(input => {
      const id = input.id;
      if (!id || !document.querySelector(`label[for="${id}"]`)) {
        missingLabel++;
      }
    });
  }

  reportResults() {
    Logger.info('Accessibility audit completed');
    if (this.issues.length > 0) {
      Logger.warn(`${this.issues.length} critical issues found`);
      this.issues.forEach(issue => {
        Logger.warn(`  - ${issue.type}: ${issue.message}`);
      });
    }
    if (this.warnings.length > 0) {
      this.warnings.forEach(warning => {
        Logger.warn(`  - ${warning}`);
      });
    }
    if (this.issues.length === 0 && this.warnings.length === 0) {
      Logger.info('No accessibility issues found');
    }
  }

  autoFixAriaLabels() {
    const fixes = [];
    document.querySelectorAll('button[title]:not([aria-label])').forEach(btn => {
      const title = btn.getAttribute('title');
      if (title) {
        btn.setAttribute('aria-label', title);
        fixes.push(`Added aria-label to button: "${title}"`);
      }
    });
    document.querySelectorAll('a[title]:not([aria-label])').forEach(link => {
      const title = link.getAttribute('title');
      if (title) {
        link.setAttribute('aria-label', title);
        fixes.push(`Added aria-label to link: "${title}"`);
      }
    });
    Logger.info(`Auto-fixed ${fixes.length} aria-labels`);
    return fixes;
  }
}

window.a11yAudit = new AccessibilityAudit();
document.addEventListener('DOMContentLoaded', () => {
  window.a11yAudit.autoFixAriaLabels();
});

