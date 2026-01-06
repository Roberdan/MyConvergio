// Views - Core Module
// Main view switching logic

function showView(view) {
  currentView = view;

  // Update breadcrumb navigation
  updateBreadcrumb(view);

  // Close diff view if open
  if (typeof closeDiffView === 'function') closeDiffView();

  // Update nav menu
  document.querySelectorAll('.nav-menu a').forEach(a => {
    a.classList.remove('active');
    const linkText = a.textContent.toLowerCase();
    if (linkText.includes(view) || (view === 'issues' && linkText.includes('issues'))) {
      a.classList.add('active');
    }
  });

  // View elements
  const dashboardElements = ['wavesSummary', 'drilldownPanel'];
  const chartCard = document.querySelector('.chart-card');
  const tradersSection = document.querySelector('.traders-section');
  const kanbanView = document.getElementById('kanbanView');
  const wavesView = document.getElementById('wavesView');
  const agentsView = document.getElementById('agentsView');
  const notificationsView = document.getElementById('notificationsView');
  const statsHeader = document.querySelector('.stats-header');
  const statsRow = document.querySelector('.stats-row');
  const waveIndicator = document.querySelector('.wave-indicator');

  // Sidebars for full-page views
  const gitPanel = document.querySelector('.git-panel');
  const rightPanel = document.querySelector('.right-panel');
  const mainWrap = document.querySelector('.main-wrap');
  const mainContent = document.querySelector('.main-content');
  const isFullPageView = view === 'kanban';

  // Hide all views
  [kanbanView, wavesView, agentsView, notificationsView].forEach(v => {
    if (v) v.style.display = 'none';
  });

  // Hide/show dashboard elements
  const hideDashboard = view !== 'dashboard';
  dashboardElements.forEach(id => {
    const el = document.getElementById(id);
    if (el) el.style.display = hideDashboard ? 'none' : '';
  });
  if (chartCard) chartCard.style.display = hideDashboard ? 'none' : '';
  if (tradersSection) tradersSection.style.display = hideDashboard ? 'none' : '';
  if (statsHeader) statsHeader.style.display = hideDashboard ? 'none' : '';
  if (statsRow) statsRow.style.display = hideDashboard ? 'none' : '';
  if (waveIndicator) waveIndicator.style.display = hideDashboard ? 'none' : '';

  // Full-page mode: hide sidebars
  if (gitPanel) gitPanel.style.display = isFullPageView ? 'none' : '';
  if (rightPanel) rightPanel.style.display = isFullPageView ? 'none' : '';
  if (mainContent) mainContent.classList.toggle('full-width', isFullPageView);
  if (mainWrap) mainWrap.style.padding = isFullPageView ? '0' : '';

  // Show selected view
  switch (view) {
    case 'kanban':
      if (kanbanView) kanbanView.style.display = 'block';
      loadKanban();
      break;
    case 'waves':
      // Show waves view with enhanced Gantt navigation
      document.getElementById('wavesView').style.display = 'block';
      loadWavesView();
      break;

    case 'agents':
      if (agentsView) agentsView.style.display = 'block';
      loadAgentsView();
      break;
    case 'notifications':
      if (notificationsView) notificationsView.style.display = 'block';
      loadNotificationsView();
      break;
    case 'dashboard':
    default:
      if (chartMode === 'tokens') {
        destroyCharts();
        renderTokenChart();
        renderAgents();
      }
      break;
   }
}

// Update breadcrumb navigation
function updateBreadcrumb(view) {
  const breadcrumbNav = document.getElementById('breadcrumbNav');
  if (!breadcrumbNav) return;

  const viewNames = {
    dashboard: 'Dashboard',
    kanban: 'Control Center',
    waves: 'Waves',
    agents: 'Agents',
    notifications: 'Notifications'
  };

  const viewName = viewNames[view] || view;
  breadcrumbNav.innerHTML = `<span class="breadcrumb-item active" data-view="${view}">${viewName}</span>`;
}

// Export functions
window.updateBreadcrumb = updateBreadcrumb;

console.log('Views core loaded');
