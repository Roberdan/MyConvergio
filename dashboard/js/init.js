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

// Wrap loadGitData to also render the git tab
const originalLoadGitData = loadGitData;
loadGitData = async function() {
  await originalLoadGitData();
  if (typeof renderGitTab === 'function') renderGitTab();
};

document.addEventListener('DOMContentLoaded', init);
