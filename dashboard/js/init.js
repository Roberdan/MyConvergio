// Initialization

async function init() {
  initTheme();
  try {
    await loadProjects();

    const lastProject = localStorage.getItem('dashboard-current-project');
    if (lastProject && registry?.projects?.[lastProject]) {
      await selectProject(lastProject);
    } else {
      const res = await fetch('plan.json');
      data = await res.json();
      currentProjectId = data.meta?.project_id || null;
      render();
    }

    // Check if any plans are in "doing" status - if not, redirect to Control Center
    await checkAndRedirectToControlCenter();
  } catch (e) {
    document.querySelector('.main-content').innerHTML = `<div style="padding:40px;color:#ef4444;">Error: ${e.message}</div>`;
  }

  // Ensure git panel is never collapsed
  const panel = document.getElementById('gitPanel');
  if (panel) panel.classList.remove('collapsed');
  localStorage.removeItem('git-panel-collapsed');

  // Start notification polling
  startNotificationPolling();
}

async function checkAndRedirectToControlCenter() {
  try {
    const res = await fetch(`${API_BASE}/kanban`);
    const plans = await res.json();
    const doingPlans = plans.filter(p => p.status === 'doing');

    if (doingPlans.length === 0) {
      // No active plans - show Control Center
      showView('kanban');
    }
  } catch (e) {
    console.log('Could not check plan status:', e.message);
  }
}

// Wrap loadGitData to also render the git tab
const originalLoadGitData = loadGitData;
loadGitData = async function() {
  await originalLoadGitData();
  if (typeof renderGitTab === 'function') renderGitTab();
};

document.addEventListener('DOMContentLoaded', init);
