// Initialization

async function init() {
  initTheme();
  try {
    await loadProjects();

    // First check if there are any active plans
    const hasActivePlans = await checkForActivePlans();

    if (!hasActivePlans) {
      // No active plans - clear selection and show Control Center
      clearProjectSelection();
      showView('kanban');
    } else {
      // There are active plans - try to restore last project or select first active
      const lastProject = localStorage.getItem('dashboard-current-project');
      const projectHasActivePlan = lastProject && registry?.projects?.[lastProject]?.plans_doing > 0;

      if (projectHasActivePlan) {
        await selectProject(lastProject);
      } else {
        // Find first project with active plan
        const activeProject = Object.entries(registry?.projects || {}).find(([id, p]) => p.plans_doing > 0);
        if (activeProject) {
          await selectProject(activeProject[0]);
        } else {
          clearProjectSelection();
          showView('kanban');
        }
      }
    }
  } catch (e) {
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
}

async function checkForActivePlans() {
  try {
    const res = await fetch(`${API_BASE}/kanban`);
    const plans = await res.json();
    const doingPlans = plans.filter(p => p.status === 'doing');
    return doingPlans.length > 0;
  } catch (e) {
    console.log('Could not check plan status:', e.message);
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

document.addEventListener('DOMContentLoaded', init);
