/**
 * ApexCharts Loader - Self-hosted with CDN fallback
 * Provides the ApexCharts library either from local files or CDN
 */

(function() {
  'use strict';

  // Check if ApexCharts is already loaded
  if (window.ApexCharts) {
    console.log('ApexCharts already loaded');
    return;
  }

  // Configuration
  const config = {
    localUrl: '/libs/apexcharts/apexcharts.min.js',
    cdnUrl: 'https://cdn.jsdelivr.net/npm/apexcharts@latest/dist/apexcharts.min.js',
    timeout: 5000,
    retries: 2
  };

  /**
   * Load script from URL
   */
  function loadScript(url, options = {}) {
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = url;
      script.type = 'text/javascript';
      script.async = true;

      if (options.crossOrigin) {
        script.crossOrigin = options.crossOrigin;
      }

      const timeout = setTimeout(() => {
        reject(new Error(`Script loading timeout: ${url}`));
      }, config.timeout);

      script.onload = () => {
        clearTimeout(timeout);
        resolve();
      };

      script.onerror = () => {
        clearTimeout(timeout);
        reject(new Error(`Failed to load script: ${url}`));
      };

      document.head.appendChild(script);
    });
  }

  /**
   * Load ApexCharts with fallback strategy
   */
  async function loadApexCharts() {
    let lastError;

    // Try local version first
    try {
      console.log('Attempting to load ApexCharts from local: ', config.localUrl);
      await loadScript(config.localUrl);
      if (window.ApexCharts) {
        console.log('✅ ApexCharts loaded from local');
        return true;
      }
    } catch (error) {
      console.warn('Local ApexCharts load failed:', error.message);
      lastError = error;
    }

    // Fall back to CDN
    try {
      console.log('Falling back to CDN: ', config.cdnUrl);
      await loadScript(config.cdnUrl, { crossOrigin: 'anonymous' });
      if (window.ApexCharts) {
        console.log('✅ ApexCharts loaded from CDN');
        return true;
      }
    } catch (error) {
      console.error('CDN ApexCharts load failed:', error.message);
      lastError = error;
    }

    // If all else fails, provide a stub
    console.error('Failed to load ApexCharts. Using stub.');
    window.ApexCharts = function() {
      console.warn('ApexCharts is not available. Charts will not render.');
      return {
        render: function() {},
        destroy: function() {},
        updateSeries: function() {}
      };
    };

    return false;
  }

  // Load when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadApexCharts);
  } else {
    loadApexCharts().catch(error => {
      console.error('Error loading ApexCharts:', error);
    });
  }
})();
