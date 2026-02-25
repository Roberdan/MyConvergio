// Main Rendering Functions

function updateNavCounts() {
  const kanbanCount = document.getElementById('navKanbanCount');
  const tasksCount = document.getElementById('navTasksCount');

  if (tasksCount && data.metrics?.throughput) {
    const done = data.metrics.throughput.done || 0;
    const total = data.metrics.throughput.total || 0;
    tasksCount.textContent = total > 0 ? `${done}/${total}` : '';
  }
}

function render() {
  const statsRow = document.getElementById('statsRow');
  const emptyState = document.getElementById('emptyState');

  // Check if we have valid data
  if (!data || !data.metrics || !data.metrics.throughput) {
    // Show empty state
    if (statsRow) statsRow.style.display = 'none';
    if (emptyState) emptyState.style.display = 'flex';
    return;
  }

  // Show stats row and hide empty state
  if (statsRow) statsRow.style.display = 'flex';
  if (emptyState) emptyState.style.display = 'none';

  // Helper to safely set text content
  const setText = (id, value) => {
    const el = document.getElementById(id);
    if (el) el.textContent = value;
  };

  // Header
  setText('projectName', data.meta.project);
  const planLabelEl = document.getElementById('planLabel');
  if (planLabelEl) {
    const planId = data.meta.plan_id ? `<span class="plan-label-id">#${data.meta.plan_id}</span> ` : '';
    planLabelEl.innerHTML = planId + (data.meta.project || '');
  }
  setText('throughputBadge', data.metrics.throughput.percent + '%');

  // Stats with better formatting
  const done = data.metrics.throughput.done || 0;
  const total = data.metrics.throughput.total || 0;
  setText('tasksDone', total > 0 ? `${done}/${total}` : '-');

  const tokensTotal = data.tokens?.total;
  setText('tokensUsed', tokensTotal ? formatTokens(tokensTotal) : '-');

  const avgTokens = data.tokens?.avgPerTask;
  setText('avgTokensPerTask', avgTokens ? formatTokens(avgTokens) : '-');

  setText('progressPercent', total > 0 ? data.metrics.throughput.percent + '%' : '-');

  // Execution time calculation
  const execTime = calculateExecTime(data.meta?.started_at, data.meta?.completed_at);
  setText('execTime', execTime);

  // Thor validation status
  renderThorStatus(data.meta?.validated_at, data.meta?.validated_by);

  // Charts only if there are waves

  // Git
  if (data.git) {
    const gitBranchEl = document.getElementById('gitCurrentBranchName');
    if (gitBranchEl) gitBranchEl.textContent = data.git.currentBranch;
    renderGitTab();
    renderGitGraph();
  }

  // Update panels
  updateHealthStatus();
  renderRiskAlerts();
  renderIssuesPanel();
  renderTokensTab();
  // Only render Gantt in dashboard view
  if (currentView === 'dashboard') {
    GanttView.render();
  }
  updateNavCounts();

  // Render unified waves card
  if (typeof renderUnifiedWaves === 'function') {
    renderUnifiedWaves();
  }

  // Initialize bug list
  if (typeof initBugTracker === 'function') {
    initBugTracker();
  }

  // Charts
  destroyCharts();
  if (chartMode === 'tokens') {
    renderTokenChart();
  } else {
    renderChart();
  }
  renderAgents();
}

