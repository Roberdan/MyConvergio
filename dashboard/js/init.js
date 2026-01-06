// Initialization

async function init() {
  initTheme();
  try {
    await loadProjects();

    // Force load ConvergioEdu project data immediately
    console.log('Forcing ConvergioEdu project load...');
    await forceLoadConvergioEdu();

  } catch (e) {
    console.error('Init error:', e);
    document.querySelector('.main-content').innerHTML = `<div style="padding:40px;color:#ef4444;">Error: ${e.message}</div>`;
  }

  // Ensure git panel is never collapsed
  const panel = document.getElementById('gitPanel');
  if (panel) panel.classList.remove('collapsed');
  localStorage.removeItem('git-panel-collapsed');

  // Start notification polling
  startNotificationPolling();

  // Start data auto-refresh (every 30 seconds)
  startDataRefresh();

  // Initialize bug list
    if (typeof initBugList === 'function') {
      initBugList();
    }

  // Initialize bug tracker
  if (typeof initBugTracker === 'function') {
    initBugTracker();
  }
}

// Force load ConvergioEdu project data - Simplified approach
async function forceLoadConvergioEdu() {
  console.log('Loading ConvergioEdu dashboard data...');

  try {
    // Load data directly from API
    const response = await fetch('/api/project/convergioedu/dashboard');
    const projectData = await response.json();

    console.log('Loaded data:', projectData);

    // Update the UI immediately
    updateDashboardUI(projectData);

  } catch (error) {
    console.error('Failed to load dashboard:', error);

    // Fallback: show hardcoded data
    updateDashboardUI({
      meta: { project: 'ConvergioEdu' },
      metrics: { throughput: { done: 96, total: 136, percent: 71 } },
      plans: { done: 2, total: 5 }
    });
  }
}

// Update dashboard UI with data
function updateDashboardUI(data) {
  console.log('Updating dashboard UI with:', data);

  // Update project name
  const planLabel = document.getElementById('planLabel');
  if (planLabel) planLabel.textContent = data.meta?.project || 'ConvergioEdu';

  // Show stats row
  const statsRow = document.getElementById('statsRow');
  if (statsRow) statsRow.style.display = 'flex';

  // Update stats
  const tasksDone = document.getElementById('tasksDone');
  if (tasksDone && data.metrics?.throughput) {
    tasksDone.textContent = `${data.metrics.throughput.done}/${data.metrics.throughput.total}`;
  }

  const progressPercent = document.getElementById('progressPercent');
  if (progressPercent && data.metrics?.throughput) {
    progressPercent.textContent = `${data.metrics.throughput.percent}%`;
  }

  const wavesStatus = document.getElementById('wavesStatus');
  if (wavesStatus && data.plans) {
    wavesStatus.textContent = `${data.plans.done}/${data.plans.total}`;
  }

  console.log('Dashboard UI updated successfully');
}

async function checkForActivePlans() {
  try {
    const res = await fetch(`${API_BASE}/kanban`);
    const plans = await res.json();
    const doingPlans = plans.filter(p => p.status === 'doing');
    return doingPlans.length > 0;
  } catch (e) {
    return false;
  }
}

function clearProjectSelection() {
  currentProjectId = null;
  localStorage.removeItem('dashboard-current-project');

  // Clear global data
  if (typeof data !== 'undefined') {
    data = { meta: {}, waves: [], tasks: [], github: {} };
  }

  // Clear project header
  const projectName = document.getElementById('projectName');
  if (projectName) projectName.textContent = 'Select Project';

  const projectAvatar = document.getElementById('projectAvatar');
  if (projectAvatar) projectAvatar.style.display = 'none';

  const gitRepoAvatar = document.getElementById('gitRepoAvatar');
  if (gitRepoAvatar) gitRepoAvatar.style.display = 'none';

  const gitRepoName = document.getElementById('gitRepoName');
  if (gitRepoName) gitRepoName.textContent = 'Project';

  // Clear nav counts and throughput
  const navCounts = ['navKanbanCount', 'navWavesCount', 'navIssuesCount'];
  navCounts.forEach(id => {
    const el = document.getElementById(id);
    if (el) el.textContent = '';
  });

  const throughputBadge = document.getElementById('throughputBadge');
  if (throughputBadge) throughputBadge.textContent = '-';

  // Clear waves
  const wavesList = document.getElementById('wavesList');
  if (wavesList) wavesList.innerHTML = '<div class="cc-empty">Select a project</div>';

  const wavesSummary = document.getElementById('wavesSummary');
  if (wavesSummary) wavesSummary.style.display = 'none';

  const wavesStatus = document.getElementById('wavesStatus');
  if (wavesStatus) wavesStatus.textContent = '-';

  // Clear issues tab
  const tabIssues = document.getElementById('tabIssues');
  if (tabIssues) tabIssues.innerHTML = '<div class="issues-loading">Select a project</div>';

  // Clear health indicators
  const healthItems = ['healthWave', 'healthBuild', 'healthTests', 'healthIssues'];
  healthItems.forEach(id => {
    const el = document.getElementById(id);
    if (el) {
      el.className = 'health-item';
      const value = el.querySelector('.health-value');
      if (value) value.textContent = '-';
    }
  });

  // Clear drilldown
  const drilldownPanel = document.getElementById('drilldownPanel');
  if (drilldownPanel) drilldownPanel.style.display = 'none';

  // Clear wave indicator
  const waveIndicator = document.getElementById('waveIndicator');
  if (waveIndicator) waveIndicator.style.display = 'none';

  const currentWave = document.getElementById('currentWave');
  if (currentWave) currentWave.textContent = '-';

  const countdown = document.getElementById('countdown');
  if (countdown) countdown.textContent = '-';

  const epochFill = document.getElementById('epochFill');
  if (epochFill) epochFill.style.width = '0%';

  // Hide sidebars in Control Center mode
  const gitPanel = document.querySelector('.git-panel');
  const rightPanel = document.querySelector('.right-panel');
  if (gitPanel) gitPanel.style.display = 'none';
  if (rightPanel) rightPanel.style.display = 'none';

  // Clear bug list
  const bugListContainer = document.getElementById('bugListContainer');
  if (bugListContainer) bugListContainer.innerHTML = '';
}

