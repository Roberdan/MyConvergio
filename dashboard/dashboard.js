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

async function loadProjects() {
  try {
    const res = await fetch('../plans/registry.json');
    registry = await res.json();
    renderProjectList();
  } catch (e) {
    console.log('No registry found, using local plan.json');
    registry = { projects: {} };
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

  // Load project's current.json
  try {
    const res = await fetch(`../plans/${projectId}/current.json`);
    data = await res.json();
    render();
    renderProjectList();
  } catch (e) {
    console.error('Failed to load project plan:', e);
    // Fallback to local plan.json
    const res = await fetch('plan.json');
    data = await res.json();
    render();
  }
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
  // TODO: Fetch from SQLite via API or show modal with stats
  const stats = {
    totalPlans: Object.keys(registry?.projects || {}).length,
    message: 'Learning stats will show plan modification patterns and optimization insights.'
  };
  alert(`Learning Stats\n\nTotal Projects: ${stats.totalPlans}\n\n${stats.message}`);
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

  // Stats - format like Voltrex with $ prefix for first value
  document.getElementById('tasksDone').textContent = '$' + data.metrics.throughput.done;
  document.getElementById('velocity').textContent = data.metrics.velocity.value + '/h';
  document.getElementById('cycleTime').textContent = data.metrics.cycleTime.value + 'min';
  document.getElementById('bugsFixed').textContent = `${data.bugs.fixed}/${data.bugs.total}`;
  document.getElementById('quality').textContent = data.metrics.quality.score + '%';

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

  // PR panel
  if (data.github) {
    document.getElementById('prAdditions').textContent = '+' + data.github.pr.additions;
    document.getElementById('prDeletions').textContent = '-' + data.github.pr.deletions;
    document.getElementById('prNumber').textContent = data.github.pr.number;
    document.getElementById('prFiles').textContent = data.github.pr.files;
    document.getElementById('prTitle').value = data.github.pr.title;
    document.getElementById('sliderValue').textContent = data.metrics.throughput.percent + '%';
    document.getElementById('sliderThumb').style.left = data.metrics.throughput.percent + '%';
    document.getElementById('viewPrBtn').onclick = () => window.open(data.github.pr.url, '_blank');
  }

  // Git branch
  if (data.git) {
    document.getElementById('gitBranch').textContent = data.git.currentBranch;
  }

  // Alert/blocker
  if (data.alerts && data.alerts.length > 0) {
    const blocker = data.alerts.find(a => a.type === 'blocker') || data.alerts[0];
    document.getElementById('blockerTitle').textContent = blocker.title;
    document.getElementById('blockerDesc').textContent = blocker.desc;
  }

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
  ['alerts', 'git', 'debt', 'history'].forEach(t => {
    const tab = document.getElementById('tab' + t.charAt(0).toUpperCase() + t.slice(1));
    const btn = document.querySelector(`.about-tab[onclick="showTab('${t}')"]`);
    if (tab) tab.style.display = t === tabName ? 'block' : 'none';
    if (btn) btn.classList.toggle('active', t === tabName);
  });

  if (tabName === 'git' && data.git?.uncommitted) {
    renderGitTree();
  }
  if (tabName === 'debt' && data.debt) {
    renderDebt();
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
    if (a.textContent.toLowerCase().includes(view)) {
      a.classList.add('active');
    }
  });

  // Toggle view visibility
  const dashboardElements = ['wavesSummary', 'drilldownPanel'];
  const chartCard = document.querySelector('.chart-card');
  const tradersSection = document.querySelector('.traders-section');
  const kanbanView = document.getElementById('kanbanView');
  const statsRow = document.querySelector('.stats-row');
  const epochBar = document.querySelector('.epoch-bar');

  if (view === 'kanban') {
    dashboardElements.forEach(id => {
      const el = document.getElementById(id);
      if (el) el.style.display = 'none';
    });
    if (chartCard) chartCard.style.display = 'none';
    if (tradersSection) tradersSection.style.display = 'none';
    if (statsRow) statsRow.style.display = 'none';
    if (epochBar) epochBar.style.display = 'none';
    if (kanbanView) kanbanView.style.display = 'block';
    loadKanban();
  } else {
    dashboardElements.forEach(id => {
      const el = document.getElementById(id);
      if (el) el.style.display = '';
    });
    if (chartCard) chartCard.style.display = '';
    if (tradersSection) tradersSection.style.display = '';
    if (statsRow) statsRow.style.display = '';
    if (epochBar) epochBar.style.display = '';
    if (kanbanView) kanbanView.style.display = 'none';
  }
}

async function loadKanban() {
  if (!registry) await loadProjects();

  const kanban = { todo: [], doing: [], done: [] };

  // Scan all projects for plans
  for (const [projectId, project] of Object.entries(registry.projects || {})) {
    for (const status of ['todo', 'doing', 'done']) {
      try {
        // Try to fetch plan list from each status folder
        const planFiles = await fetchPlanList(projectId, status);
        planFiles.forEach(plan => {
          kanban[status].push({
            project: project.name,
            projectId: projectId,
            name: plan.name,
            file: plan.file,
            progress: plan.progress || 0,
            updated: plan.updated
          });
        });
      } catch (e) {
        // Folder might not exist or be empty
      }
    }
  }

  renderKanban(kanban);
}

async function fetchPlanList(projectId, status) {
  // Try to read current.json to get plan info
  try {
    const res = await fetch(`plans/${projectId}/current.json`);
    if (!res.ok) return [];
    const current = await res.json();

    // If we have an active plan and status is 'doing', include it
    if (status === 'doing' && current.active_plan) {
      return [{
        name: current.active_plan,
        file: `${current.active_plan}.json`,
        progress: 50, // Default, would need to read actual file
        updated: current.updated
      }];
    }

    // For done, check if last_completed exists
    if (status === 'done' && current.last_completed) {
      return [{
        name: current.last_completed,
        file: `${current.last_completed}.json`,
        progress: 100,
        updated: current.updated
      }];
    }

    return [];
  } catch (e) {
    return [];
  }
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

    container.innerHTML = plans.map(plan => `
      <div class="kanban-card" onclick="selectProject('${plan.projectId}'); showView('dashboard');">
        <div class="kanban-card-project">${plan.project}</div>
        <div class="kanban-card-title">${plan.name}</div>
        <div class="kanban-card-meta">
          <span>${plan.progress}%</span>
          <span>${plan.updated ? new Date(plan.updated).toLocaleDateString() : ''}</span>
        </div>
        <div class="kanban-card-progress">
          <div class="kanban-card-progress-fill" style="width: ${plan.progress}%"></div>
        </div>
      </div>
    `).join('');
  });
}

document.addEventListener('DOMContentLoaded', init);
