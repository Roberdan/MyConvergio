// Main Rendering Functions

function updateNavCounts() {
  const kanbanCount = document.getElementById('navKanbanCount');
  const wavesCount = document.getElementById('navWavesCount');
  const issuesCount = document.getElementById('navIssuesCount');

  if (kanbanCount && data.waves) {
    const activeWaves = data.waves.filter(w => w.status === 'in_progress').length;
    kanbanCount.textContent = activeWaves > 0 ? activeWaves : '';
  }

  if (wavesCount && data.waves) {
    wavesCount.textContent = data.waves.length > 0 ? data.waves.length : '';
  }

  if (issuesCount && data.github?.issues) {
    const count = data.github.issues.length;
    issuesCount.textContent = count > 0 ? count : '';
  }
}

function render() {
  // Header
  document.getElementById('projectName').textContent = data.meta.project;
  document.getElementById('planLabel').textContent = data.meta.project;
  document.getElementById('throughputBadge').textContent = data.metrics.throughput.percent + '%';

  // Stats
  document.getElementById('tasksDone').textContent = `${data.metrics.throughput.done}/${data.metrics.throughput.total}`;
  document.getElementById('tokensUsed').textContent = data.tokens?.total ? data.tokens.total.toLocaleString() : 'n/d';
  document.getElementById('avgTokensPerTask').textContent = data.tokens?.avgPerTask ? data.tokens.avgPerTask.toLocaleString() : 'n/d';
  const wavesDone = data.waves.filter(w => w.status === 'done').length;
  document.getElementById('wavesStatus').textContent = `${wavesDone}/${data.waves.length}`;
  document.getElementById('progressPercent').textContent = data.metrics.throughput.percent + '%';

  // Epoch bar - only show if there are waves
  const waveIndicator = document.getElementById('waveIndicator');
  if (data.waves && data.waves.length > 0) {
    const currentWave = data.waves.find(w => w.status === 'in_progress') || data.waves[data.waves.length - 1];
    if (currentWave) {
      document.getElementById('currentWave').textContent = currentWave.id + ' - ' + currentWave.name;
    }

    const start = data.timeline?.start ? data.timeline.start.replace('T', ' ').slice(0, 16) : '-';
    const eta = data.timeline?.eta ? data.timeline.eta.replace('T', ' ').slice(0, 16) : '-';
    document.getElementById('epochDates').innerHTML = start + ' &#8212; ' + eta;
    document.getElementById('countdown').textContent = data.timeline?.remaining ? data.timeline.remaining + ' left' : '-';

    const totalTasks = data.metrics.throughput.total;
    const doneTasks = data.metrics.throughput.done;
    const epochProgress = totalTasks > 0 ? Math.round((doneTasks / totalTasks) * 100) : 0;
    document.getElementById('epochFill').style.width = epochProgress + '%';

    if (waveIndicator) waveIndicator.style.display = '';
  } else {
    // No waves - hide indicator
    if (waveIndicator) waveIndicator.style.display = 'none';
    document.getElementById('currentWave').textContent = '-';
    document.getElementById('countdown').textContent = '-';
    document.getElementById('epochFill').style.width = '0%';
  }

  // Git
  if (data.git) {
    const gitBranchEl = document.getElementById('gitCurrentBranchName');
    if (gitBranchEl) gitBranchEl.textContent = data.git.currentBranch;
    renderGitTab();
    renderGitGraph();
  }

  // Update panels
  updateHealthStatus();
  renderIssuesPanel();
  renderTokensTab();
  // Only render Gantt in dashboard view, not in waves drilldown view
  if (currentView === 'dashboard' || currentView === 'control-center') {
    renderWavesGantt();
  }
  updateNavCounts();

  // Show/hide waves summary based on data
  const wavesSummary = document.getElementById('wavesSummary');
  if (wavesSummary) {
    wavesSummary.style.display = (data.waves && data.waves.length > 0) ? '' : 'none';
  }

  // Charts
  if (chartMode === 'tokens') {
    renderTokenChart();
  } else {
    renderChart();
  }
  renderAgents();
}

function renderChart() {
  const times = data.timeline.data.map(d => d.time);
  const done = data.timeline.data.map(d => d.done);
  const theme = document.documentElement.getAttribute('data-theme') || 'voltrex';
  const colors = themeColors[theme];

  mainChart = new ApexCharts(document.getElementById('mainChart'), {
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
        <div class="trader-profit">+${c.tasks.toLocaleString()} tasks</div>
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
