// Voltrex-style Plan Dashboard - Pixel Perfect (Multi-Project V3)
let data = null;
let mainChart = null;
let sparkCharts = [];
let registry = null;
let currentProjectId = null;

// Theme colors for ApexCharts
const themeColors = {
  voltrex: { line: '#f7931a', accent: '#22c55e', grid: 'rgba(139, 92, 246, 0.08)', text: '#6b7280' },
  midnight: { line: '#2dd4bf', accent: '#38bdf8', grid: 'rgba(56, 189, 248, 0.08)', text: '#64748b' },
  frost: { line: '#3b82f6', accent: '#059669', grid: 'rgba(71, 85, 105, 0.1)', text: '#64748b' },
  dawn: { line: '#f59e0b', accent: '#16a34a', grid: 'rgba(180, 83, 9, 0.08)', text: '#78716c' }
};

function initTheme() {
  const saved = localStorage.getItem('dashboard-theme') || 'voltrex';
  document.documentElement.setAttribute('data-theme', saved);
  document.getElementById('themeSelect').value = saved;
}

function setTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  localStorage.setItem('dashboard-theme', theme);
  // Re-render charts with new colors
  if (data) {
    destroyCharts();
    renderChart();
    renderAgents();
  }
}

function destroyCharts() {
  if (mainChart) {
    mainChart.destroy();
    mainChart = null;
  }
  sparkCharts.forEach(c => c.destroy());
  sparkCharts = [];
}

async function init() {
  initTheme();
  try {
    // Load registry first
    await loadProjects();

    // Try to load last selected project or default plan
    const lastProject = localStorage.getItem('dashboard-current-project');
    if (lastProject && registry?.projects?.[lastProject]) {
      await selectProject(lastProject);
    } else {
      // Fallback to local plan.json
      const res = await fetch('plan.json');
      data = await res.json();
      currentProjectId = data.meta?.project_id || null;
      render();
    }
  } catch (e) {
    document.querySelector('.main-content').innerHTML = `<div style="padding:40px;color:#ef4444;">Error: ${e.message}</div>`;
  }
}

// ==========================================
// PROJECT MANAGEMENT (V3)
// ==========================================

// API base URL - change this if server runs on different port
const API_BASE = '/api';

