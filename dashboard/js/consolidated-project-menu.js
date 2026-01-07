// Consolidated Project Menu with Tree-based Plan Navigation

let projectMenuExpanded = new Set();
let projectPlanCache = {};

async function renderConsolidatedProjectMenu() {
  const list = document.getElementById('projectList');
  if (!list || !registry) return;

  const allProjects = Object.entries(registry.projects || {});

  if (allProjects.length === 0) {
    list.innerHTML = '<div class="project-loading">No projects available</div>';
    return;
  }

  // Sort: doing projects first, then todo
  allProjects.sort(([, a], [, b]) => {
    const aActive = a.plans_doing > 0;
    const bActive = b.plans_doing > 0;
    if (aActive && !bActive) return -1;
    if (!aActive && bActive) return 1;
    return 0;
  });

  // Render consolidated menu
  list.innerHTML = `
    <div class="project-tree">
      ${allProjects.map(([id, p]) => renderProjectNode(id, p)).join('')}
    </div>
  `;

  // Attach event listeners for expand/collapse
  list.querySelectorAll('.project-tree-toggle').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const projectId = btn.closest('.project-tree-node').dataset.projectId;
      toggleProjectNode(projectId);
    });
  });
}

function renderProjectNode(projectId, project) {
  const isExpanded = projectMenuExpanded.has(projectId);
  const isActive = projectId === currentProjectId;
  const hasPlans = project.plans_doing > 0 || project.plans_todo > 0;
  const planCount = project.plans_doing + project.plans_todo + (project.plans_done || 0);

  return `
    <div class="project-tree-node ${isActive ? 'active' : ''}" data-project-id="${projectId}">
      <div class="project-tree-header" onclick="selectProjectFromMenu('${projectId}')">
        ${hasPlans ? `
          <button class="project-tree-toggle" title="Toggle plans">
            <span class="tree-expand-icon">${isExpanded ? '▼' : '▶'}</span>
          </button>
        ` : '<div class="tree-expand-icon-spacer"></div>'}

        <span class="project-tree-dot ${getProjectStatus(project)}"></span>
        <span class="project-tree-name">${project.name}</span>
        <span class="project-tree-count">${planCount}</span>
      </div>

      ${isExpanded && hasPlans ? `
        <div class="project-tree-plans">
          ${renderProjectPlans(projectId) || '<div class="plan-loading">Loading plans...</div>'}
        </div>
      ` : ''}
    </div>
  `;
}

function renderProjectPlans(projectId) {
  const plans = projectPlanCache[projectId];
  if (!plans) {
    loadProjectPlans(projectId);
    return '';
  }

  if (plans.length === 0) {
    return '<div class="plan-empty">No plans</div>';
  }

  return plans.map(plan => {
    const isActive = currentProjectId === projectId && data?.plan_id === plan.id;
    const statusClass = plan.status || 'pending';

    return `
      <div class="plan-tree-item ${isActive ? 'active' : ''} ${statusClass}" onclick="selectPlanFromMenu('${projectId}', '${plan.id}')">
        <span class="plan-status-icon">${getPlanStatusIcon(plan.status)}</span>
        <span class="plan-name">${plan.name || plan.plan_name}</span>
        <span class="plan-meta">${plan.tasks_done || 0}/${plan.tasks_total || 0}</span>
      </div>
    `;
  }).join('');
}

async function loadProjectPlans(projectId) {
  try {
    const res = await fetch(`${API_BASE}/plans/${projectId}`);
    const plans = await res.json();
    projectPlanCache[projectId] = plans || [];

    // Re-render the project node with plans
    const projectNode = document.querySelector(`[data-project-id="${projectId}"]`);
    if (projectNode) {
      const plansContainer = projectNode.querySelector('.project-tree-plans');
      if (plansContainer) {
        plansContainer.innerHTML = renderProjectPlans(projectId);
        attachPlanClickHandlers(projectId);
      }
    }
  } catch (e) {
    projectPlanCache[projectId] = [];
    console.error(`Failed to load plans for ${projectId}:`, e);
  }
}

function attachPlanClickHandlers(projectId) {
  const node = document.querySelector(`[data-project-id="${projectId}"]`);
  if (!node) return;

  node.querySelectorAll('.plan-tree-item').forEach(item => {
    item.addEventListener('click', (e) => {
      const planId = item.textContent.split('\n')[0]; // Simplified - should use data attribute
      e.stopPropagation();
    });
  });
}

function toggleProjectNode(projectId) {
  if (projectMenuExpanded.has(projectId)) {
    projectMenuExpanded.delete(projectId);
  } else {
    projectMenuExpanded.add(projectId);
  }
  renderConsolidatedProjectMenu();
}

async function selectProjectFromMenu(projectId) {
  // Expand/collapse or select project
  const node = document.querySelector(`[data-project-id="${projectId}"]`);
  const toggle = node?.querySelector('.project-tree-toggle');

  if (toggle) {
    // If project has plans, toggle expansion instead of select
    if (projectMenuExpanded.has(projectId)) {
      projectMenuExpanded.delete(projectId);
    } else {
      projectMenuExpanded.add(projectId);
      // Load plans when expanding
      if (!projectPlanCache[projectId]) {
        await loadProjectPlans(projectId);
      }
    }
    renderConsolidatedProjectMenu();
  } else {
    // No plans, just select
    await selectProject(projectId);
  }
}

async function selectPlanFromMenu(projectId, planId) {
  // First select the project
  if (currentProjectId !== projectId) {
    await selectProject(projectId);
  }

  // Then load the plan
  try {
    await loadPlanDetails(planId);
    render();
  } catch (e) {
    console.error('Failed to load plan:', e);
  }

  // Update top bar and close menu
  updateTopBarWithPlan();
  document.getElementById('projectMenu').style.display = 'none';
  renderConsolidatedProjectMenu();

  // Refresh other data
  if (typeof loadGitHubData === 'function') loadGitHubData();
  if (typeof loadGitData === 'function') loadGitData();
  if (typeof loadTokenData === 'function') loadTokenData();
}

function getProjectStatus(project) {
  if (project.plans_doing > 0) return 'in-progress';
  if (project.plans_todo > 0) return 'pending';
  return 'done';
}

function getPlanStatusIcon(status) {
  const icons = {
    'todo': '○',
    'pending': '○',
    'doing': '●',
    'in_progress': '●',
    'done': '✓',
    'completed': '✓',
    'active': '●'
  };
  return icons[status] || '○';
}
