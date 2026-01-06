// Initialization - Simplified

// Update navigation state based on project selection
function updateNavState(hasProject) {
  const projectDependentItems = [
    { selector: '.nav-menu a[onclick*="dashboard"]', action: 'link' },
    { selector: '.nav-menu a[onclick*="tasks"]', action: 'link' },
    { selector: '#throughputBadge', action: 'element' },
    { selector: '#bugTrackerBtn', action: 'button' },
    { selector: '#exportBtn', action: 'button' }
  ];

  projectDependentItems.forEach(item => {
    const el = document.querySelector(item.selector);
    if (!el) return;
    
    if (hasProject) {
      el.classList.remove('disabled');
      el.removeAttribute('disabled');
      if (item.action === 'link') {
        el.style.pointerEvents = '';
      }
    } else {
      el.classList.add('disabled');
      el.setAttribute('disabled', 'true');
      if (item.action === 'link') {
        el.style.pointerEvents = 'none';
      }
    }
  });
}

async function init() {
  initTheme();
  
  // Initially disable project-dependent menus
  updateNavState(false);
  
  try {
    await loadProjects();

    // Auto-select last project if available, otherwise prompt user to choose
    const savedProject = localStorage.getItem('dashboard-current-project');
    if (savedProject && registry?.projects?.[savedProject]) {
      await selectProject(savedProject);
    } else {
      const firstProject = Object.keys(registry?.projects || {})[0];
      if (firstProject) {
        await selectProject(firstProject);
      } else {
        // No projects - show Control Center by default
        showView('kanban');
      }
    }
  } catch (e) {
    Logger.error('Init error:', e);
    document.querySelector('.main-content').innerHTML = `<div style="padding:40px;color:#ef4444;">Error: ${e.message}</div>`;
  }

  const panel = document.getElementById('gitPanel');
  if (panel) panel.classList.remove('collapsed');
  localStorage.removeItem('git-panel-collapsed');

  startNotificationPolling();
  startDataRefresh();

  if (typeof initBugList === 'function') initBugList();
  if (typeof initBugTracker === 'function') initBugTracker();
}

function updateDashboardUI(data) {
  Logger.debug('Updating dashboard UI with:', data);
  const setText = (id, text) => { const el = document.getElementById(id); if (el) el.textContent = text; };
  const setDisplay = (id, display) => { const el = document.getElementById(id); if (el) el.style.display = display; };

  setText('planLabel', data.meta?.project || 'ConvergioEdu');
  setDisplay('statsRow', 'flex');

  if (data.metrics?.throughput) {
    setText('tasksDone', `${data.metrics.throughput.done}/${data.metrics.throughput.total}`);
    setText('progressPercent', `${data.metrics.throughput.percent}%`);
  }
  if (data.plans) {
    setText('wavesStatus', `${data.plans.done}/${data.plans.total}`);
  }
  Logger.debug('Dashboard UI updated successfully');
}

function clearProjectSelection() {
  currentProjectId = null;
  localStorage.removeItem('dashboard-current-project');
  if (typeof data !== 'undefined') {
    data = { meta: {}, waves: [], tasks: [], github: {} };
  }

  const setText = (id, text) => { const el = document.getElementById(id); if (el) el.textContent = text; };
  const setDisplay = (id, display) => { const el = document.getElementById(id); if (el) el.style.display = display; };
  const setHTML = (id, html) => { const el = document.getElementById(id); if (el) el.innerHTML = html; };

  setText('projectName', 'Select Project');
  setDisplay('projectAvatar', 'none');
  setDisplay('gitRepoAvatar', 'none');
  setText('gitRepoName', 'Project');

  ['navKanbanCount', 'navTasksCount', 'navIssuesCount'].forEach(id => setText(id, ''));
  setText('throughputBadge', '-');
  setHTML('wavesList', '<div class="cc-empty">Select a project</div>');
  setDisplay('wavesSummary', 'none');
  setText('wavesStatus', '-');
  setHTML('tabIssues', '<div class="issues-loading">Select a project</div>');

  ['healthWave', 'healthBuild', 'healthTests', 'healthIssues'].forEach(id => {
    const el = document.getElementById(id);
    if (el) { el.className = 'health-item'; const v = el.querySelector('.health-value'); if (v) v.textContent = '-'; }
  });

  setDisplay('drilldownPanel', 'none');
  setDisplay('waveIndicator', 'none');
  setText('currentWave', '-');
  setText('countdown', '-');
  setDisplay('epochFill', '0%');

  document.querySelectorAll('.git-panel, .right-panel').forEach(el => el.style.display = 'none');
}

const originalLoadGitData = loadGitData;
loadGitData = async function() {
  await originalLoadGitData();
  if (typeof renderGitTab === 'function') renderGitTab();
};

async function refreshData() {
  if (!currentProjectId) return;
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/dashboard`);
    if (res.ok) {
      const newData = await res.json();
      if (JSON.stringify(newData.meta) !== JSON.stringify(data?.meta) ||
          JSON.stringify(newData.waves) !== JSON.stringify(data?.waves) ||
          JSON.stringify(newData.tasks) !== JSON.stringify(data?.tasks)) {
        data = newData;
        if (currentView === 'kanban') renderKanban();
        else if (currentView === 'waves') renderWaves();
        else if (currentView === 'issues') renderIssues();
        if (typeof loadGitData === 'function') loadGitData();
      }
    }
  } catch (e) {
    Logger.debug('Data refresh failed:', e.message);
  }
}

function startDataRefresh() {
  dataRefreshInterval = setInterval(refreshData, 30000);
}

function stopDataRefresh() {
  if (dataRefreshInterval) {
    clearInterval(dataRefreshInterval);
    dataRefreshInterval = null;
  }
}

document.addEventListener('DOMContentLoaded', init);
