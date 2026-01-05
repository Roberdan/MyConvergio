/**
 * html2canvas Lazy Loader
 * Loads html2canvas only when needed (on export action)
 */

(function() {
  'use strict';

  const config = {
    version: '1.4.1',
    cdnUrl: 'https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js',
    timeout: 10000
  };

  let loadPromise = null;
  let isLoaded = false;

  /**
   * Load html2canvas script
   */
  function loadScript() {
    if (isLoaded) {
      return Promise.resolve(window.html2canvas);
    }

    if (loadPromise) {
      return loadPromise;
    }

    loadPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = config.cdnUrl;
      script.type = 'text/javascript';
      script.async = true;
      script.crossOrigin = 'anonymous';

      const timeout = setTimeout(() => {
        reject(new Error(`html2canvas loading timeout`));
      }, config.timeout);

      script.onload = () => {
        clearTimeout(timeout);
        isLoaded = true;
        console.log('✅ html2canvas loaded');
        resolve(window.html2canvas);
      };

      script.onerror = () => {
        clearTimeout(timeout);
        loadPromise = null;
        reject(new Error(`Failed to load html2canvas from ${config.cdnUrl}`));
      };

      document.head.appendChild(script);
    });

    return loadPromise;
  }

  /**
   * Export html2canvas to global scope
   */
  window.loadHtml2Canvas = function() {
    return loadScript();
  };

  /**
   * Check if html2canvas is already loaded
   */
  window.isHtml2CanvasLoaded = function() {
    return isLoaded;
  };

  console.log('html2canvas lazy loader initialized');
})();
