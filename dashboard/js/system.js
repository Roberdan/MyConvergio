// System Functions - Dashboard shutdown and management

async function shutdownDashboard() {
  // Confirm shutdown
  const confirmed = confirm('Shutdown dashboard server and close window?');
  if (!confirmed) return;

  try {
    // Show toast notification
    showToast('Shutting down...', 'info');

    // Call shutdown endpoint
    await fetch(`${API_BASE}/system/shutdown`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });

    // Wait a moment for server to shutdown
    setTimeout(() => {
      // Close browser window/tab
      window.close();

      // If window.close() doesn't work (some browsers block it), show message
      setTimeout(() => {
        document.body.innerHTML = `
          <div style="display: flex; align-items: center; justify-content: center; height: 100vh; flex-direction: column; gap: 20px; font-family: system-ui;">
            <h1 style="margin: 0; color: #22c55e;">Dashboard Shutdown</h1>
            <p style="margin: 0; color: #666;">Server stopped successfully. You can close this window.</p>
          </div>
        `;
      }, 100);
    }, 500);

  } catch (e) {
    console.error('Shutdown error:', e);
    showToast('Shutdown failed: ' + e.message, 'error');
  }
}
