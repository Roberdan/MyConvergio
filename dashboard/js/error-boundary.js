/**
 * Error Boundary Module
 * Provides graceful error handling for critical dashboard sections
 */
class ErrorBoundary {
  constructor(container, fallbackUI = null) {
    this.container = container;
    this.fallbackUI = fallbackUI;
    this.isErrored = false;
    this.error = null;
  }
  /**
   * Wrap a function with error boundary
   */
  wrap(fn, options = {}) {
    const {
      silent = false,
      onError = null,
      retry = true,
      maxRetries = 3
    } = options;
    return async (...args) => {
      let retries = 0;
      while (retries < maxRetries) {
        try {
          this.isErrored = false;
          this.error = null;
          const result = await fn(...args);
          return result;
        } catch (error) {
          retries++;
          this.error = error;
          if (retries >= maxRetries || !retry) {
            this.isErrored = true;
            if (!silent) {
              console.error(`[ErrorBoundary] Operation failed: ${error.message}`);
            }
            if (onError) {
              onError(error);
            }
            this.showErrorUI(error);
            throw error;
          }
          // Exponential backoff before retry
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, retries) * 1000));
        }
      }
    };
  }
  /**
   * Show user-friendly error UI
   */
  showErrorUI(error) {
    if (!this.container) return;
    const errorHTML = `
      <div class="error-boundary-container">
        <div class="error-boundary-content">
          <div class="error-icon">⚠️</div>
          <h3 class="error-title">Something went wrong</h3>
          <p class="error-message">${this.sanitize(error.message || 'Unknown error')}</p>
          <div class="error-actions">
            <button class="error-btn error-btn-primary" onclick="location.reload()">
              Reload Page
            </button>
            <button class="error-btn error-btn-secondary" onclick="this.parentElement.parentElement.parentElement.remove()">
              Dismiss
            </button>
          </div>
          ${this.isDev() ? `<details class="error-details">
            <summary>Developer Info</summary>
            <pre>${this.sanitize(error.stack || error.toString())}</pre>
          </details>` : ''}
        </div>
      </div>
    `;
    this.container.innerHTML = errorHTML;
    this.container.classList.add('has-error');
  }
  /**
   * Show fallback UI on critical error
   */
  showFallback() {
    if (!this.container || !this.fallbackUI) return;
    this.container.innerHTML = this.fallbackUI;
    this.container.classList.add('has-fallback');
  }
  /**
   * Clear error state
   */
  clear() {
    this.isErrored = false;
    this.error = null;
    if (this.container) {
      this.container.classList.remove('has-error', 'has-fallback');
    }
  }
  /**
   * Sanitize error message for display
   */
  sanitize(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
  /**
   * Check if running in development
   */
  isDev() {
    return !process.env.NODE_ENV || process.env.NODE_ENV === 'development';
  }
}
/**
 * Global error boundary for unhandled errors
 */
class GlobalErrorBoundary {
  constructor() {
    this.handlers = [];
    this.setupGlobalListeners();
  }
  /**
   * Setup global error listeners
   */
  setupGlobalListeners() {
    // Handle uncaught exceptions
    window.addEventListener('error', (event) => {
      this.handleError(event.error, 'uncaughtException');
    });
    // Handle unhandled promise rejections
    window.addEventListener('unhandledrejection', (event) => {
      this.handleError(event.reason, 'unhandledRejection');
    });
    // Handle navigation errors (network issues, CORS, etc)
    document.addEventListener('DOMContentLoaded', () => {
      const originalFetch = window.fetch;
      window.fetch = async (...args) => {
        try {
          const response = await originalFetch(...args);
          if (!response.ok) {
            console.warn(`[ErrorBoundary] HTTP ${response.status}: ${response.statusText}`);
          }
          return response;
        } catch (error) {
          this.handleError(error, 'fetchError');
          throw error;
        }
      };
    });
  }
  /**
   * Register error handler
   */
  onError(handler) {
    this.handlers.push(handler);
  }
  /**
   * Handle global errors
   */
  handleError(error, type) {
    console.error(`[ErrorBoundary] ${type}:`, error);
    // Call registered handlers
    this.handlers.forEach(handler => {
      try {
        handler(error, type);
      } catch (e) {
        console.error('[ErrorBoundary] Handler error:', e);
      }
    });
    // Show toast notification for critical errors
    if (type === 'uncaughtException' || type === 'unhandledRejection') {
      this.showErrorToast(error, type);
    }
  }
  /**
   * Show error toast notification
   */
  showErrorToast(error, type) {
    const container = document.getElementById('toastContainer');
    if (!container) return;
    const toast = document.createElement('div');
    toast.className = 'toast toast-error';
    toast.setAttribute('role', 'alert');
    toast.textContent = `Error: ${error?.message || 'Unknown error'}`;
    toast.style.cssText = `
      padding: 12px 20px;
      margin: 10px;
      background: #dc3545;
      color: white;
      border-radius: 6px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
      border-left: 4px solid #bb2d3b;
    `;
    container.appendChild(toast);
    // Auto-dismiss after 5s
    setTimeout(() => {
      toast.style.opacity = '0';
      setTimeout(() => toast.remove(), 300);
    }, 5000);
  }
  /**
   * Create error context for debugging
   */
  createContext() {
    return {
      timestamp: new Date().toISOString(),
      url: window.location.href,
      userAgent: navigator.userAgent,
      memory: performance.memory ? {
        usedJSHeapSize: performance.memory.usedJSHeapSize,
        totalJSHeapSize: performance.memory.totalJSHeapSize,
        jsHeapSizeLimit: performance.memory.jsHeapSizeLimit
      } : null
    };
  }
}
/**
 * Recovery strategies for common error scenarios
 */
class ErrorRecovery {
  /**
   * Recover from network errors
   */
  static async recoverFromNetworkError(fn, maxRetries = 3) {
    for (let i = 0; i < maxRetries; i++) {
      try {
        return await fn();
      } catch (error) {
        if (i === maxRetries - 1) throw error;
        // Wait with exponential backoff
        const delay = Math.pow(2, i) * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
  /**
   * Recover from timeout errors
   */
  static async recoverFromTimeout(fn, timeoutMs = 5000) {
    return Promise.race([
      fn(),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Operation timed out')), timeoutMs)
      )
    ]);
  }
  /**
   * Recover from DOM errors
   */
  static recoverFromDOMError(fn, fallback = null) {
    try {
      return fn();
    } catch (error) {
      console.error('[ErrorBoundary] DOM Error:', error);
      return fallback;
    }
  }
  /**
   * Recover from API errors
   */
  static async recoverFromAPIError(response, fallbackData = null) {
    if (!response.ok) {
      const error = new Error(`API Error: ${response.status} ${response.statusText}`);
      console.error('[ErrorBoundary] API Error:', error);
      return fallbackData;
    }
    return response.json();
  }
}
/**
 * Initialize global error boundary
 */
const globalErrorBoundary = new GlobalErrorBoundary();
// Example: Log errors to external service (opt-in)
// globalErrorBoundary.onError((error, type) => {
//   fetch('/api/errors', {
//     method: 'POST',
//     body: JSON.stringify({
//       error: error.message,
//       stack: error.stack,
//       type: type,
//       context: globalErrorBoundary.createContext()
//     })
//   }).catch(e => console.error('Failed to report error:', e));
// });
// Export for use in other modules
window.ErrorBoundary = ErrorBoundary;
window.ErrorRecovery = ErrorRecovery;
window.globalErrorBoundary = globalErrorBoundary;

