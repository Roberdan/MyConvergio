// Kanban Rendering with Drag & Drop

// Drag state
let draggedPlanId = null;
let draggedFromStatus = null;
let kanbanDragInitialized = false;

function initKanbanDragDrop() {
  // Prevent duplicate listeners
  if (kanbanDragInitialized) return;

  ['todo', 'doing', 'done'].forEach(status => {
    const container = document.getElementById(`kanban${status.charAt(0).toUpperCase() + status.slice(1)}`);
    if (!container) {
      console.warn('Kanban container not found:', status);
      return;
    }

    // IMPORTANT: Both dragenter and dragover must preventDefault() to allow drop
    container.addEventListener('dragenter', (e) => {
      e.preventDefault();
      e.stopPropagation();
      container.classList.add('drag-over');
    });

    container.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.stopPropagation();
      e.dataTransfer.dropEffect = 'move';
    });

    container.addEventListener('dragleave', (e) => {
      e.preventDefault();
      if (!container.contains(e.relatedTarget)) {
        container.classList.remove('drag-over');
      }
    });

    container.addEventListener('drop', async (e) => {
      e.preventDefault();
      e.stopPropagation();
      container.classList.remove('drag-over');

      console.log('Drop event:', { draggedPlanId, draggedFromStatus, targetStatus: status });

      if (!draggedPlanId || draggedFromStatus === status) {
        draggedPlanId = null;
        draggedFromStatus = null;
        return;
      }

      try {
        showToast(`Moving plan to ${status}...`, 'info');
        const res = await fetch(`${API_BASE}/plan/${draggedPlanId}/status`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status })
        });
        const result = await res.json();

        if (result.success) {
          showToast(`Plan moved to ${status}`, 'success');
          await loadKanban();
          // Refresh project list to reflect status changes
          await loadProjects();
        } else {
          showToast(result.error || 'Failed to move plan', 'error');
        }
      } catch (err) {
        showToast('Failed to move plan: ' + err.message, 'error');
      }

      draggedPlanId = null;
      draggedFromStatus = null;
    });
  });

  kanbanDragInitialized = true;
  console.log('Kanban drag & drop initialized');
}

function handleKanbanDragStart(e, planId, status) {
  console.log('Drag start:', { planId, status });
  draggedPlanId = planId;
  draggedFromStatus = status;
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', planId);
  }
  if (e.target) {
    e.target.classList.add('dragging');
  }
}

function handleKanbanDragEnd(e) {
  if (e.target) {
    e.target.classList.remove('dragging');
  }
  document.querySelectorAll('.cc-column-cards').forEach(c => c.classList.remove('drag-over'));
}

function renderKanban(kanban) {
  // Update status indicator
  const statusDot = document.getElementById('ccStatusDot');
  const statusText = document.getElementById('ccStatusText');
  const activePlans = kanban.doing?.length || 0;

  if (statusDot && statusText) {
    if (activePlans > 0) {
      statusDot.style.animation = 'pulse 2s infinite';
      statusText.textContent = `${activePlans} MISSION${activePlans > 1 ? 'S' : ''} IN FLIGHT`;
    } else {
      statusDot.style.animation = 'none';
      statusText.textContent = 'ALL SYSTEMS NOMINAL';
    }
  }

  // Update gauges
  updateControlCenterGauges(kanban);

  // Render kanban columns
  ['todo', 'doing', 'done'].forEach(status => {
    const container = document.getElementById(`kanban${status.charAt(0).toUpperCase() + status.slice(1)}`);
    const countEl = document.getElementById(`kanban${status.charAt(0).toUpperCase() + status.slice(1)}Count`);

    if (!container) return;

    const plans = kanban[status] || [];
    if (countEl) countEl.textContent = plans.length;

    if (plans.length === 0) {
      container.innerHTML = '<div class="cc-empty">No missions</div>';
      return;
    }

    container.innerHTML = plans.map(plan => {
      const taskInfo = plan.tasksTotal ? `${plan.tasksDone}/${plan.tasksTotal}` : '0/0';
      const statusDotClass = plan.isRunning ? 'running' : '';

      return `
        <div class="cc-plan-card"
             draggable="true"
             ondragstart="handleKanbanDragStart(event, ${plan.planId}, '${status}')"
             ondragend="handleKanbanDragEnd(event)"
             onclick="activatePlanAndNavigate(${plan.planId}, '${plan.projectId}')">
          <div class="cc-plan-project">${plan.project}</div>
          <div class="cc-plan-name">${plan.name}</div>
          <div class="cc-plan-progress">
            <div class="cc-plan-progress-fill" style="width: ${plan.progress}%"></div>
          </div>
          <div class="cc-plan-meta">
            <span class="cc-plan-tasks">${taskInfo} tasks</span>
            <span class="cc-plan-status">
              <span class="cc-plan-status-dot ${statusDotClass}"></span>
              ${plan.progress}%
            </span>
          </div>
        </div>
      `;
    }).join('');
  });

  // Initialize drag & drop after all columns are rendered
  requestAnimationFrame(initKanbanDragDrop);
}

