// Voltrex-style Plan Dashboard - Pixel Perfect
let data = null;
let mainChart = null;
let sparkCharts = [];

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
    const res = await fetch('plan.json');
    data = await res.json();
    render();
  } catch (e) {
    document.querySelector('.main-content').innerHTML = `<div style="padding:40px;color:#ef4444;">Error: ${e.message}</div>`;
  }
}

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
          <button class="trader-btn mock">Details</button>
          <button class="trader-btn copy">Assign</button>
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

document.addEventListener('DOMContentLoaded', init);
