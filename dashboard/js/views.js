// View Management and Switching

function showView(view) {
  currentView = view;

  // Close diff view if open
  if (typeof closeDiffView === 'function') closeDiffView();

  // Update nav menu
  document.querySelectorAll('.nav-menu a').forEach(a => {
    a.classList.remove('active');
    const linkText = a.textContent.toLowerCase();
    if (linkText.includes(view) || (view === 'issues' && linkText.includes('issues'))) {
      a.classList.add('active');
    }
  });

  // View elements
  const dashboardElements = ['wavesSummary', 'drilldownPanel'];
  const chartCard = document.querySelector('.chart-card');
  const tradersSection = document.querySelector('.traders-section');
  const kanbanView = document.getElementById('kanbanView');
  const wavesView = document.getElementById('wavesView');
  const bugsView = document.getElementById('bugsView');
  const agentsView = document.getElementById('agentsView');
  const notificationsView = document.getElementById('notificationsView');
  const statsHeader = document.querySelector('.stats-header');
  const statsRow = document.querySelector('.stats-row');
  const waveIndicator = document.querySelector('.wave-indicator');

  // Sidebars for full-page views
  const gitPanel = document.querySelector('.git-panel');
  const rightPanel = document.querySelector('.right-panel');
  const mainWrap = document.querySelector('.main-wrap');
  const mainContent = document.querySelector('.main-content');
  const isFullPageView = view === 'kanban';

  // Hide all views
  [kanbanView, wavesView, bugsView, agentsView, notificationsView].forEach(v => {
    if (v) v.style.display = 'none';
  });

  // Hide/show dashboard elements
  const hideDashboard = view !== 'dashboard';
  dashboardElements.forEach(id => {
    const el = document.getElementById(id);
    if (el) el.style.display = hideDashboard ? 'none' : '';
  });
  if (chartCard) chartCard.style.display = hideDashboard ? 'none' : '';
  if (tradersSection) tradersSection.style.display = hideDashboard ? 'none' : '';
  if (statsHeader) statsHeader.style.display = hideDashboard ? 'none' : '';
  if (statsRow) statsRow.style.display = hideDashboard ? 'none' : '';
  if (waveIndicator) waveIndicator.style.display = hideDashboard ? 'none' : '';

  // Full-page mode: hide sidebars
  if (gitPanel) gitPanel.style.display = isFullPageView ? 'none' : '';
  if (rightPanel) rightPanel.style.display = isFullPageView ? 'none' : '';
  if (mainContent) mainContent.classList.toggle('full-width', isFullPageView);
  if (mainWrap) mainWrap.style.padding = isFullPageView ? '0' : '';

  // Show selected view
  switch (view) {
    case 'kanban':
      if (kanbanView) kanbanView.style.display = 'block';
      loadKanban();
      break;
    case 'waves':
      if (wavesView) wavesView.style.display = 'block';
      loadWavesView();
      break;
    case 'issues':
    case 'bugs':
      if (bugsView) bugsView.style.display = 'block';
      loadBugsView();
      break;
    case 'agents':
      if (agentsView) agentsView.style.display = 'block';
      loadAgentsView();
      break;
    case 'notifications':
      if (notificationsView) notificationsView.style.display = 'block';
      loadNotificationsView();
      break;
    case 'dashboard':
    default:
      if (chartMode === 'tokens') {
        destroyCharts();
        renderTokenChart();
        renderAgents();
      }
      break;
  }
}

