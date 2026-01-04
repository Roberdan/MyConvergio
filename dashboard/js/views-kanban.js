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
    const column = document.querySelector(`.cc-kanban-column[data-status="${status}"]`);

    if (!container) {
      console.warn('Kanban container not found:', status);
      return;
    }

    // Handle drop on both container and entire column
    const handleDrop = async (e) => {
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
          await loadProjects();
        } else {
          showToast(result.error || 'Failed to move plan', 'error');
        }
      } catch (err) {
        showToast('Failed to move plan: ' + err.message, 'error');
      }

      draggedPlanId = null;
      draggedFromStatus = null;
    };

    // Listeners for cards container
    container.addEventListener('dragenter', (e) => {
      e.preventDefault();
      e.stopPropagation();
      container.classList.add('drag-over');
    });

    container.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.stopPropagation();
      e.dataTransfer.dropEffect = 'move';
      container.classList.add('drag-over');
    });

    container.addEventListener('dragleave', (e) => {
      e.preventDefault();
      if (!container.contains(e.relatedTarget)) {
        container.classList.remove('drag-over');
      }
    });

    container.addEventListener('drop', handleDrop);

    // Also handle drop on entire column (including header)
    if (column) {
      column.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        container.classList.add('drag-over');
      });

      column.addEventListener('dragleave', (e) => {
        if (!column.contains(e.relatedTarget)) {
          container.classList.remove('drag-over');
        }
      });

      column.addEventListener('drop', handleDrop);
    }
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

  // Update gauges and status
  updateControlCenterGauges(kanban);
  updateSystemStatus(kanban);

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

  // Check if project is selected
  if (!currentProjectId) {
    content.innerHTML = '<div class="cc-empty">Select a project to view issues</div>';
    document.getElementById('bugsOpenCount').textContent = '0';
    document.getElementById('bugsBlockersCount').textContent = '0';
    document.getElementById('bugsPrsCount').textContent = '0';
    return;
  }

  content.innerHTML = '<div class="bugs-loading">Loading issues...</div>';

  try {
    const allIssues = [];
    const allBlockers = [];
    let totalPRs = 0;

    // Only load GitHub data for the current project
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/github`);
    const data = await res.json();
    const projectName = registry?.projects?.[currentProjectId]?.name || currentProjectId;

    if (data.issues) {
      data.issues.forEach(issue => {
        const isBlocker = issue.labels?.some(l =>
          l.name.toLowerCase().includes('blocker') || l.name.toLowerCase().includes('critical')
        );
        const item = { ...issue, projectName, projectId: currentProjectId, repo: data.repo, isBlocker };
        allIssues.push(item);
        if (isBlocker) allBlockers.push(item);
      });
    }
    if (data.prs) totalPRs = data.prs.length;

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

  // Check if project is selected
  if (!currentProjectId) {
    grid.innerHTML = '<div class="cc-empty">Select a project to view agents</div>';
    document.getElementById('agentsTotalTasks').textContent = '0';
    document.getElementById('agentsActiveCount').textContent = '0';
    document.getElementById('agentsAvgEfficiency').textContent = '0%';
    return;
  }

  grid.innerHTML = '<div class="waves-loading">Loading agents...</div>';

  try {
    // Only load plans for the current project
    const res = await fetch(`${API_BASE}/plans/${currentProjectId}`);
    const plans = await res.json();
    const agentStats = {};

    const projectName = registry?.projects?.[currentProjectId]?.name || currentProjectId;

    for (const plan of plans) {
      try {
        const planRes = await fetch(`${API_BASE}/plan/${plan.id}`);
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
                agentStats[agent].projects.add(projectName);
                if (task.status === 'done') agentStats[agent].doneTasks++;
                if (task.status === 'in_progress') agentStats[agent].inProgressTasks++;
              });
            }
          });
        }
      } catch (e) {
        console.log('Failed to load plan:', plan.id);
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

// Status indicator functions
function toggleStatusDropdown() {
  const dropdown = document.getElementById('ccStatusDropdown');
  if (dropdown) {
    dropdown.classList.toggle('show');
  }
}

// Close dropdown when clicking outside
document.addEventListener('click', (e) => {
  const dropdown = document.getElementById('ccStatusDropdown');
  const indicator = e.target.closest('.cc-status-indicator');
  if (dropdown && !indicator) {
    dropdown.classList.remove('show');
  }
});

function updateSystemStatus(kanban) {
  const icon = document.getElementById('ccStatusIcon');
  const activePlans = kanban.doing?.length || 0;
  const blockedTasks = 0; // TODO: get from API if available
  const openIssues = 0; // TODO: get from API if available

  // Update counts in dropdown
  const activeEl = document.querySelector('#statusActivePlans .cc-status-count');
  const blockedEl = document.querySelector('#statusBlockedTasks .cc-status-count');
  const issuesEl = document.querySelector('#statusOpenIssues .cc-status-count');

  if (activeEl) activeEl.textContent = activePlans;
  if (blockedEl) blockedEl.textContent = blockedTasks;
  if (issuesEl) issuesEl.textContent = openIssues;

  // Update dots
  const activeDot = document.querySelector('#statusActivePlans .cc-status-dot');
  const blockedDot = document.querySelector('#statusBlockedTasks .cc-status-dot');
  const issuesDot = document.querySelector('#statusOpenIssues .cc-status-dot');

  if (activeDot) {
    activeDot.className = 'cc-status-dot ' + (activePlans > 0 ? 'green' : 'gray');
  }
  if (blockedDot) {
    blockedDot.className = 'cc-status-dot ' + (blockedTasks > 0 ? 'orange' : 'gray');
  }
  if (issuesDot) {
    issuesDot.className = 'cc-status-dot ' + (openIssues > 5 ? 'red' : openIssues > 0 ? 'orange' : 'gray');
  }

  // Update main icon color
  if (icon) {
    icon.className = 'cc-status-icon';
    if (blockedTasks > 0 || openIssues > 5) {
      icon.classList.add('error');
    } else if (openIssues > 0) {
      icon.classList.add('warning');
    }
    // Default is green (no class added)
  }
}

// Metric drill-down functions
function scrollToKanban(status) {
  const kanbanSection = document.querySelector('.cc-kanban');
  if (kanbanSection) {
    kanbanSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // Highlight specific column if status provided
  if (status) {
    const column = document.querySelector(`.cc-kanban-column[data-status="${status}"]`);
    if (column) {
      column.classList.add('highlight-pulse');
      setTimeout(() => column.classList.remove('highlight-pulse'), 2000);
    }
  }
}

function openProjectMenu() {
  const menu = document.getElementById('projectMenu');
  if (menu) {
    menu.style.display = menu.style.display === 'none' ? 'block' : 'none';
  }
}

function showTokensBreakdown() {
  // Show a modal/panel with tokens breakdown by project
  const modal = document.createElement('div');
  modal.className = 'cc-tokens-modal';
  modal.innerHTML = `
    <div class="cc-tokens-content">
      <div class="cc-tokens-header">
        <span>Tokens & Cost Breakdown</span>
        <button onclick="this.closest('.cc-tokens-modal').remove()">×</button>
      </div>
      <div class="cc-tokens-body" id="tokensBreakdownBody">
        <div class="waves-loading">Loading...</div>
      </div>
    </div>
  `;
  document.body.appendChild(modal);

  // Load token data for all projects
  loadTokensBreakdown();
}

async function loadTokensBreakdown() {
  const body = document.getElementById('tokensBreakdownBody');
  if (!body) return;

  try {
    const res = await fetch(`${API_BASE}/kanban`);
    const plans = await res.json();

    const projectIds = [...new Set(plans.map(p => p.project_id))];
    const projectData = [];

    for (const projectId of projectIds) {
      try {
        const tokRes = await fetch(`${API_BASE}/project/${projectId}/tokens`);
        const tokData = await tokRes.json();
        const project = plans.find(p => p.project_id === projectId);
        projectData.push({
          name: project?.project_name || projectId,
          projectId,
          tokens: tokData.stats?.total_tokens || 0,
          cost: tokData.stats?.total_cost || 0
        });
      } catch (e) {
        console.log('Failed to load tokens for', projectId);
      }
    }

    projectData.sort((a, b) => b.tokens - a.tokens);

    if (projectData.length === 0) {
      body.innerHTML = '<div class="cc-empty">No token data available</div>';
      return;
    }

    body.innerHTML = projectData.map(p => `
      <div class="cc-tokens-row" onclick="selectProject('${p.projectId}'); document.querySelector('.cc-tokens-modal').remove();">
        <div class="cc-tokens-project">${p.name}</div>
        <div class="cc-tokens-stats">
          <span class="cc-tokens-value">${p.tokens.toLocaleString()} tokens</span>
          <span class="cc-tokens-cost">$${p.cost.toFixed(2)}</span>
        </div>
      </div>
    `).join('');
  } catch (e) {
    body.innerHTML = '<div class="cc-empty">Error loading data</div>';
  }
}
