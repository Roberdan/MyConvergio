// Secondary Views: Bugs, Agents, Tokens Drilldown

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
