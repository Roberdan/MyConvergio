// Project Management

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
    renderProjectList();
  } catch (e) {
    console.log('API not available, trying registry.json fallback');
    try {
      const res = await fetch('../plans/registry.json');
      registry = await res.json();
      renderProjectList();
    } catch (e2) {
      console.log('No registry found');
      registry = { projects: {} };
    }
  }
}

function renderProjectList() {
  const list = document.getElementById('projectList');
  if (!list || !registry) return;

  const allProjects = Object.entries(registry.projects || {});

  // Filter: only show projects with active (doing) or pending (todo) plans
  const activeProjects = allProjects.filter(([id, p]) => p.plans_doing > 0 || p.plans_todo > 0);

  if (activeProjects.length === 0) {
    list.innerHTML = '<div class="project-loading">No active projects</div>';
    return;
  }

  // Sort: doing projects first, then todo
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

  // Show sidebars when a project is selected
  const gitPanel = document.querySelector('.git-panel');
  const rightPanel = document.querySelector('.right-panel');
  if (gitPanel) gitPanel.style.display = '';
  if (rightPanel) rightPanel.style.display = '';

  document.getElementById('projectName').textContent = project.name;
  const dot = document.getElementById('projectDot');
  if (dot) dot.style.background = '#22c55e';

  // Update project avatar from GitHub if available
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

  document.getElementById('projectMenu').style.display = 'none';

  try {
    const res = await fetch(`${API_BASE}/plans/${projectId}`);
    const plans = await res.json();
    const activePlan = plans.find(p => p.status === 'doing') || plans[0];

    if (activePlan) {
      await loadPlanDetails(activePlan.id);
    } else {
      data = createEmptyPlanData(projectId, project.name);
      render();
    }
    renderProjectList();

    loadGitHubData();
    loadGitData();
    loadTokenData();
    connectGitWatcher(projectId);
  } catch (e) {
    console.error('Failed to load project plans:', e);
    try {
      const res = await fetch('plan.json');
      data = await res.json();
      render();
    } catch (e2) {
      data = createEmptyPlanData(projectId, project.name);
      render();
    }
  }
}

async function loadPlanDetails(planId) {
  try {
    const res = await fetch(`${API_BASE}/plan/${planId}`);
    const plan = await res.json();

    if (plan.error) {
      console.error('Plan not found:', planId);
      return;
    }

    data = transformPlanToData(plan);
    render();
    updateNavCounts(); // Update nav after loading plan data

    const histRes = await fetch(`${API_BASE}/plan/${planId}/history`);
    const history = await histRes.json();
    data.history = history;
    renderHistory();
  } catch (e) {
    console.error('Failed to load plan details:', e);
  }
}

function transformPlanToData(plan) {
  const now = new Date().toISOString();
  const waves = plan.waves || [];

  return {
    meta: {
      project: plan.name,
      project_id: plan.project_id,
      plan_id: plan.id,
      owner: plan.validated_by || 'planner',
      created: plan.created_at,
      updated: plan.started_at || plan.created_at
    },
    metrics: {
      throughput: {
        done: plan.tasks_done || 0,
        total: plan.tasks_total || 1,
        percent: plan.tasks_total > 0 ? Math.round(100 * plan.tasks_done / plan.tasks_total) : 0
      },
      velocity: { value: '2.5' },
      cycleTime: { value: '45' },
      quality: { score: 95 }
    },
    bugs: { fixed: 0, total: 0 },
    timeline: {
      start: plan.started_at || plan.created_at || now,
      eta: plan.completed_at || now,
      remaining: plan.status === 'done' ? 'Done' : 'In progress',
      data: generateTimelineData(plan.tasks_done, plan.tasks_total)
    },
    waves: waves.map(w => ({
      id: w.wave_id,
      wave_id: w.wave_id,
      name: w.name,
      status: w.status === 'pending' ? 'pending' : w.status === 'in_progress' ? 'in_progress' : 'done',
      done: w.tasks_done || 0,
      total: w.tasks_total || 0,
      tasks_done: w.tasks_done || 0,
      tasks_total: w.tasks_total || 0,
      planned_start: w.planned_start,
      planned_end: w.planned_end,
      started_at: w.started_at,
      completed_at: w.completed_at,
      depends_on: w.depends_on,
      estimated_hours: w.estimated_hours || 8,
      tasks: (w.tasks || []).map(t => ({
        id: t.task_id,
        title: t.title,
        status: t.status,
        assignee: t.assignee,
        priority: t.priority,
        type: t.type,
        files: t.files ? t.files.split(',') : [],
        notes: t.notes,
        timing: {
          started: t.started_at,
          completed: t.completed_at,
          duration: t.duration_minutes
        }
      }))
    })),
    contributors: [
      { id: 'planner', name: 'Planner', avatar: 'P', role: 'planning', tasks: 0, status: 'idle' },
      { id: 'executor', name: 'Executor', avatar: 'E', role: 'execution', tasks: plan.tasks_done || 0, status: plan.status === 'doing' ? 'active' : 'idle' },
      { id: 'thor', name: 'Thor', avatar: 'T', role: 'validation', tasks: plan.validated_at ? 1 : 0, status: plan.validated_at ? 'done' : 'pending' }
    ],
    history: []
  };
}

function generateTimelineData(done, total) {
  const data = [];
  const steps = 8;
  for (let i = 0; i <= steps; i++) {
    const progress = Math.round((done / Math.max(total, 1)) * (i / steps) * total);
    data.push({
      time: `T${i}`,
      done: progress,
      target: Math.round((i / steps) * total)
    });
  }
  return data;
}

function createEmptyPlanData(projectId, projectName) {
  return {
    meta: { project: projectName, project_id: projectId, owner: 'none' },
    metrics: {
      throughput: { done: 0, total: 0, percent: 0 },
      velocity: { value: '0' },
      cycleTime: { value: '0' },
      quality: { score: 0 }
    },
    bugs: { fixed: 0, total: 0 },
    timeline: { start: new Date().toISOString(), eta: new Date().toISOString(), remaining: 'No plan', data: [] },
    waves: [],
    contributors: [],
    history: []
  };
}

function toggleProjectMenu() {
  const menu = document.getElementById('projectMenu');
  if (menu) {
    menu.style.display = menu.style.display === 'none' ? 'block' : 'none';
  }
}

async function refreshProjects() {
  await loadProjects();
}

function showLearningStats() {
  const stats = {
    totalPlans: Object.keys(registry?.projects || {}).length,
    message: 'Learning stats will show plan modification patterns and optimization insights.'
  };
  alert(`Learning Stats\n\nTotal Projects: ${stats.totalPlans}\n\n${stats.message}`);
}

function extractGitHubOwner(githubUrl) {
  if (!githubUrl) return null;
  // Handle URLs like https://github.com/owner/repo or git@github.com:owner/repo
  const match = githubUrl.match(/github\.com[/:]([\w-]+)/);
  return match ? match[1] : null;
}

// Close project menu when clicking outside
document.addEventListener('click', (e) => {
  const menu = document.getElementById('projectMenu');
  const logo = document.querySelector('.logo');
  if (menu && !menu.contains(e.target) && !logo.contains(e.target)) {
    menu.style.display = 'none';
  }
});