async function loadKanban() {
  const kanban = { todo: [], doing: [], done: [] };
  let totalTokens = 0;
  let totalCost = 0;
  const projectIds = new Set();

  try {
    const res = await fetch(`${API_BASE}/kanban`);
    const plans = await res.json();

    plans.forEach(plan => projectIds.add(plan.project_id));

    const tokenPromises = Array.from(projectIds).map(async (projectId) => {
      try {
        const tokRes = await fetch(`${API_BASE}/project/${projectId}/tokens`);
        const tokData = await tokRes.json();
        return { projectId, tokens: tokData.stats?.total_tokens || 0, cost: tokData.stats?.total_cost || 0 };
      } catch (e) {
        return { projectId, tokens: 0, cost: 0 };
      }
    });

    const tokenResults = await Promise.all(tokenPromises);
    const tokensByProject = {};
    tokenResults.forEach(t => {
      tokensByProject[t.projectId] = t;
      totalTokens += t.tokens;
      totalCost += t.cost;
    });

    plans.forEach(plan => {
      const status = plan.status || 'todo';
      const projectTokens = tokensByProject[plan.project_id] || { tokens: 0, cost: 0 };
      const updatedAt = plan.completed_at || plan.started_at || plan.created_at;
      const lastUpdate = updatedAt ? new Date(updatedAt) : null;
      const isRecent = lastUpdate && (Date.now() - lastUpdate.getTime()) < 3600000;
      const isRunning = status === 'doing' && isRecent;

      kanban[status].push({
        project: plan.project_name,
        projectId: plan.project_id,
        planId: plan.plan_id,
        name: plan.plan_name,
        isMaster: plan.is_master,
        progress: plan.progress || 0,
        tasksDone: plan.tasks_done || 0,
        tasksTotal: plan.tasks_total || 0,
        startedAt: plan.started_at,
        completedAt: plan.completed_at,
        updatedAt: updatedAt,
        isRunning: isRunning,
        tokens: projectTokens.tokens,
        cost: projectTokens.cost,
        validatedBy: plan.validated_by,
        validatedAt: plan.validated_at
      });
    });
  } catch (e) {
    console.error('Failed to load kanban from API:', e);
    if (!registry) await loadProjects();
    for (const [projectId, project] of Object.entries(registry.projects || {})) {
      projectIds.add(projectId);
      if (project.plans_doing > 0) {
        kanban.doing.push({ project: project.name, projectId, name: 'Active plan', progress: 50 });
      }
      if (project.plans_todo > 0) {
        kanban.todo.push({ project: project.name, projectId, name: 'Pending plan', progress: 0 });
      }
      if (project.plans_done > 0) {
        kanban.done.push({ project: project.name, projectId, name: 'Completed plan', progress: 100 });
      }
    }
  }

  document.getElementById('kanbanTotalProjects').textContent = projectIds.size;
  document.getElementById('kanbanTotalPlans').textContent = kanban.todo.length + kanban.doing.length + kanban.done.length;
  document.getElementById('kanbanActivePlans').textContent = kanban.doing.length;
  document.getElementById('kanbanCompletedPlans').textContent = kanban.done.length;
  document.getElementById('kanbanTotalTokens').textContent = totalTokens ? totalTokens.toLocaleString() : '0';
  document.getElementById('kanbanTotalCost').textContent = totalCost ? '$' + totalCost.toFixed(2) : '$0';

  renderKanban(kanban);
}

async function loadWavesView() {
  const content = document.getElementById('wavesViewContent');
  if (!content) return;

  // Check if project is selected
  if (!currentProjectId) {
    content.innerHTML = '<div class="cc-empty">Select a project to view waves</div>';
    return;
  }

  content.innerHTML = '<div class="waves-loading">Loading waves...</div>';

  try {
    // Only load plans for the current project
    const res = await fetch(`${API_BASE}/plans/${currentProjectId}`);
    const plans = await res.json();
    const allWaves = [];

    for (const plan of plans) {
      try {
        const planRes = await fetch(`${API_BASE}/plan/${plan.id}`);
        const planData = await planRes.json();
        if (planData.waves) {
          planData.waves.forEach(wave => {
            allWaves.push({
              ...wave,
              projectName: registry?.projects?.[currentProjectId]?.name || currentProjectId,
              projectId: currentProjectId,
              planName: plan.name,
              planId: plan.id
            });
          });
        }
      } catch (e) {
        console.log('Failed to load plan:', plan.id);
      }
    }

    allWaves.sort((a, b) => {
      const order = { 'in_progress': 0, 'pending': 1, 'done': 2 };
      return (order[a.status] || 3) - (order[b.status] || 3);
    });

    if (allWaves.length === 0) {
      content.innerHTML = '<div class="cc-empty">No waves in this project</div>';
      return;
    }

    content.innerHTML = allWaves.map(wave => {
      const progress = wave.tasks_total > 0 ? Math.round((wave.tasks_done / wave.tasks_total) * 100) : 0;
      return `
        <div class="wave-timeline-item" onclick="loadPlanDetails(${wave.planId}); showView('dashboard'); drillIntoWave('${wave.wave_id}');">
          <div class="wave-timeline-status ${wave.status}"></div>
          <div class="wave-timeline-content">
            <div class="wave-timeline-header">
              <span class="wave-timeline-title">${wave.wave_id} - ${wave.name}</span>
              <span class="wave-timeline-project">${wave.planName}</span>
            </div>
            <div class="wave-timeline-progress">
              <div class="wave-timeline-progress-fill" style="width: ${progress}%"></div>
            </div>
            <div class="wave-timeline-meta">
              <span>Tasks: ${wave.tasks_done || 0}/${wave.tasks_total || 0}</span>
              <span>${wave.status}</span>
            </div>
          </div>
        </div>
      `;
    }).join('');
  } catch (e) {
    content.innerHTML = '<div class="cc-empty">Error: ' + e.message + '</div>';
  }
}