function updateControlCenterGauges(kanban) {
  const totalPlans = (kanban.todo?.length || 0) + (kanban.doing?.length || 0) + (kanban.done?.length || 0);
  const completedPlans = kanban.done?.length || 0;
  const activePlans = kanban.doing?.length || 0;

  // Completion Rate Gauge
  const completionRate = totalPlans > 0 ? Math.round((completedPlans / totalPlans) * 100) : 0;
  const completionGauge = document.getElementById('gaugeCompletion');
  const completionValue = document.getElementById('gaugeCompletionValue');
  if (completionGauge) {
    const rotation = -90 + (completionRate / 100) * 180;
    completionGauge.style.transform = `rotate(${rotation}deg)`;
  }
  if (completionValue) completionValue.textContent = completionRate + '%';

  // Active Workload Gauge (max 10 for scale)
  const workloadGauge = document.getElementById('gaugeWorkload');
  const workloadValue = document.getElementById('gaugeWorkloadValue');
  const workloadPercent = Math.min(activePlans / 10, 1);
  if (workloadGauge) {
    const rotation = -90 + workloadPercent * 180;
    workloadGauge.style.transform = `rotate(${rotation}deg)`;
  }
  if (workloadValue) workloadValue.textContent = activePlans;

  // Efficiency Score (calculate from completed plans)
  let totalTokens = 0;
  let totalTasks = 0;
  (kanban.done || []).forEach(plan => {
    totalTokens += plan.tokens || 0;
    totalTasks += plan.tasksDone || 0;
  });

  const avgTokensPerTask = totalTasks > 0 ? Math.round(totalTokens / totalTasks) : 0;
  const efficiencyGauge = document.getElementById('gaugeEfficiency');
  const efficiencyValue = document.getElementById('gaugeEfficiencyValue');

  // Scale: < 5000 = excellent, > 50000 = poor
  const efficiencyPercent = avgTokensPerTask > 0 ? Math.max(0, 1 - (avgTokensPerTask - 5000) / 45000) : 0.5;
  if (efficiencyGauge) {
    const rotation = -90 + Math.min(efficiencyPercent, 1) * 180;
    efficiencyGauge.style.transform = `rotate(${rotation}deg)`;
  }
  if (efficiencyValue) {
    efficiencyValue.textContent = avgTokensPerTask > 0 ? (avgTokensPerTask / 1000).toFixed(1) + 'K' : '-';
  }
}

async function activatePlanAndNavigate(planId, projectId) {
  // First select the project
  if (projectId && typeof selectProject === 'function') {
    await selectProject(projectId);
  }
  // Then load the plan details
  if (typeof loadPlanDetails === 'function') {
    await loadPlanDetails(planId);
  }
  // Navigate to dashboard
  showView('dashboard');
}

async function loadBugsView() {
  const content = document.getElementById('bugsContent');
  if (!content) return;

  content.innerHTML = '<div class="bugs-loading">Loading issues...</div>';

  try {
    const projects = await fetch(`${API_BASE}/projects`).then(r => r.json());
    const allIssues = [];
    const allBlockers = [];
    let totalPRs = 0;

    const githubPromises = projects.map(async (project) => {
      try {
        const res = await fetch(`${API_BASE}/project/${project.project_id}/github`);
        const data = await res.json();

        if (data.issues) {
          data.issues.forEach(issue => {
            const isBlocker = issue.labels?.some(l =>
              l.name.toLowerCase().includes('blocker') || l.name.toLowerCase().includes('critical')
            );
            const item = { ...issue, projectName: project.project_name, projectId: project.project_id, repo: data.repo, isBlocker };
            allIssues.push(item);
            if (isBlocker) allBlockers.push(item);
          });
        }
        if (data.prs) totalPRs += data.prs.length;
      } catch (e) {
        console.log('Failed to load GitHub data for:', project.project_id);
      }
    });

    await Promise.all(githubPromises);

    document.getElementById('bugsOpenCount').textContent = allIssues.length;
    document.getElementById('bugsBlockersCount').textContent = allBlockers.length;
    document.getElementById('bugsPrsCount').textContent = totalPRs;

    if (allIssues.length === 0) {
      content.innerHTML = '<div class="bugs-loading">No open issues found</div>';
      return;
    }

    allIssues.sort((a, b) => {
      if (a.isBlocker && !b.isBlocker) return -1;
      if (!a.isBlocker && b.isBlocker) return 1;
      return new Date(b.createdAt) - new Date(a.createdAt);
    });

    content.innerHTML = allIssues.map(issue => {
      const url = `https://github.com/${issue.repo}/issues/${issue.number}`;
      const labels = issue.labels?.map(l => `<span class="bug-label">${l.name}</span>`).join('') || '';
      return `
        <div class="bug-item ${issue.isBlocker ? 'blocker' : ''}" onclick="window.open('${url}', '_blank')">
          <div class="bug-icon ${issue.isBlocker ? 'blocker' : ''}">#${issue.number}</div>
          <div class="bug-content">
            <div class="bug-title">${issue.title}</div>
            <div class="bug-meta">${labels}<span class="bug-project">${issue.projectName}</span></div>
          </div>
        </div>
      `;
    }).join('');
  } catch (e) {
    content.innerHTML = '<div class="bugs-loading">Error: ' + e.message + '</div>';
  }
}

