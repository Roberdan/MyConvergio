// Project Management - UI Module
// Menu toggles and UI helpers
function toggleProjectMenu() {
  const menu = document.getElementById('projectMenu');
  if (menu) {
    const isOpening = menu.style.display === 'none';
    if (isOpening) {
      DropdownManager.closeAll('projectMenu');
    }
    menu.style.display = isOpening ? 'block' : 'none';
  }
}
async function refreshProjects() {
  await loadProjects();
  renderConsolidatedProjectMenu();
}
function showLearningStats() {
  const stats = {
    totalPlans: Object.keys(registry?.projects || {}).length,
    message: 'Learning stats will show plan modification patterns and optimization insights.'
  };
  showToast(`Learning Stats\nTotal Projects: ${stats.totalPlans}\n${stats.message}`, 'info');
}
function extractGitHubOwner(githubUrl) {
  if (!githubUrl) return null;
  const match = githubUrl.match(/github\.com[/:]([\w-]+)/);
  return match ? match[1] : null;
}
function updateTopBarWithPlan() {
  const projectNameEl = document.getElementById('projectName');
  if (!projectNameEl) return;
  const project = registry?.projects?.[currentProjectId];
  const projectName = project?.name || 'Select Project';
  const currentPlan = currentPlans?.find(p => p.id === currentPlanId);
  const planName = currentPlan?.name || '';
  if (planName) {
    projectNameEl.innerHTML = `${projectName} › ${planName} <span class="project-dropdown">▼</span>`;
  } else {
    projectNameEl.innerHTML = `${projectName} <span class="project-dropdown">▼</span>`;
  }
}
async function selectPlan(planId) {
  const planMenu = document.getElementById('planMenu');
  if (planMenu) planMenu.style.display = 'none';
  await loadPlanDetails(planId);
  updateTopBarWithPlan();
  renderConsolidatedProjectMenu();
  loadGitHubData();
  loadGitData();
  loadTokenData();
}
// Close project menu when clicking outside
document.addEventListener('click', (e) => {
  const menu = document.getElementById('projectMenu');
  const logo = document.querySelector('.logo');
  if (menu && !menu.contains(e.target) && !logo.contains(e.target)) {
    menu.style.display = 'none';
  }
});