function renderRiskAlerts() {
  const listEl = document.getElementById('riskAlertsList');
  if (!listEl) return;

  const alerts = [];
  const now = Date.now();
  const staleMs = 24 * 60 * 60 * 1000;
  const planId = data?.meta?.plan_id;
  const projectId = currentProjectId;

  if (planId) {
    const status = data?.meta?.status || 'todo';
    // Skip risk alerts for cancelled plans
    if (status === 'cancelled') {
      if (alerts.length === 0) {
        listEl.innerHTML = '<div class="risk-empty">No alerts</div>';
        return;
      }
    }
    const tasksDone = data?.meta?.tasks_done || 0;
    const tasksTotal = data?.meta?.tasks_total || 0;
    const validatedAt = data?.meta?.validated_at;
    const startedAt = data?.meta?.started_at ? DateUtils.parseUTC(data.meta.started_at).getTime() : null;

    if (status === 'done' && (tasksTotal === 0 || tasksDone < tasksTotal)) {
      alerts.push({ level: 'error', text: 'Plan marked done but tasks are incomplete.', planId, projectId });
    }
    if (status === 'done' && !validatedAt && tasksTotal > 0) {
      alerts.push({ level: 'error', text: 'Plan marked done without Thor validation.', planId, projectId });
    }
    if (tasksTotal === 0 && status !== 'todo') {
      alerts.push({ level: 'warn', text: 'Plan has no tasks but is not in todo.', planId, projectId });
    }
    if (status === 'doing' && startedAt && now - startedAt > staleMs) {
      alerts.push({ level: 'warn', text: 'Plan in progress for more than 24h.', planId, projectId });
    }
    if (!validatedAt && tasksTotal > 0 && tasksDone >= tasksTotal) {
      alerts.push({ level: 'info', text: 'All tasks done; awaiting Thor validation.', planId, projectId });
    }
  } else if (Array.isArray(data?.waves)) {
    data.waves.forEach(w => {
      const status = w.status || 'todo';
      if (status === 'cancelled') return; // Skip cancelled waves
      const done = w.done || 0;
      const total = w.total || 0;
      const validatedAt = w.validated_at;
      const startedAt = w.started_at ? DateUtils.parseUTC(w.started_at).getTime() : null;
      const label = w.name || w.id || 'Plan';
      const waveId = w.id || w.plan_id;

      if (status === 'done' && (total === 0 || done < total)) {
        alerts.push({ level: 'error', text: `${label}: done but tasks incomplete.`, planId: waveId, projectId });
      }
      if (status === 'done' && total > 0 && !validatedAt) {
        alerts.push({ level: 'error', text: `${label}: done without Thor validation.`, planId: waveId, projectId });
      }
      if (total === 0 && status !== 'todo') {
        alerts.push({ level: 'warn', text: `${label}: no tasks but not todo.`, planId: waveId, projectId });
      }
      if (status === 'doing' && startedAt && now - startedAt > staleMs) {
        alerts.push({ level: 'warn', text: `${label}: in progress over 24h.`, planId: waveId, projectId });
      }
    });
  }

  if (alerts.length === 0) {
    listEl.innerHTML = '<div class="risk-empty">No alerts</div>';
    return;
  }

  listEl.innerHTML = alerts.map(a => {
    const clickable = a.planId && a.projectId;
    const clickAttr = clickable ? `onclick="navigateToRiskSource('${a.planId}', '${a.projectId}')"` : '';
    const clickClass = clickable ? 'clickable' : '';
    return `
      <div class="risk-alert-item ${a.level} ${clickClass}" ${clickAttr} title="${clickable ? 'Click to view plan' : ''}">
        <span class="risk-alert-dot"></span>
        <span>${a.text}</span>
        ${clickable ? '<span class="risk-alert-arrow">→</span>' : ''}
      </div>
    `;
  }).join('');
}

function navigateToRiskSource(planId, projectId) {
  if (typeof activatePlanAndNavigate === 'function') {
    activatePlanAndNavigate(planId, projectId);
  } else {
    showToast('Navigation not available', 'warning');
  }
}

window.navigateToRiskSource = navigateToRiskSource;