async function loadAgentsView() {
  const grid = document.getElementById('agentsGridView');
  if (!grid) return;

  grid.innerHTML = '<div class="waves-loading">Loading agents...</div>';

  try {
    const res = await fetch(`${API_BASE}/kanban`);
    const plans = await res.json();
    const agentStats = {};

    for (const plan of plans) {
      try {
        const planRes = await fetch(`${API_BASE}/plan/${plan.plan_id}`);
        const planData = await planRes.json();

        if (planData.waves) {
          planData.waves.forEach(wave => {
            if (wave.tasks) {
              wave.tasks.forEach(task => {
                const agent = task.assignee || 'unassigned';
                if (!agentStats[agent]) {
                  agentStats[agent] = { name: agent, totalTasks: 0, doneTasks: 0, inProgressTasks: 0, projects: new Set() };
                }
                agentStats[agent].totalTasks++;
                agentStats[agent].projects.add(plan.project_name);
                if (task.status === 'done') agentStats[agent].doneTasks++;
                if (task.status === 'in_progress') agentStats[agent].inProgressTasks++;
              });
            }
          });
        }
      } catch (e) {
        console.log('Failed to load plan:', plan.plan_id);
      }
    }

    const agents = Object.values(agentStats);
    const totalTasks = agents.reduce((sum, a) => sum + a.totalTasks, 0);
    const activeAgents = agents.filter(a => a.inProgressTasks > 0).length;
    const avgEfficiency = agents.length > 0
      ? Math.round(agents.reduce((sum, a) => sum + (a.totalTasks > 0 ? (a.doneTasks / a.totalTasks) * 100 : 0), 0) / agents.length)
      : 0;

    document.getElementById('agentsTotalTasks').textContent = totalTasks;
    document.getElementById('agentsActiveCount').textContent = activeAgents;
    document.getElementById('agentsAvgEfficiency').textContent = avgEfficiency + '%';

    if (agents.length === 0) {
      grid.innerHTML = '<div class="waves-loading">No agent data available</div>';
      return;
    }

    agents.sort((a, b) => b.doneTasks - a.doneTasks);

    grid.innerHTML = agents.filter(a => a.name !== 'unassigned').map(agent => {
      const efficiency = agent.totalTasks > 0 ? Math.round((agent.doneTasks / agent.totalTasks) * 100) : 0;
      const isActive = agent.inProgressTasks > 0;
      const projectCount = agent.projects.size;

      return `
        <div class="trader-card">
          <div class="trader-top">
            <div class="trader-avatar">${agent.name.charAt(0).toUpperCase()}</div>
            <div class="trader-info">
              <div class="trader-name">${agent.name}</div>
              <div class="trader-followers">${projectCount} project${projectCount !== 1 ? 's' : ''}</div>
            </div>
            <div class="trader-star ${isActive ? '' : 'inactive'}">&#9733;</div>
          </div>
          <div class="trader-profit">+${agent.doneTasks} tasks (${efficiency}%)</div>
          <div class="trader-stats">
            <div class="trader-stat"><div class="trader-stat-label">Total</div><div class="trader-stat-value">${agent.totalTasks}</div></div>
            <div class="trader-stat"><div class="trader-stat-label">Done</div><div class="trader-stat-value">${agent.doneTasks}</div></div>
            <div class="trader-stat"><div class="trader-stat-label">Active</div><div class="trader-stat-value">${agent.inProgressTasks}</div></div>
          </div>
        </div>
      `;
    }).join('');
  } catch (e) {
    grid.innerHTML = '<div class="waves-loading">Error: ' + e.message + '</div>';
  }
}
