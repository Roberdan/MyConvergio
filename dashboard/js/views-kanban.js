// Kanban Rendering with Drag & Drop

// Drag state
let draggedPlanId = null;
let draggedFromStatus = null;

function initKanbanDragDrop() {
  ['todo', 'doing', 'done'].forEach(status => {
    const container = document.getElementById(`kanban${status.charAt(0).toUpperCase() + status.slice(1)}`);
    if (!container) return;

    container.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      container.classList.add('drag-over');
    });

    container.addEventListener('dragleave', (e) => {
      // Only remove if leaving the container entirely
      if (!container.contains(e.relatedTarget)) {
        container.classList.remove('drag-over');
      }
    });

    container.addEventListener('drop', async (e) => {
      e.preventDefault();
      container.classList.remove('drag-over');

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
}

function handleKanbanDragStart(e, planId, status) {
  draggedPlanId = planId;
  draggedFromStatus = status;
  e.dataTransfer.effectAllowed = 'move';
  e.dataTransfer.setData('text/plain', planId);
  e.target.classList.add('dragging');
}

function handleKanbanDragEnd(e) {
  e.target.classList.remove('dragging');
  document.querySelectorAll('.kanban-cards').forEach(c => c.classList.remove('drag-over'));
}

function renderKanban(kanban) {
  ['todo', 'doing', 'done'].forEach(status => {
    const container = document.getElementById(`kanban${status.charAt(0).toUpperCase() + status.slice(1)}`);
    const countEl = document.getElementById(`kanban${status.charAt(0).toUpperCase() + status.slice(1)}Count`);

    if (!container) return;

    const plans = kanban[status] || [];
    if (countEl) countEl.textContent = plans.length;

    if (plans.length === 0) {
      container.innerHTML = '<div class="kanban-empty">No plans</div>';
      return;
    }

    container.innerHTML = plans.map(plan => {
      const masterBadge = plan.isMaster ? '<span class="kanban-master-badge">MASTER</span>' : '';
      const taskInfo = plan.tasksTotal ? `${plan.tasksDone}/${plan.tasksTotal}` : '';

      let updatedStr = '';
      if (plan.updatedAt) {
        const updated = new Date(plan.updatedAt);
        const diffMs = Date.now() - updated;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 60) updatedStr = diffMins + 'm ago';
        else if (diffHours < 24) updatedStr = diffHours + 'h ago';
        else updatedStr = diffDays + 'd ago';
      }

      let runningIndicator = '';
      if (status === 'doing') {
        runningIndicator = plan.isRunning
          ? '<span class="kanban-running-indicator active">Running</span>'
          : '<span class="kanban-running-indicator stopped">Paused</span>';
      }

      const tokenStr = plan.tokens ? plan.tokens.toLocaleString() : '0';

      let statsSection = '';
      if (status === 'done' && plan.completedAt) {
        const duration = plan.startedAt
          ? Math.ceil((new Date(plan.completedAt) - new Date(plan.startedAt)) / 86400000)
          : '-';
        const avgTokensPerTask = plan.tasksDone > 0 && plan.tokens > 0
          ? Math.round(plan.tokens / plan.tasksDone).toLocaleString()
          : '-';

        statsSection = `
          <div class="kanban-card-stats">
            <div class="kanban-card-stats-item">
              <span class="kanban-card-stats-value">${plan.tasksDone}</span>
              <span class="kanban-card-stats-label">Tasks</span>
            </div>
            <div class="kanban-card-stats-item">
              <span class="kanban-card-stats-value">${duration}d</span>
              <span class="kanban-card-stats-label">Duration</span>
            </div>
            <div class="kanban-card-stats-item">
              <span class="kanban-card-stats-value">${avgTokensPerTask}</span>
              <span class="kanban-card-stats-label">Tok/Task</span>
            </div>
            ${plan.validatedBy ? `
            <div class="kanban-card-stats-item">
              <span class="kanban-card-stats-value">${plan.validatedBy}</span>
              <span class="kanban-card-stats-label">Validated</span>
            </div>` : ''}
          </div>
        `;
      }

      return `
        <div class="kanban-card ${plan.isMaster ? 'master' : ''}"
             draggable="true"
             ondragstart="handleKanbanDragStart(event, ${plan.planId}, '${status}')"
             ondragend="handleKanbanDragEnd(event)"
             onclick="loadPlanDetails(${plan.planId}); showView('dashboard');">
          <div class="kanban-card-header">
            <span class="kanban-card-project">${plan.project}</span>
            ${masterBadge}
          </div>
          <div class="kanban-card-status">${runningIndicator}</div>
          <div class="kanban-card-title">${plan.name}</div>
          <div class="kanban-card-meta">
            <span>${plan.progress}%</span>
            <span>${taskInfo}</span>
          </div>
          <div class="kanban-card-progress">
            <div class="kanban-card-progress-fill" style="width: ${plan.progress}%"></div>
          </div>
          <div class="kanban-card-tokens">
            <span class="token-icon">&#x1F4B0;</span>
            <span>${tokenStr} tokens</span>
          </div>
          ${updatedStr ? `<div class="kanban-card-updated">Updated ${updatedStr}</div>` : ''}
          ${statsSection}
        </div>
      `;
    }).join('');

    // Initialize drag & drop after first render
    if (status === 'done') {
      setTimeout(initKanbanDragDrop, 0);
    }
  });
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
