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

  const projectName = document.getElementById('projectName');
  if (projectName) projectName.textContent = 'Select Project';

  const projectAvatar = document.getElementById('projectAvatar');
  if (projectAvatar) projectAvatar.style.display = 'none';

  const gitRepoAvatar = document.getElementById('gitRepoAvatar');
  if (gitRepoAvatar) gitRepoAvatar.style.display = 'none';

  const gitRepoName = document.getElementById('gitRepoName');
  if (gitRepoName) gitRepoName.textContent = 'Project';
}

// Wrap loadGitData to also render the git tab
const originalLoadGitData = loadGitData;
loadGitData = async function() {
  await originalLoadGitData();
  if (typeof renderGitTab === 'function') renderGitTab();
};

document.addEventListener('DOMContentLoaded', init);