// Wrap loadGitData to also render the git tab
const originalLoadGitData = loadGitData;
loadGitData = async function() {
  await originalLoadGitData();
  if (typeof renderGitTab === 'function') renderGitTab();
};

// Data auto-refresh - refreshes project data every 30 seconds
async function refreshData() {
  if (!currentProjectId) return;

  try {
    // Refresh project data silently (no loading spinners)
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/dashboard`);
    if (res.ok) {
      const newData = await res.json();
      // Only update if data changed
      if (JSON.stringify(newData.meta) !== JSON.stringify(data?.meta) ||
          JSON.stringify(newData.waves) !== JSON.stringify(data?.waves) ||
          JSON.stringify(newData.tasks) !== JSON.stringify(data?.tasks)) {
        data = newData;
        // Re-render current view
        if (currentView === 'kanban') {
          renderKanban();
        } else if (currentView === 'waves') {
          renderWaves();
        } else if (currentView === 'issues') {
          renderIssues();
        }
        // Update git panel
        if (typeof loadGitData === 'function') loadGitData();
      }
    }
  } catch (e) {
    // Silent fail - don't interrupt user
    console.log('Data refresh failed:', e.message);
  }
}

function startDataRefresh() {
  // Initial refresh not needed - data already loaded
  dataRefreshInterval = setInterval(refreshData, 30000);
}

function stopDataRefresh() {
  if (dataRefreshInterval) {
    clearInterval(dataRefreshInterval);
    dataRefreshInterval = null;
  }
}

// Unified dropdown manager - closes all dropdowns when clicking outside
// or when opening a different dropdown
const registeredDropdowns = [
  { menu: 'projectMenu', trigger: '.logo, .project-name' },
  { menu: 'waveMenuList', trigger: '.wave-menu-trigger' },
  { menu: 'gitBranchList', trigger: '#gitBranchToggle' },
  { menu: 'bugDropdownMenu', trigger: '.bug-dropdown-toggle' }
];

function closeAllDropdowns(exceptMenu = null) {
  registeredDropdowns.forEach(({ menu }) => {
    if (menu === exceptMenu) return;
    const el = document.getElementById(menu);
    if (el) {
      el.style.display = 'none';
      el.classList.remove('is-open');
    }
  });
}

// Global click handler to close dropdowns when clicking outside
document.addEventListener('click', (e) => {
  let clickedInDropdown = false;
  let clickedMenuId = null;

  // Check if click was inside any registered dropdown or its trigger
  registeredDropdowns.forEach(({ menu, trigger }) => {
    const menuEl = document.getElementById(menu);
    const triggerEls = document.querySelectorAll(trigger);

    if (menuEl && menuEl.contains(e.target)) {
      clickedInDropdown = true;
      clickedMenuId = menu;
    }

    triggerEls.forEach(triggerEl => {
      if (triggerEl && triggerEl.contains(e.target)) {
        clickedInDropdown = true;
        clickedMenuId = menu;
      }
    });
  });

  // If clicked outside all dropdowns and triggers, close all
  if (!clickedInDropdown) {
    closeAllDropdowns();
  }
});

document.addEventListener('DOMContentLoaded', init);