async function loadProjects() {
  try {
    const res = await fetch(`${API_BASE}/projects`);
    const projectsList = await res.json();
    // Convert array to object keyed by project_id
    registry = { projects: {} };
    projectsList.forEach(p => {
      registry.projects[p.project_id] = {
        name: p.project_name,
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

  const projects = Object.entries(registry.projects || {});
  if (projects.length === 0) {
    list.innerHTML = '<div class="project-loading">No projects registered yet</div>';
    return;
  }

  list.innerHTML = projects.map(([id, p]) => {
    const isActive = id === currentProjectId;
    const plan = p.current_plan || 'No active plan';
    const statusClass = p.status === 'active' ? 'in-progress' : '';
    return `
      <div class="project-item ${isActive ? 'active' : ''} ${statusClass}" onclick="selectProject('${id}')">
        <div class="project-item-dot"></div>
        <div class="project-item-info">
          <div class="project-item-name">${p.name}</div>
          <div class="project-item-plan">${plan}</div>
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

  // Update project indicator
  document.getElementById('projectName').textContent = project.name;
  const dot = document.getElementById('projectDot');
  if (dot) dot.style.background = '#22c55e';

  // Hide menu
  document.getElementById('projectMenu').style.display = 'none';

  // Load project plans from API
  try {
    const res = await fetch(`${API_BASE}/plans/${projectId}`);
    const plans = await res.json();

    // Find active (doing) plan or first plan
    const activePlan = plans.find(p => p.status === 'doing') || plans[0];

    if (activePlan) {
      await loadPlanDetails(activePlan.id);
    } else {
      // No plans yet - show empty state
      data = createEmptyPlanData(projectId, project.name);
      render();
    }
    renderProjectList();

    // Load real GitHub, git, and token data in parallel
    loadGitHubData();
    loadGitData();
    loadTokenData();
  } catch (e) {
    console.error('Failed to load project plans:', e);
    // Fallback to local plan.json
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

    // Transform DB plan to dashboard data format
    data = transformPlanToData(plan);
    render();

    // Load history
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
      name: w.name,
      status: w.status === 'pending' ? 'pending' : w.status === 'in_progress' ? 'in_progress' : 'done',
      done: w.tasks_done || 0,
      total: w.tasks_total || 0,
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

// Load real GitHub data for current project
async function loadGitHubData() {
  if (!currentProjectId) return;

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/github`);
    const github = await res.json();

    if (github.error) {
      console.log('GitHub data not available:', github.error);
      data.github = null;
      return;
    }

    data.github = {
      repo: github.repo,
      issues: github.issues || [],
      pr: github.prs?.[0] ? {
        number: `#${github.prs[0].number}`,
        title: github.prs[0].title,
        additions: github.prs[0].additions || 0,
        deletions: github.prs[0].deletions || 0,
        files: github.prs[0].files?.length || 0,
        url: `https://github.com/${github.repo}/pull/${github.prs[0].number}`,
        branch: github.prs[0].headRefName
      } : null,
      prs: github.prs || []
    };

    renderGitHubPanel();
  } catch (e) {
    console.error('Failed to load GitHub data:', e);
  }
}

// Load real git status for current project
async function loadGitData() {
  if (!currentProjectId) return;

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git`);
    const git = await res.json();

    if (git.error) {
      console.log('Git data not available:', git.error);
      return;
    }

    data.git = {
      currentBranch: git.branch,
      uncommitted: git.uncommitted,
      commits: git.commits,
      totalChanges: git.totalChanges
    };

    renderGitTree();
  } catch (e) {
    console.error('Failed to load git data:', e);
  }
}

// Render GitHub panel with real data
function renderGitHubPanel() {
  if (!data.github) return;
  renderIssuesPanel();
  updateHealthStatus();
}

// Render GitHub issues in Issues tab
function renderIssuesPanel() {
  const tabIssues = document.getElementById('tabIssues');
  if (!tabIssues) return;

  if (!data.github?.issues) {
    tabIssues.innerHTML = '<div class="issues-loading">No GitHub data</div>';
    return;
  }

  const issues = data.github.issues;
  if (issues.length === 0) {
    tabIssues.innerHTML = '<div class="alert-empty">No open issues</div>';
    return;
  }

  tabIssues.innerHTML = issues.slice(0, 5).map(issue => `
    <div class="alert-item" onclick="window.open('https://github.com/${data.github.repo}/issues/${issue.number}', '_blank')">
      <div class="alert-icon">#${issue.number}</div>
      <div class="alert-content">
        <div class="alert-title">${issue.title}</div>
        <div class="alert-meta">
          ${issue.labels?.map(l => `<span class="alert-label">${l.name}</span>`).join('') || ''}
          <span class="alert-author">by ${issue.author?.login || 'unknown'}</span>
        </div>
      </div>
    </div>
  `).join('');
}

// Load token usage data
async function loadTokenData() {
  if (!currentProjectId) return;

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/tokens`);
    const tokenData = await res.json();

    data.tokens = {
      total: tokenData.stats?.total_tokens || 0,
      cost: tokenData.stats?.total_cost || 0,
      calls: tokenData.stats?.api_calls || 0,
      avgPerTask: 0
    };

    // Calculate avg per task if we have tasks
    if (data.metrics?.throughput?.done > 0 && data.tokens.total > 0) {
      data.tokens.avgPerTask = Math.round(data.tokens.total / data.metrics.throughput.done);
    }

    // Update display
    document.getElementById('tokensUsed').textContent = data.tokens.total ? data.tokens.total.toLocaleString() : 'n/d';
    document.getElementById('avgTokensPerTask').textContent = data.tokens.avgPerTask ? data.tokens.avgPerTask.toLocaleString() : 'n/d';

    // Also update tokens tab
    renderTokensTab();
  } catch (e) {
    console.log('Token data not available:', e.message);
    data.tokens = null;
  }
}

// Render Git tab with real data
function renderGitTab() {
  if (!data.git) {
    document.getElementById('gitBranch').textContent = 'No git data';
    return;
  }

  document.getElementById('gitBranch').textContent = data.git.currentBranch || '-';

  // Count uncommitted files
  const uncommitted = data.git.uncommitted || {};
  const stagedCount = uncommitted.staged?.length || 0;
  const unstagedCount = uncommitted.unstaged?.length || 0;
  const untrackedCount = uncommitted.untracked?.length || 0;
  const totalUncommitted = stagedCount + unstagedCount + untrackedCount;

  document.getElementById('gitUncommitted').textContent = totalUncommitted;
  document.getElementById('gitAhead').textContent = '-'; // TODO: calculate from commits
  document.getElementById('gitBehind').textContent = '-';

  // Render file list
  const gitFilesList = document.getElementById('gitFilesList');
  if (gitFilesList) {
    const files = [];
    (uncommitted.unstaged || []).forEach(f => files.push({ status: f.status, path: f.path }));
    (uncommitted.staged || []).forEach(f => files.push({ status: 'A', path: f.path }));
    (uncommitted.untracked || []).slice(0, 5).forEach(f => files.push({ status: 'U', path: f }));

    gitFilesList.innerHTML = files.slice(0, 10).map(f => `
      <div class="git-file">
        <span class="git-file-status ${f.status}">${f.status}</span>
        <span class="git-file-path">${f.path}</span>
      </div>
    `).join('') || '<div class="git-file">No uncommitted files</div>';
  }
}

// Render Tokens tab
function renderTokensTab() {
  if (!data.tokens) {
    document.getElementById('tokenTotal').textContent = 'n/d';
    document.getElementById('tokenCost').textContent = 'n/d';
    document.getElementById('tokenCalls').textContent = '0';
    return;
  }

  document.getElementById('tokenTotal').textContent = data.tokens.total ? data.tokens.total.toLocaleString() : 'n/d';
  document.getElementById('tokenCost').textContent = data.tokens.cost ? '$' + data.tokens.cost.toFixed(2) : 'n/d';
  document.getElementById('tokenCalls').textContent = data.tokens.calls || 0;
}

// Update health status indicators
function updateHealthStatus() {
  // Plan health
  const planHealth = document.getElementById('healthPlan');
  if (planHealth) {
    const progress = data.metrics?.throughput?.percent || 0;
    const blockedTasks = data.waves?.filter(w => w.status === 'blocked').length || 0;

    planHealth.className = 'health-item';
    if (blockedTasks > 0) {
      planHealth.classList.add('red');
      planHealth.querySelector('.health-value').textContent = 'Blocked';
    } else if (progress > 50) {
      planHealth.classList.add('green');
      planHealth.querySelector('.health-value').textContent = progress + '%';
    } else if (progress > 0) {
      planHealth.classList.add('yellow');
      planHealth.querySelector('.health-value').textContent = progress + '%';
    } else {
      planHealth.querySelector('.health-value').textContent = 'Not started';
    }
  }

  // Git health
  const gitHealth = document.getElementById('healthGit');
  if (gitHealth && data.git) {
    const uncommitted = data.git.totalChanges || 0;
    gitHealth.className = 'health-item';
    if (uncommitted > 10) {
      gitHealth.classList.add('yellow');
      gitHealth.querySelector('.health-value').textContent = uncommitted + ' changes';
    } else if (uncommitted > 0) {
      gitHealth.classList.add('green');
      gitHealth.querySelector('.health-value').textContent = uncommitted + ' changes';
    } else {
      gitHealth.classList.add('green');
      gitHealth.querySelector('.health-value').textContent = 'Clean';
    }
  }

  // Issues health
  const issuesHealth = document.getElementById('healthIssues');
  if (issuesHealth && data.github) {
    const openIssues = data.github.issues?.length || 0;
    issuesHealth.className = 'health-item';
    if (openIssues > 10) {
      issuesHealth.classList.add('red');
    } else if (openIssues > 5) {
      issuesHealth.classList.add('yellow');
    } else {
      issuesHealth.classList.add('green');
    }
    issuesHealth.querySelector('.health-value').textContent = openIssues + ' open';
  }

  // Current focus
  const activeWave = data.waves?.find(w => w.status === 'in_progress');
  const focusWave = document.getElementById('focusWave');
  const focusTask = document.getElementById('focusTask');

  if (focusWave) {
    if (activeWave) {
      focusWave.textContent = activeWave.id + ' - ' + activeWave.name;
      const activeTask = activeWave.tasks?.find(t => t.status === 'in_progress');
      if (focusTask) {
        focusTask.textContent = activeTask ? activeTask.title : 'No active task';
      }
    } else {
      focusWave.textContent = 'No active wave';
      if (focusTask) focusTask.textContent = '-';
    }
  }
}

// Close project menu when clicking outside
document.addEventListener('click', (e) => {
  const menu = document.getElementById('projectMenu');
  const logo = document.querySelector('.logo');
  if (menu && !menu.contains(e.target) && !logo.contains(e.target)) {
    menu.style.display = 'none';
  }
});

function render() {
  // Header
  document.getElementById('projectName').textContent = data.meta.project;
  document.getElementById('planLabel').textContent = data.meta.project;
  document.getElementById('throughputBadge').textContent = data.metrics.throughput.percent + '%';
  document.getElementById('ownerBadge').innerHTML = '&#x1F464; ' + data.meta.owner;

  // Stats - real data or n/d
  document.getElementById('tasksDone').textContent = `${data.metrics.throughput.done}/${data.metrics.throughput.total}`;
  document.getElementById('tokensUsed').textContent = data.tokens?.total ? data.tokens.total.toLocaleString() : 'n/d';
  document.getElementById('avgTokensPerTask').textContent = data.tokens?.avgPerTask ? data.tokens.avgPerTask.toLocaleString() : 'n/d';
  const wavesDone = data.waves.filter(w => w.status === 'done').length;
  document.getElementById('wavesStatus').textContent = `${wavesDone}/${data.waves.length}`;
  document.getElementById('progressPercent').textContent = data.metrics.throughput.percent + '%';

  // Epoch bar
  const currentWave = data.waves.find(w => w.status === 'in_progress') || data.waves[data.waves.length - 1];
  document.getElementById('currentWave').textContent = currentWave.id + ' - ' + currentWave.name;

  const start = data.timeline.start.replace('T', ' ').slice(0, 16);
  const eta = data.timeline.eta.replace('T', ' ').slice(0, 16);
  document.getElementById('epochDates').innerHTML = start + ' &#8212; ' + eta;
  document.getElementById('countdown').textContent = data.timeline.remaining + ' left';

  // Calculate progress percentage for epoch bar
  const totalTasks = data.metrics.throughput.total;
  const doneTasks = data.metrics.throughput.done;
  const epochProgress = Math.round((doneTasks / totalTasks) * 100);
  document.getElementById('epochFill').style.width = epochProgress + '%';

  // Git branch
  if (data.git) {
    document.getElementById('gitBranch').textContent = data.git.currentBranch;
    renderGitTab();
  }

  // Update right panel
  updateHealthStatus();
  renderIssuesPanel();
  renderTokensTab();

  renderChart();
  renderAgents();
}

function renderChart() {
  const times = data.timeline.data.map(d => d.time);
  const done = data.timeline.data.map(d => d.done);
  const target = data.timeline.data.map(d => d.target);
  const theme = document.documentElement.getAttribute('data-theme') || 'voltrex';
  const colors = themeColors[theme];

  mainChart = new ApexCharts(document.getElementById('mainChart'), {
    series: [
      { name: 'Completed', data: done }
    ],
    chart: {
      type: 'line',
      height: 260,
      toolbar: { show: false },
      background: 'transparent',
      zoom: { enabled: false },
      animations: { enabled: true, easing: 'easeinout', speed: 800 },
      redrawOnParentResize: true,
      redrawOnWindowResize: true
    },
    responsive: [
      {
        breakpoint: 768,
        options: {
          chart: { height: 200 },
          xaxis: { labels: { rotate: -45, style: { fontSize: '9px' } } }
        }
      },
      {
        breakpoint: 576,
        options: {
          chart: { height: 180 },
          markers: { size: 3 }
        }
      }
    ],
    colors: [colors.line],
    stroke: { width: 3, curve: 'smooth' },
    markers: {
      size: 5,
      colors: [colors.line],
      strokeColors: theme === 'frost' || theme === 'dawn' ? '#ffffff' : '#0a0612',
      strokeWidth: 2,
      hover: { size: 7 }
    },
    xaxis: {
      categories: times,
      labels: {
        style: { colors: colors.text, fontSize: '10px' },
        rotate: 0
      },
      axisBorder: { show: false },
      axisTicks: { show: false }
    },
    yaxis: {
      labels: {
        style: { colors: colors.text, fontSize: '10px' },
        formatter: v => Math.round(v).toLocaleString()
      },
      min: 0
    },
    grid: {
      borderColor: colors.grid,
      strokeDashArray: 0,
      xaxis: { lines: { show: true } },
      yaxis: { lines: { show: true } }
    },
    legend: { show: false },
    tooltip: {
      theme: theme === 'frost' || theme === 'dawn' ? 'light' : 'dark',
      custom: ({ series, seriesIndex, dataPointIndex, w }) => {
        const time = w.globals.categoryLabels[dataPointIndex];
        const val = series[0][dataPointIndex];
        const bg = theme === 'frost' || theme === 'dawn' ? '#ffffff' : '#1a1128';
        const border = theme === 'frost' || theme === 'dawn' ? 'rgba(0,0,0,0.1)' : 'rgba(139,92,246,0.3)';
        const textCol = theme === 'frost' || theme === 'dawn' ? '#1c1917' : '#fff';
        return `<div style="background:${bg};padding:10px 14px;border-radius:8px;border:1px solid ${border};">
          <div style="color:${colors.text};font-size:10px;margin-bottom:4px;">${time}</div>
          <div style="color:${textCol};font-size:13px;font-weight:600;">Value: ${val}</div>
          <div style="color:${colors.accent};font-size:11px;">Progress: +${val}</div>
        </div>`;
      }
    },
    annotations: {
      yaxis: [{
        y: data.metrics.throughput.done,
        borderColor: colors.accent,
        strokeDashArray: 4,
        label: {
          borderColor: colors.accent,
          position: 'right',
          style: {
            color: theme === 'frost' || theme === 'dawn' ? '#fff' : '#000',
            background: colors.accent,
            fontSize: '10px',
            fontWeight: 600,
            padding: { left: 6, right: 6, top: 2, bottom: 2 }
          },
          text: data.metrics.throughput.done.toLocaleString()
        }
      }]
    }
  });
  mainChart.render();
}

function renderAgents() {
  const grid = document.getElementById('agentsGrid');
  grid.innerHTML = data.contributors.map((c, i) => {
    const isActive = c.status === 'active';
    return `
      <div class="trader-card">
        <div class="trader-top">
          <div class="trader-avatar">${c.avatar}</div>
          <div class="trader-info">
            <div class="trader-name">${c.name}</div>
            <div class="trader-followers">${c.tasks}/100</div>
          </div>
          <div class="trader-star ${isActive ? '' : 'inactive'}">&#9733;</div>
        </div>
        <div class="trader-profit">+${c.tasks.toLocaleString()}</div>
        <div class="trader-roi">ROI +${c.efficiency || 100}%</div>
        <div class="trader-chart" id="spark${i}"></div>
        <div class="trader-stats">
          <div class="trader-stat">
            <div class="trader-stat-label">Status</div>
            <div class="trader-stat-value">${c.status}</div>
          </div>
          <div class="trader-stat">
            <div class="trader-stat-label">Current</div>
            <div class="trader-stat-value">${c.currentTask || '-'}</div>
          </div>
          <div class="trader-stat">
            <div class="trader-stat-label">Efficiency</div>
            <div class="trader-stat-value">${c.efficiency ? c.efficiency + '%' : '-'}</div>
          </div>
        </div>
        <div class="trader-actions">
          <button class="trader-btn mock" onclick="showAgentDetails('${c.id}')">Details</button>
        </div>
      </div>
    `;
  }).join('');

  // Render sparklines for each agent
  const theme = document.documentElement.getAttribute('data-theme') || 'voltrex';
  const colors = themeColors[theme];

  data.contributors.forEach((c, i) => {
    const sparkData = generateSparkline(c.tasks, c.status === 'active');
    const spark = new ApexCharts(document.getElementById(`spark${i}`), {
      series: [{ data: sparkData }],
      chart: {
        type: 'line',
        height: 36,
        sparkline: { enabled: true },
        animations: { enabled: false }
      },
      stroke: { width: 2, curve: 'smooth' },
      colors: [c.status === 'active' ? colors.line : colors.accent],
      tooltip: { enabled: false }
    });
    spark.render();
    sparkCharts.push(spark);
  });
}

function generateSparkline(tasks, isActive) {
  const points = [];
  let val = tasks * 0.3;
  for (let i = 0; i < 12; i++) {
    val += (Math.random() - 0.3) * (tasks / 8);
    if (val < 0) val = Math.random() * tasks * 0.2;
    points.push(Math.round(val));
  }
  // Make active agents trend upward
  if (isActive) {
    points[points.length - 1] = Math.max(...points) * 1.1;
  }
  return points;
}

// Export handler
document.getElementById('exportBtn')?.addEventListener('click', () => {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const link = document.createElement('a');
  link.download = `${data.meta.project}-plan.json`;
  link.href = URL.createObjectURL(blob);
  link.click();
});

// Open PR button
document.querySelector('.max-btn')?.addEventListener('click', () => {
  if (data.github?.pr?.url) {
    window.open(data.github.pr.url, '_blank');
  }
});

// Theme selector event listener
document.getElementById('themeSelect')?.addEventListener('change', (e) => {
  setTheme(e.target.value);
});

// ==========================================
// DRILL-DOWN & NAVIGATION (V2)
// ==========================================

let drilldownState = { level: 'plan', waveId: null, taskId: null };

function renderWaves() {
  const wavesList = document.getElementById('wavesList');
  if (!wavesList || !data.waves) return;

  wavesList.innerHTML = data.waves.map(w => {
    const progress = w.total > 0 ? Math.round((w.done / w.total) * 100) : 0;
    const statusClass = w.status === 'done' ? 'green' : w.status === 'in_progress' ? 'orange' : '';
    return `
      <div class="wave-item" onclick="drillIntoWave('${w.id}')">
        <div class="wave-item-header">
          <span class="wave-id">${w.id}</span>
          <span class="wave-name">${w.name}</span>
          <span class="wave-status ${statusClass}">${w.status}</span>
        </div>
        <div class="wave-item-progress">
          <div class="wave-bar">
            <div class="wave-bar-fill" style="width:${progress}%"></div>
          </div>
          <span class="wave-count">${w.done}/${w.total}</span>
        </div>
      </div>
    `;
  }).join('');
}

function drillIntoWave(waveId) {
  const wave = data.waves.find(w => w.id === waveId);
  if (!wave) return;

  drilldownState = { level: 'wave', waveId, taskId: null };
  document.getElementById('wavesSummary').style.display = 'none';
  document.getElementById('drilldownPanel').style.display = 'block';
  document.getElementById('drilldownTitle').textContent = `${wave.id} - ${wave.name}`;
  document.getElementById('drilldownBack').style.display = 'inline-block';

  const tasks = wave.tasks || [];
  if (tasks.length === 0) {
    document.getElementById('drilldownContent').innerHTML = `
      <div class="no-tasks">No task details available for this wave.</div>
    `;
    return;
  }

  document.getElementById('drilldownContent').innerHTML = tasks.map(t => {
    const statusClass = t.status === 'done' ? 'green' : t.status === 'in_progress' ? 'orange' : t.status === 'blocked' ? 'red' : '';
    return `
      <div class="task-item" onclick="drillIntoTask('${waveId}', '${t.id}')">
        <span class="task-id">${t.id}</span>
        <span class="task-title">${t.title}</span>
        <span class="task-status ${statusClass}">${t.status}</span>
        ${t.timing?.duration ? `<span class="task-duration">${t.timing.duration}m</span>` : ''}
      </div>
    `;
  }).join('');
}

function drillIntoTask(waveId, taskId) {
  const wave = data.waves.find(w => w.id === waveId);
  const task = wave?.tasks?.find(t => t.id === taskId);
  if (!task) return;

  drilldownState = { level: 'task', waveId, taskId };
  document.getElementById('drilldownTitle').textContent = `Task ${task.id}`;

  document.getElementById('drilldownContent').innerHTML = `
    <div class="task-detail">
      <h3>${task.title}</h3>
      <div class="task-meta">
        <div><strong>Status:</strong> ${task.status}</div>
        <div><strong>Assignee:</strong> ${task.assignee || '-'}</div>
        <div><strong>Priority:</strong> ${task.priority || '-'}</div>
        <div><strong>Type:</strong> ${task.type || '-'}</div>
      </div>
      ${task.timing ? `
        <div class="task-timing">
          <div><strong>Started:</strong> ${task.timing.started || '-'}</div>
          <div><strong>Completed:</strong> ${task.timing.completed || '-'}</div>
          <div><strong>Duration:</strong> ${task.timing.duration ? task.timing.duration + ' min' : '-'}</div>
        </div>
      ` : ''}
      ${task.files?.length ? `
        <div class="task-files">
          <strong>Files:</strong>
          <ul>${task.files.map(f => `<li>${f}</li>`).join('')}</ul>
        </div>
      ` : ''}
      ${task.notes ? `<div class="task-notes"><strong>Notes:</strong> ${task.notes}</div>` : ''}
    </div>
  `;
}

function navigateBack() {
  if (drilldownState.level === 'task') {
    drillIntoWave(drilldownState.waveId);
  } else if (drilldownState.level === 'wave') {
    drilldownState = { level: 'plan', waveId: null, taskId: null };
    document.getElementById('drilldownPanel').style.display = 'none';
    document.getElementById('wavesSummary').style.display = 'block';
  }
}

function refreshWaves() {
  renderWaves();
}

// ==========================================
// TAB SWITCHING
// ==========================================

function showTab(tabName) {
  ['git', 'issues', 'tokens', 'history'].forEach(t => {
    const tabId = 'tab' + t.charAt(0).toUpperCase() + t.slice(1);
    const tab = document.getElementById(tabId);
    const btn = document.querySelector(`.about-tab[onclick="showTab('${t}')"]`);
    if (tab) tab.style.display = t === tabName ? 'block' : 'none';
    if (btn) btn.classList.toggle('active', t === tabName);
  });

  if (tabName === 'git') {
    renderGitTab();
  }
  if (tabName === 'issues') {
    renderIssuesPanel();
  }
  if (tabName === 'tokens') {
    renderTokensTab();
  }
  if (tabName === 'history') {
    renderHistory();
  }
}

// ==========================================
// GIT TREE
// ==========================================

function renderGitTree() {
  const uncommitted = data.git?.uncommitted || { staged: [], unstaged: [], untracked: [] };

  document.getElementById('stagedCount').textContent = uncommitted.staged?.length || 0;
  document.getElementById('unstagedCount').textContent = uncommitted.unstaged?.length || 0;
  document.getElementById('untrackedCount').textContent = uncommitted.untracked?.length || 0;

  document.getElementById('stagedFiles').innerHTML = (uncommitted.staged || []).map(f =>
    `<div class="git-file"><span class="git-status ${f.status}">${f.status}</span> ${f.path}</div>`
  ).join('') || '<div class="git-empty">No staged files</div>';

  document.getElementById('unstagedFiles').innerHTML = (uncommitted.unstaged || []).map(f =>
    `<div class="git-file"><span class="git-status ${f.status}">${f.status}</span> ${f.path}</div>`
  ).join('') || '<div class="git-empty">No unstaged changes</div>';

  document.getElementById('untrackedFiles').innerHTML = (uncommitted.untracked || []).map(f =>
    `<div class="git-file">? ${f}</div>`
  ).join('') || '<div class="git-empty">No untracked files</div>';
}

function toggleGitSection(section) {
  const filesEl = document.getElementById(section + 'Files');
  if (filesEl) {
    filesEl.style.display = filesEl.style.display === 'none' ? 'block' : 'none';
  }
}

function copyBranch() {
  const branch = document.getElementById('gitBranch')?.textContent;
  if (branch) {
    navigator.clipboard.writeText(branch);
  }
}

// ==========================================
// DEBT PANEL
// ==========================================

function renderDebt() {
  if (!data.debt) return;

  document.getElementById('debtTotal').textContent = data.debt.total || 0;
  document.getElementById('debtTodo').textContent = data.debt.byType?.todo?.length || 0;
  document.getElementById('debtFixme').textContent = data.debt.byType?.fixme?.length || 0;
  document.getElementById('debtHack').textContent = data.debt.byType?.hack?.length || 0;

  if (data.debt.lastScan) {
    document.getElementById('debtUpdated').textContent = 'Last scan: ' + new Date(data.debt.lastScan).toLocaleString();
  }
}

// ==========================================
// HISTORY PANEL (Plan Versions)
// ==========================================

function renderHistory() {
  const history = data.history || [];

  // Update summary stats
  const versions = history.length;
  const edits = history.filter(h => h.change_type === 'user_edit').length;
  const blockers = history.filter(h => h.change_type === 'blocker').length;

  document.getElementById('historyVersions').textContent = versions || 0;
  document.getElementById('historyEdits').textContent = edits || 0;
  document.getElementById('historyBlockers').textContent = blockers || 0;

  const timeline = document.getElementById('historyTimeline');
  if (!timeline) return;

  if (history.length === 0) {
    timeline.innerHTML = '<div class="history-empty">No version history yet</div>';
    return;
  }

  timeline.innerHTML = history.map(h => {
    const typeLabel = {
      'created': 'Created',
      'user_edit': 'User Edit',
      'scope_add': 'Scope Added',
      'scope_remove': 'Scope Removed',
      'blocker': 'Blocker',
      'replan': 'Replanned',
      'task_split': 'Task Split',
      'completed': 'Completed'
    }[h.change_type] || h.change_type;

    const time = h.created_at ? new Date(h.created_at).toLocaleString() : '';

    return `
      <div class="history-item">
        <div class="history-item-dot ${h.change_type}"></div>
        <div class="history-item-content">
          <div class="history-item-type">v${h.version} - ${typeLabel}</div>
          ${h.change_reason ? `<div class="history-item-reason">${h.change_reason}</div>` : ''}
          <div class="history-item-time">${time}</div>
        </div>
      </div>
    `;
  }).join('');
}

// ==========================================
// AGENT DETAILS
// ==========================================

function showAgentDetails(agentId) {
  const agent = data.contributors?.find(c => c.id === agentId);
  if (!agent) return;

  alert(`Agent: ${agent.name}\nRole: ${agent.role}\nTasks: ${agent.tasks}\nStatus: ${agent.status}\nEfficiency: ${agent.efficiency || '-'}%`);
}

// ==========================================
// ENHANCED RENDER (V2)
// ==========================================

const originalRender = render;
render = function() {
  originalRender();
  renderWaves();
  if (data.git?.uncommitted) renderGitTree();
  if (data.debt) renderDebt();
};

// ==========================================
// KANBAN VIEW
// ==========================================

let currentView = 'dashboard';

function showView(view) {
  currentView = view;

  // Update nav menu active state
  document.querySelectorAll('.nav-menu a').forEach(a => {
    a.classList.remove('active');
    const linkText = a.textContent.toLowerCase();
    if (linkText.includes(view) || (view === 'bugs' && linkText.includes('bugs'))) {
      a.classList.add('active');
    }
  });

  // All view elements
  const dashboardElements = ['wavesSummary', 'drilldownPanel'];
  const chartCard = document.querySelector('.chart-card');
  const tradersSection = document.querySelector('.traders-section');
  const kanbanView = document.getElementById('kanbanView');
  const wavesView = document.getElementById('wavesView');
  const bugsView = document.getElementById('bugsView');
  const agentsView = document.getElementById('agentsView');
  const statsRow = document.querySelector('.stats-row');
  const epochBar = document.querySelector('.epoch-bar');
  const planLabel = document.querySelector('.stats-label');

  // Hide all specialized views first
  [kanbanView, wavesView, bugsView, agentsView].forEach(v => {
    if (v) v.style.display = 'none';
  });

  // Hide/show dashboard elements based on view
  const hideDashboard = view !== 'dashboard';
  dashboardElements.forEach(id => {
    const el = document.getElementById(id);
    if (el) el.style.display = hideDashboard ? 'none' : '';
  });
  if (chartCard) chartCard.style.display = hideDashboard ? 'none' : '';
  if (tradersSection) tradersSection.style.display = hideDashboard ? 'none' : '';
  if (statsRow) statsRow.style.display = hideDashboard ? 'none' : '';
  if (epochBar) epochBar.style.display = hideDashboard ? 'none' : '';
  if (planLabel) planLabel.style.display = hideDashboard ? 'none' : '';

  // Show the selected view and load its data
  switch (view) {
    case 'kanban':
      if (kanbanView) kanbanView.style.display = 'block';
      loadKanban();
      break;
    case 'waves':
      if (wavesView) wavesView.style.display = 'block';
      loadWavesView();
      break;
    case 'bugs':
      if (bugsView) bugsView.style.display = 'block';
      loadBugsView();
      break;
    case 'agents':
      if (agentsView) agentsView.style.display = 'block';
      loadAgentsView();
      break;
    case 'dashboard':
    default:
      // Dashboard elements are already shown
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

    // Collect all project IDs first
    plans.forEach(plan => projectIds.add(plan.project_id));

    // Fetch token data for all projects in parallel
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

      // Determine if plan is "running" (has recent activity)
      const updatedAt = plan.completed_at || plan.started_at || plan.created_at;
      const lastUpdate = updatedAt ? new Date(updatedAt) : null;
      const isRecent = lastUpdate && (Date.now() - lastUpdate.getTime()) < 3600000; // < 1 hour
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
    // Fallback to registry scan if API not available
    if (!registry) await loadProjects();

    for (const [projectId, project] of Object.entries(registry.projects || {})) {
      projectIds.add(projectId);
      if (project.plans_doing > 0) {
        kanban.doing.push({ project: project.name, projectId, name: 'Active plan', progress: 50, isRunning: false });
      }
      if (project.plans_todo > 0) {
        kanban.todo.push({ project: project.name, projectId, name: 'Pending plan', progress: 0, isRunning: false });
      }
      if (project.plans_done > 0) {
        kanban.done.push({ project: project.name, projectId, name: 'Completed plan', progress: 100, isRunning: false });
      }
    }
  }

  // Update summary stats
  const totalPlans = kanban.todo.length + kanban.doing.length + kanban.done.length;
  document.getElementById('kanbanTotalProjects').textContent = projectIds.size;
  document.getElementById('kanbanTotalPlans').textContent = totalPlans;
  document.getElementById('kanbanActivePlans').textContent = kanban.doing.length;
  document.getElementById('kanbanCompletedPlans').textContent = kanban.done.length;
  document.getElementById('kanbanTotalTokens').textContent = totalTokens ? totalTokens.toLocaleString() : '0';
  document.getElementById('kanbanTotalCost').textContent = totalCost ? '$' + totalCost.toFixed(2) : '$0';

  renderKanban(kanban);
}

function renderKanban(kanban) {
  ['todo', 'doing', 'done'].forEach(status => {
    const container = document.getElementById(`kanban${status.charAt(0).toUpperCase() + status.slice(1)}`);
    const countEl = document.getElementById(`kanban${status.charAt(0).toUpperCase() + status.slice(1)}Count`);

    if (!container) return;

    const plans = kanban[status] || [];
    countEl.textContent = plans.length;

    if (plans.length === 0) {
      container.innerHTML = '<div class="kanban-empty">No plans</div>';
      return;
    }

    container.innerHTML = plans.map(plan => {
      const masterBadge = plan.isMaster ? '<span class="kanban-master-badge">MASTER</span>' : '';
      const taskInfo = plan.tasksTotal ? `${plan.tasksDone}/${plan.tasksTotal}` : '';

      // Format updated date
      let updatedStr = '';
      if (plan.updatedAt) {
        const updated = new Date(plan.updatedAt);
        const now = new Date();
        const diffMs = now - updated;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 60) {
          updatedStr = diffMins + 'm ago';
        } else if (diffHours < 24) {
          updatedStr = diffHours + 'h ago';
        } else {
          updatedStr = diffDays + 'd ago';
        }
      }

      // Running indicator for active plans
      let runningIndicator = '';
      if (status === 'doing') {
        runningIndicator = plan.isRunning
          ? '<span class="kanban-running-indicator active">Running</span>'
          : '<span class="kanban-running-indicator stopped">Paused</span>';
      }

      // Token info
      const tokenStr = plan.tokens ? plan.tokens.toLocaleString() : '0';

      // Stats section for completed plans
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
        <div class="kanban-card ${plan.isMaster ? 'master' : ''}" onclick="loadPlanDetails(${plan.planId}); showView('dashboard');">
          <div class="kanban-card-header">
            <span class="kanban-card-project">${plan.project}</span>
            ${masterBadge}
          </div>
          <div class="kanban-card-status">
            ${runningIndicator}
          </div>
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
  });
}

// ==========================================
// WAVES VIEW
// ==========================================

async function loadWavesView() {
  const content = document.getElementById('wavesViewContent');
  if (!content) return;

  content.innerHTML = '<div class="waves-loading">Loading waves...</div>';

  try {
    // Get all plans from all projects
    const res = await fetch(`${API_BASE}/kanban`);
    const plans = await res.json();

    // Collect all waves from all plans
    const allWaves = [];

    for (const plan of plans) {
      try {
        const planRes = await fetch(`${API_BASE}/plan/${plan.plan_id}`);
        const planData = await planRes.json();

        if (planData.waves) {
          planData.waves.forEach(wave => {
            allWaves.push({
              ...wave,
              projectName: plan.project_name,
              projectId: plan.project_id,
              planName: plan.plan_name,
              planId: plan.plan_id
            });
          });
        }
      } catch (e) {
        console.log('Failed to load plan:', plan.plan_id);
      }
    }

    // Sort waves: in_progress first, then pending, then done
    allWaves.sort((a, b) => {
      const order = { 'in_progress': 0, 'pending': 1, 'done': 2 };
      return (order[a.status] || 3) - (order[b.status] || 3);
    });

    if (allWaves.length === 0) {
      content.innerHTML = '<div class="waves-loading">No waves found</div>';
      return;
    }

    content.innerHTML = allWaves.map(wave => {
      const progress = wave.tasks_total > 0
        ? Math.round((wave.tasks_done / wave.tasks_total) * 100)
        : 0;

      return `
        <div class="wave-timeline-item" onclick="selectProject('${wave.projectId}'); loadPlanDetails(${wave.planId}); showView('dashboard'); drillIntoWave('${wave.wave_id}');">
          <div class="wave-timeline-status ${wave.status}"></div>
          <div class="wave-timeline-content">
            <div class="wave-timeline-header">
              <span class="wave-timeline-title">${wave.wave_id} - ${wave.name}</span>
              <span class="wave-timeline-project">${wave.projectName}</span>
            </div>
            <div class="wave-timeline-progress">
              <div class="wave-timeline-progress-fill" style="width: ${progress}%"></div>
            </div>
            <div class="wave-timeline-meta">
              <span>Plan: ${wave.planName}</span>
              <span>Tasks: ${wave.tasks_done || 0}/${wave.tasks_total || 0}</span>
              <span>Assignee: ${wave.assignee || '-'}</span>
            </div>
          </div>
        </div>
      `;
    }).join('');
  } catch (e) {
    content.innerHTML = '<div class="waves-loading">Error loading waves: ' + e.message + '</div>';
  }
}

// ==========================================
// BUGS VIEW
// ==========================================

async function loadBugsView() {
  const content = document.getElementById('bugsContent');
  if (!content) return;

  content.innerHTML = '<div class="bugs-loading">Loading issues...</div>';

  try {
    const projects = await fetch(`${API_BASE}/projects`).then(r => r.json());

    const allIssues = [];
    const allBlockers = [];
    let totalPRs = 0;

    // Fetch GitHub data for all projects in parallel
    const githubPromises = projects.map(async (project) => {
      try {
        const res = await fetch(`${API_BASE}/project/${project.project_id}/github`);
        const data = await res.json();

        if (data.issues) {
          data.issues.forEach(issue => {
            const isBlocker = issue.labels?.some(l =>
              l.name.toLowerCase().includes('blocker') ||
              l.name.toLowerCase().includes('critical')
            );

            const item = {
              ...issue,
              projectName: project.project_name,
              projectId: project.project_id,
              repo: data.repo,
              isBlocker
            };

            allIssues.push(item);
            if (isBlocker) allBlockers.push(item);
          });
        }

        if (data.prs) {
          totalPRs += data.prs.length;
        }
      } catch (e) {
        console.log('Failed to load GitHub data for:', project.project_id);
      }
    });

    await Promise.all(githubPromises);

    // Update stats
    document.getElementById('bugsOpenCount').textContent = allIssues.length;
    document.getElementById('bugsBlockersCount').textContent = allBlockers.length;
    document.getElementById('bugsPrsCount').textContent = totalPRs;

    if (allIssues.length === 0) {
      content.innerHTML = '<div class="bugs-loading">No open issues found</div>';
      return;
    }

    // Sort: blockers first, then by date
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
            <div class="bug-meta">
              ${labels}
              <span class="bug-project">${issue.projectName}</span>
            </div>
          </div>
        </div>
      `;
    }).join('');
  } catch (e) {
    content.innerHTML = '<div class="bugs-loading">Error loading issues: ' + e.message + '</div>';
  }
}

// ==========================================
// AGENTS VIEW
// ==========================================

async function loadAgentsView() {
  const grid = document.getElementById('agentsGridView');
  if (!grid) return;

  grid.innerHTML = '<div class="waves-loading">Loading agents...</div>';

  try {
    // Get all plans and aggregate agent data
    const res = await fetch(`${API_BASE}/kanban`);
    const plans = await res.json();

    const agentStats = {};

    // Aggregate from all plans
    for (const plan of plans) {
      try {
        const planRes = await fetch(`${API_BASE}/plan/${plan.plan_id}`);
        const planData = await planRes.json();

        // Count tasks by assignee
        if (planData.waves) {
          planData.waves.forEach(wave => {
            if (wave.tasks) {
              wave.tasks.forEach(task => {
                const agent = task.assignee || 'unassigned';
                if (!agentStats[agent]) {
                  agentStats[agent] = {
                    name: agent,
                    totalTasks: 0,
                    doneTasks: 0,
                    inProgressTasks: 0,
                    projects: new Set()
                  };
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

    // Calculate totals
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

    // Sort by tasks done
    agents.sort((a, b) => b.doneTasks - a.doneTasks);

    grid.innerHTML = agents.filter(a => a.name !== 'unassigned').map(agent => {
      const efficiency = agent.totalTasks > 0
        ? Math.round((agent.doneTasks / agent.totalTasks) * 100)
        : 0;
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
          <div class="trader-profit">+${agent.doneTasks}</div>
          <div class="trader-roi">${efficiency}% completion</div>
          <div class="trader-stats">
            <div class="trader-stat">
              <div class="trader-stat-label">Total</div>
              <div class="trader-stat-value">${agent.totalTasks}</div>
            </div>
            <div class="trader-stat">
              <div class="trader-stat-label">Done</div>
              <div class="trader-stat-value">${agent.doneTasks}</div>
            </div>
            <div class="trader-stat">
              <div class="trader-stat-label">Active</div>
              <div class="trader-stat-value">${agent.inProgressTasks}</div>
            </div>
          </div>
        </div>
      `;
    }).join('');
  } catch (e) {
    grid.innerHTML = '<div class="waves-loading">Error loading agents: ' + e.message + '</div>';
  }
}

// ==========================================
// TOAST NOTIFICATIONS
// ==========================================

let lastNotificationId = 0;
let notificationPollingInterval = null;

function showToast(notification) {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  const severityIcons = {
    info: '&#x2139;',
    success: '&#x2713;',
    warning: '&#x26A0;',
    error: '&#x2717;'
  };

  const toast = document.createElement('div');
  toast.className = `toast ${notification.severity || 'info'}`;
  toast.dataset.id = notification.id;

  toast.innerHTML = `
    <div class="toast-icon">${severityIcons[notification.severity] || severityIcons.info}</div>
    <div class="toast-content">
      <div class="toast-title">${notification.title}</div>
      ${notification.message ? `<div class="toast-message">${notification.message}</div>` : ''}
      <div class="toast-project">${notification.project_name || notification.project_id}</div>
      ${notification.link ? `
        <div class="toast-actions">
          <button class="toast-action primary" onclick="handleNotificationAction(${notification.id}, '${notification.link}', '${notification.link_type}')">View</button>
          <button class="toast-action" onclick="dismissToast(this.closest('.toast'))">Dismiss</button>
        </div>
      ` : ''}
    </div>
    <button class="toast-close" onclick="dismissToast(this.closest('.toast'))">&times;</button>
  `;

  // Click to navigate if has link
  if (notification.link) {
    toast.style.cursor = 'pointer';
  }

  container.appendChild(toast);

  // Auto-dismiss after 8 seconds (longer for errors)
  const duration = notification.severity === 'error' ? 12000 : 8000;
  setTimeout(() => dismissToast(toast), duration);
}

function dismissToast(toast) {
  if (!toast || toast.classList.contains('dismissing')) return;
  toast.classList.add('dismissing');

  // Mark as read in DB
  const id = toast.dataset.id;
  if (id) {
    fetch(`${API_BASE}/notifications/${id}/read`, { method: 'POST' });
  }

  setTimeout(() => toast.remove(), 300);
}

function handleNotificationAction(id, link, linkType) {
  // Mark as read
  fetch(`${API_BASE}/notifications/${id}/read`, { method: 'POST' });

  if (linkType === 'project') {
    selectProject(link);
    showView('dashboard');
  } else if (linkType === 'github') {
    window.open(link, '_blank');
  } else if (linkType === 'plan') {
    loadPlanDetails(parseInt(link));
    showView('dashboard');
  } else if (link.startsWith('http')) {
    window.open(link, '_blank');
  }
}

// Poll for new notifications
async function pollNotifications() {
  try {
    const res = await fetch(`${API_BASE}/notifications/unread`);
    const data = await res.json();

    // Update bell badge
    const countEl = document.getElementById('notificationCount');
    if (countEl) {
      if (data.total > 0) {
        countEl.textContent = data.total > 99 ? '99+' : data.total;
        countEl.classList.remove('hidden');
      } else {
        countEl.classList.add('hidden');
      }
    }

    // Show toasts for new notifications
    if (data.notifications) {
      data.notifications.forEach(n => {
        if (n.id > lastNotificationId) {
          showToast(n);
          lastNotificationId = n.id;
        }
      });
    }
  } catch (e) {
    console.log('Failed to poll notifications:', e.message);
  }
}

function startNotificationPolling() {
  // Poll immediately
  pollNotifications();
  // Then every 10 seconds
  notificationPollingInterval = setInterval(pollNotifications, 10000);
}

function stopNotificationPolling() {
  if (notificationPollingInterval) {
    clearInterval(notificationPollingInterval);
    notificationPollingInterval = null;
  }
}

// ==========================================
// NOTIFICATION ARCHIVE VIEW
// ==========================================

let notificationsFilter = 'all';
let notificationsSearch = '';

async function loadNotificationsView() {
  const list = document.getElementById('notificationsList');
  if (!list) return;

  list.innerHTML = '<div class="notifications-empty">Loading...</div>';

  try {
    let url = `${API_BASE}/notifications?limit=50`;
    if (notificationsFilter === 'unread') url += '&unread=true';
    if (notificationsFilter === 'success') url += '&severity=success';
    if (notificationsFilter === 'error') url += '&severity=error';
    if (notificationsSearch) url += `&search=${encodeURIComponent(notificationsSearch)}`;

    const res = await fetch(url);
    const data = await res.json();

    if (!data.notifications || data.notifications.length === 0) {
      list.innerHTML = '<div class="notifications-empty">No notifications found</div>';
      return;
    }

    list.innerHTML = data.notifications.map(n => {
      const time = n.created_at ? formatRelativeTime(new Date(n.created_at)) : '';
      const severityIcons = { info: '&#x2139;', success: '&#x2713;', warning: '&#x26A0;', error: '&#x2717;' };

      return `
        <div class="notification-item ${n.is_read ? '' : 'unread'}" onclick="handleNotificationClick(${n.id}, '${n.link || ''}', '${n.link_type || ''}')">
          <div class="notification-item-icon ${n.severity}">${severityIcons[n.severity] || severityIcons.info}</div>
          <div class="notification-item-content">
            <div class="notification-item-header">
              <span class="notification-item-title">${n.title}</span>
              <span class="notification-item-time">${time}</span>
            </div>
            ${n.message ? `<div class="notification-item-message">${n.message}</div>` : ''}
            <div class="notification-item-project">${n.project_name || n.project_id}</div>
          </div>
        </div>
      `;
    }).join('');
  } catch (e) {
    list.innerHTML = `<div class="notifications-empty">Error: ${e.message}</div>`;
  }
}

function handleNotificationClick(id, link, linkType) {
  // Mark as read
  fetch(`${API_BASE}/notifications/${id}/read`, { method: 'POST' }).then(() => {
    // Refresh view
    loadNotificationsView();
    pollNotifications();
  });

  // Navigate if has link
  if (link) {
    handleNotificationAction(id, link, linkType);
  }
}

function filterNotifications(filter) {
  notificationsFilter = filter;

  // Update filter buttons
  document.querySelectorAll('.notifications-filter').forEach(btn => {
    btn.classList.toggle('active', btn.textContent.toLowerCase().includes(filter) || (filter === 'all' && btn.textContent === 'All'));
  });

  loadNotificationsView();
}

function searchNotifications(query) {
  notificationsSearch = query;
  // Debounce search
  clearTimeout(window.notificationSearchTimeout);
  window.notificationSearchTimeout = setTimeout(loadNotificationsView, 300);
}

async function markAllNotificationsRead() {
  await fetch(`${API_BASE}/notifications/read-all`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
  loadNotificationsView();
  pollNotifications();
}

function formatRelativeTime(date) {
  const now = new Date();
  const diffMs = now - date;
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return 'just now';
  if (diffMins < 60) return diffMins + 'm ago';
  if (diffHours < 24) return diffHours + 'h ago';
  if (diffDays < 7) return diffDays + 'd ago';
  return date.toLocaleDateString();
}

// ==========================================
// TOKEN CHART
// ==========================================

let chartMode = 'tokens';

function switchChartMode(mode) {
  chartMode = mode;

  // Update tab active state
  document.querySelectorAll('.chart-tab').forEach(tab => {
    tab.classList.toggle('active', tab.textContent.toLowerCase() === mode);
  });

  // Re-render chart
  destroyCharts();
  if (mode === 'tokens') {
    renderTokenChart();
  } else {
    renderChart(); // Original burndown chart
  }
}

async function renderTokenChart() {
  // Fetch token history for the project
  let tokenHistory = [];

  try {
    // For now, generate sample data based on current token usage
    // In production, this would fetch from /api/project/:id/tokens/history
    const totalTokens = data.tokens?.total || 0;
    const calls = data.tokens?.calls || 0;

    if (calls > 0) {
      // Generate historical data points
      const days = 7;
      const avgPerDay = Math.round(totalTokens / days);
      let cumulative = 0;

      for (let i = days; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        const dayTokens = i === 0 ? totalTokens - cumulative : Math.round(avgPerDay * (0.5 + Math.random()));
        cumulative += dayTokens;
        tokenHistory.push({
          date: date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
          input: Math.round(dayTokens * 0.7),
          output: Math.round(dayTokens * 0.3)
        });
      }
    } else {
      // No data - show empty chart
      for (let i = 6; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        tokenHistory.push({
          date: date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
          input: 0,
          output: 0
        });
      }
    }
  } catch (e) {
    console.error('Failed to load token history:', e);
  }

  const theme = document.documentElement.getAttribute('data-theme') || 'voltrex';
  const colors = themeColors[theme];

  // Update legend
  const totalInput = tokenHistory.reduce((sum, d) => sum + d.input, 0);
  const totalOutput = tokenHistory.reduce((sum, d) => sum + d.output, 0);
  document.getElementById('legendInputTokens').textContent = totalInput.toLocaleString();
  document.getElementById('legendOutputTokens').textContent = totalOutput.toLocaleString();
  document.getElementById('legendTotalTokens').textContent = (totalInput + totalOutput).toLocaleString();

  mainChart = new ApexCharts(document.getElementById('mainChart'), {
    series: [
      { name: 'Input Tokens', data: tokenHistory.map(d => d.input) },
      { name: 'Output Tokens', data: tokenHistory.map(d => d.output) }
    ],
    chart: {
      type: 'area',
      height: 260,
      stacked: true,
      toolbar: { show: false },
      background: 'transparent',
      animations: { enabled: true, easing: 'easeinout', speed: 800 }
    },
    colors: [colors.line, colors.accent],
    stroke: { width: 2, curve: 'smooth' },
    fill: {
      type: 'gradient',
      gradient: { opacityFrom: 0.4, opacityTo: 0.1 }
    },
    xaxis: {
      categories: tokenHistory.map(d => d.date),
      labels: { style: { colors: colors.text, fontSize: '10px' } },
      axisBorder: { show: false },
      axisTicks: { show: false }
    },
    yaxis: {
      labels: {
        style: { colors: colors.text, fontSize: '10px' },
        formatter: v => v >= 1000 ? (v / 1000).toFixed(1) + 'k' : v
      }
    },
    grid: {
      borderColor: colors.grid,
      strokeDashArray: 0
    },
    legend: { show: false },
    tooltip: {
      theme: theme === 'frost' || theme === 'dawn' ? 'light' : 'dark',
      y: { formatter: v => v.toLocaleString() + ' tokens' }
    }
  });

  mainChart.render();
}

// ==========================================
// GIT GRAPH
// ==========================================

function renderGitGraph() {
  const graphContainer = document.getElementById('gitFilesList');
  if (!graphContainer || !data.git?.commits) return;

  const commits = data.git.commits.slice(0, 8);

  graphContainer.innerHTML = `
    <div class="git-graph">
      ${commits.map(c => `
        <div class="git-commit-row">
          <div class="git-graph-line">
            <div class="git-graph-dot"></div>
          </div>
          <span class="git-commit-hash">${c.hash}</span>
          <span class="git-commit-message">${c.message}</span>
          <span class="git-commit-date">${c.date}</span>
        </div>
      `).join('')}
    </div>
  `;
}

// ==========================================
// GANTT CHART FOR WAVES (Professional)
// ==========================================

function renderWavesGantt() {
  const wavesList = document.getElementById('wavesList');
  if (!wavesList || !data.waves || data.waves.length === 0) {
    if (wavesList) wavesList.innerHTML = '<div class="waves-loading">No waves</div>';
    return;
  }

  const now = new Date();

  // Find earliest and latest dates from wave planned dates
  let minDate = null;
  let maxDate = null;

  data.waves.forEach(wave => {
    const start = wave.planned_start ? new Date(wave.planned_start) : null;
    const end = wave.planned_end ? new Date(wave.planned_end) : null;

    if (start && (!minDate || start < minDate)) minDate = start;
    if (end && (!maxDate || end > maxDate)) maxDate = end;
  });

  // Fallback if no planned dates
  if (!minDate) minDate = new Date(now.getTime() - 86400000);
  if (!maxDate) maxDate = new Date(now.getTime() + 7 * 86400000);

  // Add padding
  const padding = 12 * 3600000; // 12 hours
  minDate = new Date(minDate.getTime() - padding);
  maxDate = new Date(maxDate.getTime() + padding);

  const totalMs = maxDate - minDate;
  const totalDays = Math.ceil(totalMs / 86400000);

  // Generate time headers based on total duration
  const headers = [];
  if (totalDays <= 3) {
    // Show hours for short durations
    for (let t = minDate.getTime(); t <= maxDate.getTime(); t += 6 * 3600000) {
      const d = new Date(t);
      headers.push({
        label: d.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit' }),
        time: t
      });
    }
  } else {
    // Show days
    for (let i = 0; i <= totalDays; i++) {
      const d = new Date(minDate.getTime() + i * 86400000);
      headers.push({
        label: d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
        time: d.getTime()
      });
    }
  }

  // Calculate today marker position
  const todayPos = ((now - minDate) / totalMs) * 100;
  const showToday = todayPos >= 0 && todayPos <= 100;

  // Build dependency map
  const waveMap = {};
  data.waves.forEach(w => { waveMap[w.wave_id] = w; });

  wavesList.innerHTML = `
    <div class="gantt-container">
      <div class="gantt-header">
        <div class="gantt-header-label">WAVE</div>
        <div class="gantt-header-timeline">
          ${headers.map(h => `<div class="gantt-header-day">${h.label}</div>`).join('')}
        </div>
      </div>
      <div class="gantt-body">
        ${showToday ? `<div class="gantt-today-marker" style="left:calc(200px + ${todayPos}% * (100% - 200px) / 100);" title="Today"></div>` : ''}
        ${data.waves.map((wave, idx) => {
          const start = wave.planned_start ? new Date(wave.planned_start) : null;
          const end = wave.planned_end ? new Date(wave.planned_end) : null;
          const actual_start = wave.started_at ? new Date(wave.started_at) : null;
          const actual_end = wave.completed_at ? new Date(wave.completed_at) : null;

          // Calculate planned bar position
          let plannedLeft = 0, plannedWidth = 5;
          if (start && end) {
            plannedLeft = ((start - minDate) / totalMs) * 100;
            plannedWidth = Math.max(2, ((end - start) / totalMs) * 100);
          }

          // Calculate actual bar position (if started)
          let actualLeft = plannedLeft, actualWidth = 0;
          if (actual_start) {
            actualLeft = ((actual_start - minDate) / totalMs) * 100;
            const actualEndTime = actual_end || now;
            actualWidth = Math.max(1, ((actualEndTime - actual_start) / totalMs) * 100);
          }

          // Progress
          const progress = wave.tasks_total > 0 ? Math.round((wave.tasks_done / wave.tasks_total) * 100) : 0;

          // Format dates for tooltip
          const startStr = start ? start.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'Not planned';
          const endStr = end ? end.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'Not planned';

          // Dependency indicator
          const hasDeps = wave.depends_on && wave.depends_on.length > 0;

          return `
            <div class="gantt-row" onclick="drillIntoWave('${wave.wave_id}')" title="${wave.name}&#10;Start: ${startStr}&#10;End: ${endStr}&#10;Progress: ${progress}%">
              <div class="gantt-label">
                <div class="gantt-label-status ${wave.status}"></div>
                <div class="gantt-label-info">
                  <span class="gantt-label-text">${wave.wave_id}</span>
                  ${hasDeps ? `<span class="gantt-dep-badge" title="Depends on: ${wave.depends_on}">&#x2192; ${wave.depends_on}</span>` : ''}
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

// ==========================================
// ENHANCED SHOWVIEW
// ==========================================

const originalShowView = showView;
showView = function(view) {
  currentView = view;

  // Update nav menu active state
  document.querySelectorAll('.nav-menu a').forEach(a => {
    a.classList.remove('active');
    const linkText = a.textContent.toLowerCase();
    if (linkText.includes(view) || (view === 'bugs' && linkText.includes('bugs'))) {
      a.classList.add('active');
    }
  });

  // All view elements
  const dashboardElements = ['wavesSummary', 'drilldownPanel'];
  const chartCard = document.querySelector('.chart-card');
  const tradersSection = document.querySelector('.traders-section');
  const kanbanView = document.getElementById('kanbanView');
  const wavesView = document.getElementById('wavesView');
  const bugsView = document.getElementById('bugsView');
  const agentsView = document.getElementById('agentsView');
  const notificationsView = document.getElementById('notificationsView');
  const statsRow = document.querySelector('.stats-row');
  const epochBar = document.querySelector('.epoch-bar');
  const planLabel = document.querySelector('.stats-label');

  // Hide all specialized views first
  [kanbanView, wavesView, bugsView, agentsView, notificationsView].forEach(v => {
    if (v) v.style.display = 'none';
  });

  // Hide/show dashboard elements based on view
  const hideDashboard = view !== 'dashboard';
  dashboardElements.forEach(id => {
    const el = document.getElementById(id);
    if (el) el.style.display = hideDashboard ? 'none' : '';
  });
  if (chartCard) chartCard.style.display = hideDashboard ? 'none' : '';
  if (tradersSection) tradersSection.style.display = hideDashboard ? 'none' : '';
  if (statsRow) statsRow.style.display = hideDashboard ? 'none' : '';
  if (epochBar) epochBar.style.display = hideDashboard ? 'none' : '';
  if (planLabel) planLabel.style.display = hideDashboard ? 'none' : '';

  // Show the selected view and load its data
  switch (view) {
    case 'kanban':
      if (kanbanView) kanbanView.style.display = 'block';
      loadKanban();
      break;
    case 'waves':
      if (wavesView) wavesView.style.display = 'block';
      loadWavesView();
      break;
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
      // Dashboard elements are already shown
      // Render token chart instead of progress chart
      if (chartMode === 'tokens') {
        destroyCharts();
        renderTokenChart();
        renderAgents();
      }
      break;
  }
};

// ==========================================
// ENHANCED RENDER - Use Gantt for waves
// ==========================================

const baseRender = render;
render = function() {
  // Header
  document.getElementById('projectName').textContent = data.meta.project;
  document.getElementById('planLabel').textContent = data.meta.project;
  document.getElementById('throughputBadge').textContent = data.metrics.throughput.percent + '%';

  // Stats - real data or n/d
  document.getElementById('tasksDone').textContent = `${data.metrics.throughput.done}/${data.metrics.throughput.total}`;
  document.getElementById('tokensUsed').textContent = data.tokens?.total ? data.tokens.total.toLocaleString() : 'n/d';
  document.getElementById('avgTokensPerTask').textContent = data.tokens?.avgPerTask ? data.tokens.avgPerTask.toLocaleString() : 'n/d';
  const wavesDone = data.waves.filter(w => w.status === 'done').length;
  document.getElementById('wavesStatus').textContent = `${wavesDone}/${data.waves.length}`;
  document.getElementById('progressPercent').textContent = data.metrics.throughput.percent + '%';

  // Epoch bar
  const currentWave = data.waves.find(w => w.status === 'in_progress') || data.waves[data.waves.length - 1];
  if (currentWave) {
    document.getElementById('currentWave').textContent = currentWave.id + ' - ' + currentWave.name;
  }

  const start = data.timeline.start.replace('T', ' ').slice(0, 16);
  const eta = data.timeline.eta.replace('T', ' ').slice(0, 16);
  document.getElementById('epochDates').innerHTML = start + ' &#8212; ' + eta;
  document.getElementById('countdown').textContent = data.timeline.remaining + ' left';

  // Calculate progress percentage for epoch bar
  const totalTasks = data.metrics.throughput.total;
  const doneTasks = data.metrics.throughput.done;
  const epochProgress = totalTasks > 0 ? Math.round((doneTasks / totalTasks) * 100) : 0;
  document.getElementById('epochFill').style.width = epochProgress + '%';

  // Git
  if (data.git) {
    document.getElementById('gitBranch').textContent = data.git.currentBranch;
    renderGitTab();
    renderGitGraph();
  }

  // Update right panel
  updateHealthStatus();
  renderIssuesPanel();
  renderTokensTab();

  // Use Gantt chart for waves
  renderWavesGantt();

  // Token chart instead of progress chart
  if (chartMode === 'tokens') {
    renderTokenChart();
  } else {
    renderChart();
  }
  renderAgents();
};

// Start notification polling on init
const originalInit = init;
init = async function() {
  await originalInit();
  startNotificationPolling();
};

document.addEventListener('DOMContentLoaded', init);
