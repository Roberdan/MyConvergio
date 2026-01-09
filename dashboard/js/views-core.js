// Views - Core Module
// Main view switching logic

function showView(view) {
  currentView = view;

  // Update breadcrumb navigation
  updateBreadcrumb(view);

  // Hide breadcrumb on dashboard view (redundant)
  const breadcrumbNav = document.getElementById('breadcrumbNav');
  if (breadcrumbNav) {
    breadcrumbNav.style.display = view === 'dashboard' ? 'none' : 'flex';
  }

  // Close diff view if open
  if (typeof closeDiffView === 'function') closeDiffView();
  
  // Close commit viewer if open
  if (typeof closeCommitDetails === 'function') closeCommitDetails();
  const commitViewer = document.getElementById('commitViewer');
  if (commitViewer) commitViewer.style.display = 'none';

  // Update nav menu - remove active from all, add to current
  document.querySelectorAll('.nav-menu > a, .nav-menu > div > a').forEach(a => {
    a.classList.remove('active');
  });

  // Add active class to current view link
  const navLinks = {
    'kanban': 'Control Center',
    'dashboard': 'Dashboard',
    'tasks': 'Tasks',
    'agents': 'Agents',
    'notifications': 'Notifications'
  };

  document.querySelectorAll('.nav-menu a').forEach(a => {
    const linkText = a.textContent.trim().toLowerCase();
    const viewName = navLinks[view]?.toLowerCase() || view.toLowerCase();
    if (linkText.includes(viewName) || (view === 'issues' && linkText.includes('issues'))) {
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
  const isFullPageView = view === 'kanban' || view === 'tasks' || view === 'notifications';

  // Hide all views
  [kanbanView, wavesView, agentsView, notificationsView].forEach(v => {
    if (v) v.style.display = 'none';
  });

  // Hide/show dashboard elements
  const hideDashboard = view !== 'dashboard';
  const emptyState = document.getElementById('emptyState');
  const interactiveGantt = document.querySelector('.interactive-gantt');
  
  dashboardElements.forEach(id => {
    const el = document.getElementById(id);
    if (el) el.style.display = hideDashboard ? 'none' : '';
  });
  if (chartCard) chartCard.style.display = hideDashboard ? 'none' : '';
  if (tradersSection) tradersSection.style.display = hideDashboard ? 'none' : '';
  if (statsHeader) statsHeader.style.display = hideDashboard ? 'none' : '';
  if (statsRow) statsRow.style.display = hideDashboard ? 'none' : '';
  if (waveIndicator) waveIndicator.style.display = hideDashboard ? 'none' : '';
  if (emptyState) emptyState.style.display = (hideDashboard || (data && data.waves?.length > 0)) ? 'none' : '';
  if (interactiveGantt) interactiveGantt.style.display = hideDashboard ? 'none' : 'block';

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
    case 'tasks':
    case 'waves': // backwards compatibility
      // Show tasks view - full page with all waves/tasks expanded
      document.getElementById('wavesView').style.display = 'block';
      loadTasksView();
      break;

    case 'agents':
      if (agentsView) agentsView.style.display = 'block';
      loadAgentsView();
      break;
    case 'notifications':
      if (notificationsView) notificationsView.style.display = 'block';
      if (typeof loadNotificationsView === 'function') {
        loadNotificationsView();
      }
      break;
    case 'dashboard':
    default:
      // Auto-load Gantt for current project
      if (currentProjectId && typeof GanttView !== 'undefined') {
        GanttView.renderTarget = 'ganttContentArea';
        GanttView.load(currentProjectId);
      }
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
    tasks: 'Tasks',
    waves: 'Tasks', // backwards compatibility
    agents: 'Agents',
    notifications: 'Notifications'
  };

  const viewName = viewNames[view] || view;
  breadcrumbNav.innerHTML = `<span class="breadcrumb-item active" data-view="${view}">${viewName}</span>`;
}

// Export functions
window.updateBreadcrumb = updateBreadcrumb;
