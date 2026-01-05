/**
 * Export Handler - Lazy loads html2canvas on demand
 */

(function() {
  'use strict';

  // Store original export functionality
  let exportHandler = null;

  /**
   * Initialize export button handler
   */
  function initExportHandler() {
    const exportBtn = document.getElementById('exportBtn');
    if (!exportBtn) return;

    exportBtn.addEventListener('click', handleExport);
  }

  /**
   * Handle export button click
   */
  async function handleExport(e) {
    e.preventDefault();

    // Show loading state
    const exportBtn = e.target;
    const originalText = exportBtn.textContent;
    exportBtn.textContent = 'Loading...';
    exportBtn.disabled = true;

    try {
      // Load html2canvas on demand
      const html2canvas = await window.loadHtml2Canvas();

      // Get the main content to export
      const mainContent = document.querySelector('.main-wrap');
      if (!mainContent) {
        throw new Error('Main content not found');
      }

      // Generate canvas
      const canvas = await html2canvas(mainContent, {
        allowTaint: true,
        backgroundColor: '#ffffff',
        scale: 2,
        useCORS: true,
        logging: false,
        windowWidth: mainContent.scrollWidth,
        windowHeight: mainContent.scrollHeight
      });

      // Convert to blob and download
      canvas.toBlob(function(blob) {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `dashboard-export-${new Date().toISOString().split('T')[0]}.png`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        // Show success message
        showToast('Dashboard exported successfully');
      });

    } catch (error) {
      console.error('Export failed:', error);
      showToast(`Export failed: ${error.message}`, 'error');
    } finally {
      // Restore button state
      exportBtn.textContent = originalText;
      exportBtn.disabled = false;
    }
  }

  /**
   * Show toast notification
   */
  function showToast(message, type = 'success') {
    const toastContainer = document.getElementById('toastContainer');
    if (!toastContainer) return;

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    toast.style.cssText = `
      padding: 12px 20px;
      margin: 10px;
      background: ${type === 'error' ? '#dc3545' : '#22c55e'};
      color: white;
      border-radius: 6px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
      animation: slideIn 0.3s ease;
    `;

    toastContainer.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      setTimeout(() => toast.remove(), 300);
    }, 3000);
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initExportHandler);
  } else {
    initExportHandler();
  }
})();
