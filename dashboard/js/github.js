// GitHub and External Data Loading

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

    renderGitPanel();
  } catch (e) {
    console.error('Failed to load git data:', e);
  }
}

function renderGitHubPanel() {
  if (!data.github) return;
  renderIssuesPanel();
  updateHealthStatus();
  updateNavCounts();
}

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

    if (data.metrics?.throughput?.done > 0 && data.tokens.total > 0) {
      data.tokens.avgPerTask = Math.round(data.tokens.total / data.metrics.throughput.done);
    }

    document.getElementById('tokensUsed').textContent = data.tokens.total ? data.tokens.total.toLocaleString() : 'n/d';
    document.getElementById('avgTokensPerTask').textContent = data.tokens.avgPerTask ? data.tokens.avgPerTask.toLocaleString() : 'n/d';

    renderTokensTab();
  } catch (e) {
    console.log('Token data not available:', e.message);
    data.tokens = null;
  }
}

function renderGitTab() {
  if (!data.git) {
    document.getElementById('gitBranch').textContent = 'No git data';
    return;
  }

  document.getElementById('gitBranch').textContent = data.git.currentBranch || '-';

  const uncommitted = data.git.uncommitted || {};
  const stagedCount = uncommitted.staged?.length || 0;
  const unstagedCount = uncommitted.unstaged?.length || 0;
  const untrackedCount = uncommitted.untracked?.length || 0;
  const totalUncommitted = stagedCount + unstagedCount + untrackedCount;

  document.getElementById('gitUncommitted').textContent = totalUncommitted;
  document.getElementById('gitAhead').textContent = '-';
  document.getElementById('gitBehind').textContent = '-';

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

function updateHealthStatus() {
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

  const gitHealth = document.getElementById('healthGit');
  if (gitHealth) {
    gitHealth.className = 'health-item';
    if (data.git) {
      const uncommitted = data.git.totalChanges || 0;
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
    } else {
      gitHealth.querySelector('.health-value').textContent = 'Loading...';
    }
  }

  const issuesHealth = document.getElementById('healthIssues');
  if (issuesHealth) {
    issuesHealth.className = 'health-item';
    if (data.github) {
      const openIssues = data.github.issues?.length || 0;
      if (openIssues > 10) {
        issuesHealth.classList.add('red');
      } else if (openIssues > 5) {
        issuesHealth.classList.add('yellow');
      } else {
        issuesHealth.classList.add('green');
      }
      issuesHealth.querySelector('.health-value').textContent = openIssues + ' open';
    } else {
      issuesHealth.querySelector('.health-value').textContent = 'No GitHub';
    }
  }

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
