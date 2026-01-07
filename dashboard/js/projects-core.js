// Project Management - Core Module
// Load, render, and select projects

async function loadProjects() {
  try {
    const res = await fetch(`${API_BASE}/projects`);
    const projectsList = await res.json();
    registry = { projects: {} };
    projectsList.forEach(p => {
      registry.projects[p.project_id] = {
        name: p.project_name,
        github_url: p.github_url,
        plans_todo: p.plans_todo,
        plans_doing: p.plans_doing,
        plans_done: p.plans_done,
        plans_total: p.plans_total
      };
    });
    renderConsolidatedProjectMenu();
  } catch (e) {
    try {
      const res = await fetch('../plans/registry.json');
      registry = await res.json();
      renderConsolidatedProjectMenu();
    } catch (e2) {
      registry = { projects: {} };
    }
  }
}

function renderProjectList() {
  const list = document.getElementById('projectList');
  if (!list || !registry) return;

  const allProjects = Object.entries(registry.projects || {});
  const activeProjects = allProjects.filter(([id, p]) => p.plans_doing > 0 || p.plans_todo > 0);

  if (activeProjects.length === 0) {
    list.innerHTML = '<div class="project-loading">No active projects</div>';
    return;
  }

  activeProjects.sort(([, a], [, b]) => {
    if (a.plans_doing > 0 && b.plans_doing === 0) return -1;
    if (a.plans_doing === 0 && b.plans_doing > 0) return 1;
    return 0;
  });

  list.innerHTML = activeProjects.map(([id, p]) => {
    const isActive = id === currentProjectId;
    const isDoing = p.plans_doing > 0;
    const statusLabel = isDoing ? 'In Progress' : 'Pending';
    const statusClass = isDoing ? 'in-progress' : 'pending';

    return `
      <div class="project-item ${isActive ? 'active' : ''} ${statusClass}" onclick="selectProject('${id}')">
        <div class="project-item-dot"></div>
        <div class="project-item-info">
          <div class="project-item-name">${p.name}</div>
          <div class="project-item-plan">${statusLabel} (${p.plans_doing + p.plans_todo} plans)</div>
        </div>
        ${p.github_url ? '<span title="GitHub">&#x1F517;</span>' : ''}
      </div>
    `;
  }).join('');
}

async function selectProject(projectId) {
  const project = registry?.projects?.[projectId];
  if (!project) return;

  currentProjectId = projectId;
  localStorage.setItem('dashboard-current-project', projectId);

  const gitPanel = document.querySelector('.git-panel');
  const rightPanel = document.querySelector('.right-panel');
  if (gitPanel) gitPanel.style.display = '';
  if (rightPanel) rightPanel.style.display = '';

  // Update project avatar from GitHub
  const avatarEl = document.getElementById('projectAvatar');
  if (avatarEl && project.github_url) {
    const owner = extractGitHubOwner(project.github_url);
    if (owner) {
      avatarEl.src = `https://github.com/${owner}.png?size=48`;
      avatarEl.alt = owner;
      avatarEl.style.display = 'block';
      avatarEl.onerror = () => { avatarEl.style.display = 'none'; };
    } else {
      avatarEl.style.display = 'none';
    }
  } else if (avatarEl) {
    avatarEl.style.display = 'none';
  }

  try {
      Logger.info('Selecting project:', projectId, project.name);
      currentProjectId = projectId;

      // Load aggregated project dashboard data
      const dashboardRes = await fetch(`${API_BASE}/project/${projectId}/dashboard`);
      Logger.debug('Dashboard API response:', dashboardRes.status);

      if (dashboardRes.ok) {
        data = await dashboardRes.json();
        Logger.debug('Loaded dashboard data:', data);
        render();
      } else {
       // Fallback to old method if endpoint doesn't exist
       const res = await fetch(`${API_BASE}/plans/${projectId}`);
       const plans = await res.json();
       currentPlans = plans;

       const activePlan = plans.find(p => p.status === 'doing') || plans[0];

       if (activePlan) {
         await loadPlanDetails(activePlan.id);
       } else {
         data = createEmptyPlanData(projectId, project.name);
         render();
       }
     }
    updateTopBarWithPlan();
    renderConsolidatedProjectMenu();

     // Refresh Gantt view with new project data
     if (typeof GanttView !== 'undefined' && GanttView.load) {
       await GanttView.load(projectId);
     }

     loadGitHubData();
     loadGitData();
     loadTokenData();
     connectGitWatcher(projectId);

     if (typeof initBugTracker === 'function') {
       initBugTracker();
     }

    if (typeof currentView !== 'undefined' && currentView && currentView !== 'dashboard') {
      showView(currentView);
    }
  } catch (e) {
    console.error('Failed to load project plans:', e);
    data = createEmptyPlanData(projectId, project.name);
    render();

    if (typeof initBugList === 'function') {
      initBugList();
    }

    if (typeof currentView !== 'undefined' && currentView && currentView !== 'dashboard') {
      showView(currentView);
    }
  }
  
  // Enable project-dependent navigation items (always after try/catch)
  if (typeof updateNavState === 'function') {
    updateNavState(true);
  }
}
