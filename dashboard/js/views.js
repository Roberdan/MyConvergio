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
    // Load all waves for the current project
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/dashboard`);
    const projectData = await res.json();

    if (!projectData.waves || projectData.waves.length === 0) {
      content.innerHTML = '<div class="cc-empty">No waves in this project</div>';
      return;
    }

    // Render Gantt in the waves view
    renderWavesGanttInContainer(projectData.waves, content);
  } catch (e) {
    content.innerHTML = '<div class="cc-empty">Error: ' + e.message + '</div>';
  }
}

// Render Gantt in a specific container
function renderWavesGanttInContainer(waves, container) {
  if (!waves || waves.length === 0) {
    container.innerHTML = '<div class="waves-empty">No waves available</div>';
    return;
  }

  const now = new Date();
  let minDate = null;
  let maxDate = null;

  waves.forEach(wave => {
    const start = wave.planned_start ? new Date(wave.planned_start) : null;
    const end = wave.planned_end ? new Date(wave.planned_end) : null;
    if (start && (!minDate || start < minDate)) minDate = start;
    if (end && (!maxDate || end > maxDate)) maxDate = end;
  });

  if (!minDate) minDate = new Date(now.getTime() - 86400000);
  if (!maxDate) maxDate = new Date(now.getTime() + 7 * 86400000);

  const dataRange = maxDate - minDate;
  const dynamicPadding = Math.max(30 * 60000, Math.min(6 * 3600000, dataRange * 0.15));
  minDate = new Date(minDate.getTime() - dynamicPadding);
  maxDate = new Date(maxDate.getTime() + dynamicPadding);

  const totalMs = maxDate - minDate;
  const totalDays = Math.ceil(totalMs / 86400000);
  const totalHours = totalMs / 3600000;

  // Smart header intervals based on total time range
  const headers = [];
  let interval, formatOpts;

  if (totalHours <= 3) {
    interval = 30 * 60000;
    formatOpts = { hour: '2-digit', minute: '2-digit' };
  } else if (totalHours <= 8) {
    interval = 3600000;
    formatOpts = { hour: '2-digit', minute: '2-digit' };
  } else if (totalDays <= 2) {
    interval = 3 * 3600000;
    formatOpts = { month: 'short', day: 'numeric', hour: '2-digit' };
  } else if (totalDays <= 7) {
    interval = 6 * 3600000;
    formatOpts = { month: 'short', day: 'numeric', hour: '2-digit' };
  } else {
    interval = 86400000;
    formatOpts = { month: 'short', day: 'numeric' };
  }

  for (let t = minDate.getTime(); t <= maxDate.getTime(); t += interval) {
    const d = new Date(t);
    headers.push({
      label: d.toLocaleString('en-US', formatOpts),
      time: t
    });
  }

  const todayPos = ((now - minDate) / totalMs) * 100;
  const showToday = todayPos >= 0 && todayPos <= 100;

  container.innerHTML = `
    <div class="gantt-container">
      <div class="gantt-header">
        <div class="gantt-header-label">WAVE</div>
        <div class="gantt-header-timeline">
          ${headers.map(h => `<div class="gantt-header-day">${h.label}</div>`).join('')}
        </div>
      </div>
      <div class="gantt-body">
        ${showToday ? `<div class="gantt-today-marker" style="left:calc(200px + ${todayPos}% * (100% - 200px - 180px) / 100);" title="Today"></div>` : ''}
        ${waves.map(wave => {
          const start = wave.planned_start ? new Date(wave.planned_start) : null;
          const end = wave.planned_end ? new Date(wave.planned_end) : null;
          const actual_start = wave.started_at ? new Date(wave.started_at) : null;
          const actual_end = wave.completed_at ? new Date(wave.completed_at) : null;

          let plannedLeft = 0, plannedWidth = 5;
          if (start && end) {
            plannedLeft = ((start - minDate) / totalMs) * 100;
            plannedWidth = Math.max(2, ((end - start) / totalMs) * 100);
          }

          let actualLeft = plannedLeft, actualWidth = 0;
          if (actual_start) {
            actualLeft = ((actual_start - minDate) / totalMs) * 100;
            const actualEndTime = actual_end || now;
            actualWidth = Math.max(1, ((actualEndTime - actual_start) / totalMs) * 100);
          }

          const progress = wave.tasks_total > 0 ? Math.round((wave.tasks_done / wave.tasks_total) * 100) : 0;
          const startStr = start ? start.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'Not planned';
          const endStr = end ? end.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'Not planned';
          const hasDeps = wave.depends_on && wave.depends_on.length > 0;

          return `
            <div class="gantt-row" onclick="drillIntoWave('${wave.wave_id}')" title="${wave.name}&#10;Start: ${startStr}&#10;End: ${endStr}&#10;Progress: ${progress}%">
              <div class="gantt-label">
                <div class="gantt-label-status ${wave.status}"></div>
                <div class="gantt-label-info">
                  <div class="gantt-label-header">
                    <span class="gantt-label-text">${wave.wave_id}</span>
                    ${hasDeps ? `<span class="gantt-dep-badge" title="Depends on: ${wave.depends_on}">&#x2192; ${wave.depends_on}</span>` : ''}
                    <button class="gantt-markdown-btn" onclick="event.stopPropagation(); showWaveMarkdown('${wave.wave_id}')" title="View wave documentation">
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M22.27 19.385H1.73A1.73 1.73 0 0 1 0 17.655V6.345a1.73 1.73 0 0 1 1.73-1.73h20.54A1.73 1.73 0 0 1 24 6.345v11.308a1.73 1.73 0 0 1-1.73 1.731zM5.769 15.923v-4.5l2.308 2.885 2.307-2.885v4.5h2.308V8.078h-2.308l-2.307 2.885-2.308-2.885H3.46v7.847zM21.232 12h-2.309V8.077h-2.307V12h-2.308l3.461 4.039z"/>
                      </svg>
                    </button>
                  </div>
                  <div class="gantt-label-summary" title="${wave.name}">${wave.name}</div>
                </div>
              </div>
              <div class="gantt-timeline">
                ${start && end ? `
                  <div class="gantt-bar planned ${wave.status}" style="left:${plannedLeft}%;width:${plannedWidth}%;">
                    <div class="gantt-bar-progress" style="width:${progress}%"></div>
                    <span class="gantt-bar-label">${wave.tasks_done}/${wave.tasks_total}</span>
                  </div>
                ` : `<div class="gantt-no-dates">No dates</div>`}
                ${actual_start && wave.status !== 'done' ? `
                  <div class="gantt-bar actual" style="left:${actualLeft}%;width:${actualWidth}%;"></div>
                ` : ''}
              </div>
              <div class="gantt-dates">
                <span class="gantt-date-start">${startStr}</span>
                <span class="gantt-date-end">${endStr}</span>
              </div>
            </div>
          `;
        }).join('')}
      </div>
    </div>
  `;
}
