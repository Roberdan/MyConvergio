// Theme Management

function initTheme() {
  const saved = localStorage.getItem('dashboard-theme') || 'voltrex';
  document.documentElement.setAttribute('data-theme', saved);
  document.getElementById('themeSelect').value = saved;
}

function setTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  localStorage.setItem('dashboard-theme', theme);
  if (data) {
    destroyCharts();
    renderChart();
    renderAgents();
  }
}

function destroyCharts() {
  if (mainChart) {
    mainChart.destroy();
    mainChart = null;
  }
  sparkCharts.forEach(c => c.destroy());
  sparkCharts = [];
}

// Theme selector event listener
document.getElementById('themeSelect')?.addEventListener('change', (e) => {
  setTheme(e.target.value);
});
