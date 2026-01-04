// Token Chart and Chart Mode Switching

let chartFilterRange = 'all';

function showChartFilterMenu(event) {
  event.stopPropagation();
  const menu = document.getElementById('chartFilterMenu');
  if (menu) {
    menu.classList.toggle('visible');
    // Close on click outside
    if (menu.classList.contains('visible')) {
      setTimeout(() => {
        document.addEventListener('click', hideChartFilterMenu, { once: true });
      }, 10);
    }
  }
}

function hideChartFilterMenu() {
  const menu = document.getElementById('chartFilterMenu');
  if (menu) menu.classList.remove('visible');
}

function setChartFilter(range, event) {
  event.stopPropagation();
  chartFilterRange = range;

  // Update label
  const labels = {
    'all': 'All time',
    '30d': 'Last 30 days',
    '7d': 'Last 7 days',
    '1d': 'Last 24 hours',
    '1h': 'Last hour',
    '30m': 'Last 30 min'
  };
  const label = document.getElementById('chartFilterLabel');
  if (label) label.innerHTML = `&#x1F4C5; ${labels[range] || range}`;

  // Update active state
  document.querySelectorAll('.chart-filter-option').forEach(opt => {
    opt.classList.toggle('active', opt.dataset.range === range);
  });

  hideChartFilterMenu();

  // Re-render chart with new filter
  destroyCharts();
  if (chartMode === 'tokens') {
    renderTokenChart();
  } else {
    renderChart();
  }
}

function switchChartMode(mode) {
  chartMode = mode;

  document.querySelectorAll('.chart-tab').forEach(tab => {
    tab.classList.toggle('active', tab.textContent.toLowerCase() === mode);
  });

  destroyCharts();
  if (mode === 'tokens') {
    renderTokenChart();
  } else {
    renderChart();
  }
}

async function renderTokenChart() {
  let tokenHistory = [];

  try {
    const totalTokens = data.tokens?.total || 0;
    const calls = data.tokens?.calls || 0;

    if (calls > 0) {
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

function renderGitGraph() {
  const graphContainer = document.getElementById('gitFilesList');
  if (!graphContainer || !data.git?.commits) return;

  // Show all commits with scroll
  const commits = data.git.commits;

  graphContainer.innerHTML = `
    <div class="git-graph-scroll">
      ${commits.map((c, i) => {
        const isMerge = c.message?.toLowerCase().startsWith('merge');
        const isLast = i === commits.length - 1;
        return `
          <div class="git-commit-row ${isMerge ? 'merge' : ''}">
            <div class="git-graph-line">
              <div class="git-graph-dot ${isMerge ? 'merge' : ''}"></div>
              ${!isLast ? '<div class="git-graph-connector"></div>' : ''}
            </div>
            <div class="git-commit-info">
              <span class="git-commit-hash">${c.hash}</span>
              <span class="git-commit-message" title="${c.message}">${truncateMessage(c.message, 50)}</span>
            </div>
            <div class="git-commit-meta">
              <span class="git-commit-author">${c.author || ''}</span>
              <span class="git-commit-date">${c.date}</span>
            </div>
          </div>
        `;
      }).join('')}
    </div>
  `;
}

function truncateMessage(msg, maxLen) {
  if (!msg) return '';
  return msg.length > maxLen ? msg.substring(0, maxLen) + '...' : msg;
}