function renderChart() {
  // Clear any existing chart content to prevent stale data
  const chartContainer = document.getElementById('mainChart');
  if (chartContainer) {
    chartContainer.innerHTML = '';
  }

  const times = data.timeline.data.map(d => d.time);
  const done = data.timeline.data.map(d => d.done);
  const theme = document.documentElement.getAttribute('data-theme') || 'voltrex';
  const colors = themeColors[theme];

  mainChart = new ApexCharts(chartContainer, {
    series: [{ name: 'Completed', data: done }],
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
      labels: { style: { colors: colors.text, fontSize: '10px' }, rotate: 0 },
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
      custom: ({ series, dataPointIndex, w }) => {
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
  if (!grid) return;
  
  const contributors = data?.contributors || [];
  if (contributors.length === 0) {
    grid.innerHTML = '<div class="cc-empty">No agents</div>';
    return;
  }
  
  grid.innerHTML = contributors.map((c, i) => {
    const isActive = c.status === 'active';
    const statusClass = isActive ? 'active' : c.status === 'idle' ? 'idle' : 'offline';
    const statusDot = isActive ? '●' : '○';
    return `
      <div class="trader-card ${statusClass}">
        <div class="trader-top">
          <div class="trader-avatar">${c.avatar}</div>
          <div class="trader-info">
            <div class="trader-name">${c.name}</div>
            <div class="trader-role">${c.role || 'Agent'}</div>
          </div>
          <div class="trader-status-indicator ${statusClass}" title="${c.status}">${statusDot}</div>
        </div>
        <div class="trader-stats-inline">
          <div class="trader-stat-inline">
            <span class="stat-icon">✓</span>
            <span class="stat-value">${c.tasks || 0}</span>
            <span class="stat-label">tasks</span>
          </div>
          <div class="trader-stat-inline">
            <span class="stat-icon">⏱</span>
            <span class="stat-value">${c.totalTime || '-'}</span>
          </div>
          <div class="trader-stat-inline">
            <span class="stat-icon">◎</span>
            <span class="stat-value">${c.tokens ? (c.tokens / 1000).toFixed(1) + 'k' : '-'}</span>
          </div>
        </div>
        ${isActive && c.currentTask ? `
          <div class="trader-current-task">
            <span class="current-label">Working on:</span>
            <span class="current-value">${c.currentTask}</span>
          </div>
        ` : ''}
        <div class="trader-chart" id="spark${i}"></div>
      </div>
    `;
  }).join('');

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
  if (isActive) {
    points[points.length - 1] = Math.max(...points) * 1.1;
  }
  return points;
}

function showAgentDetails(agentId) {
  const agent = data.contributors?.find(c => c.id === agentId);
  if (!agent) return;
  alert(`Agent: ${agent.name}\nRole: ${agent.role}\nTasks: ${agent.tasks}\nStatus: ${agent.status}\nEfficiency: ${agent.efficiency || '-'}%`);
}

// Export button handler - Screenshot
document.getElementById('exportBtn')?.addEventListener('click', async () => {
  try {
    showToast('Capturing screenshot...', 'info');
    const mainWrap = document.querySelector('.main-wrap');
    if (!mainWrap) return;

    // Use html2canvas if available, otherwise use browser print
    if (typeof html2canvas !== 'undefined') {
      const canvas = await html2canvas(mainWrap, { backgroundColor: '#0d1117', scale: 2 });
      const link = document.createElement('a');
      link.download = `dashboard-${data.meta?.project || 'export'}-${Date.now()}.png`;
      link.href = canvas.toDataURL('image/png');
      link.click();
      showToast('Screenshot saved!', 'success');
    } else {
      // Fallback: open print dialog
      window.print();
    }
  } catch (e) {
    showToast('Screenshot failed: ' + e.message, 'error');
  }
});

// Open PR button
document.querySelector('.max-btn')?.addEventListener('click', () => {
  if (data.github?.pr?.url) {
    window.open(data.github.pr.url, '_blank');
  }
});

async function loadAgentsView() {
  const gridView = document.getElementById('agentsGridView');
  if (!gridView || !data.contributors) {
    if (gridView) gridView.innerHTML = '<div class="agents-empty">No agent data available</div>';
    return;
  }
  gridView.innerHTML = data.contributors.map((c, i) => `
    <div class="agent-card">
      <div class="agent-header">
        <div class="agent-avatar">${c.avatar || '🤖'}</div>
        <div class="agent-info">
          <div class="agent-name">${c.name}</div>
          <div class="agent-status ${c.status}">${c.status}</div>
        </div>
      </div>
      <div class="agent-stats">
        <div class="agent-stat">
          <span class="agent-stat-value">${c.tasks}</span>
          <span class="agent-stat-label">Tasks</span>
        </div>
        <div class="agent-stat">
          <span class="agent-stat-value">${c.efficiency || '-'}%</span>
          <span class="agent-stat-label">Efficiency</span>
        </div>
      </div>
    </div>
  `).join('');
}

function showAgentDetails(agentId) {
  const agent = data.contributors?.find(c => c.id === agentId);
  if (!agent) return;
  showToast(`Agent: ${agent.name}\nRole: ${agent.role || 'N/A'}\nTasks: ${agent.tasks}\nStatus: ${agent.status}\nEfficiency: ${agent.efficiency || '-'}%`, 'info');
}

// Format tokens with K/M suffix
function formatTokens(num) {
  if (!num || num === 0) return '-';
  if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
  if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
  return num.toLocaleString();
}

// Calculate execution time from start to end (or now if in progress)
function calculateExecTime(startedAt, completedAt) {
  if (!startedAt) return '-';
  const start = DateUtils.parseUTC(startedAt);
  const end = completedAt ? DateUtils.parseUTC(completedAt) : new Date();
  const diffMs = end - start;
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMins / 60);
  const diffDays = Math.floor(diffHours / 24);
  if (diffDays > 0) return `${diffDays}d ${diffHours % 24}h`;
  if (diffHours > 0) return `${diffHours}h ${diffMins % 60}m`;
  return `${diffMins}m`;
}

// Render Thor validation status icon
function renderThorStatus(validatedAt, validatedBy) {
  const iconEl = document.getElementById('thorIcon');
  const labelEl = document.getElementById('thorLabel');
  if (!iconEl || !labelEl) return;

  if (validatedAt) {
    iconEl.className = 'thor-icon verified';
    iconEl.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
      <polyline points="20 6 9 17 4 12"/>
    </svg>`;
    labelEl.textContent = 'Thor';
    labelEl.style.color = 'var(--green)';
    iconEl.title = `Validated by ${validatedBy || 'Thor'} on ${new Date(validatedAt).toLocaleString('it-IT')}`;
  } else {
    iconEl.className = 'thor-icon pending';
    iconEl.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <circle cx="12" cy="12" r="10"/>
      <path d="M12 6v6l4 2"/>
    </svg>`;
    labelEl.textContent = 'Pending';
    labelEl.style.color = 'var(--text-dim)';
    iconEl.title = 'Thor validation pending';
  }
}
