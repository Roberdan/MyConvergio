// GitHub and External Data Loading

async function loadGitHubData() {
  const projectId = currentProjectId;
  if (!projectId) return;

  try {
    const res = await fetch(`${API_BASE}/project/${projectId}/github`);
    const github = await res.json();

    // Check if project changed during fetch
    if (projectId !== currentProjectId) return;

    if (github.error) {
      console.log('GitHub data not available:', github.error);
      data.github = null;
      updateHealthStatus();
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
    if (projectId === currentProjectId) {
      data.github = null;
      updateHealthStatus();
    }
  }
}

async function loadGitData() {
  if (!currentProjectId) return;

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git`);
    const git = await res.json();

    if (git.error) {
      console.log('Git data not available:', git.error);
      data.git = { error: git.error, currentBranch: null, uncommitted: null, commits: [], totalChanges: 0 };
      updateHealthStatus();
      return;
    }

    data.git = {
      currentBranch: git.branch,
      uncommitted: git.uncommitted,
      commits: git.commits,
      totalChanges: git.totalChanges
    };

    renderGitPanel();
    updateHealthStatus();
  } catch (e) {
    console.error('Failed to load git data:', e);
    data.git = { error: e.message, currentBranch: null, uncommitted: null, commits: [], totalChanges: 0 };
    updateHealthStatus();
  }
}

function renderGitHubPanel() {
  if (!data.github) return;
  renderIssuesPanel();
  renderPRsPanel();
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

function renderPRsPanel() {
  const prSection = document.getElementById('prSection');
  const prList = document.getElementById('prList');
  const prCount = document.getElementById('prCount');

  if (!prSection || !prList || !prCount) return;

  prSection.style.display = 'block';

  if (!data.github?.prs || data.github.prs.length === 0) {
    prCount.textContent = '0';
    prList.innerHTML = '<div class="pr-empty">No open pull requests</div>';
    return;
  }

  const prs = data.github.prs;
  prCount.textContent = prs.length;

  prList.innerHTML = prs.map(pr => {
    const number = pr.number;
    const title = pr.title || 'Untitled PR';
    const additions = pr.additions || 0;
    const deletions = pr.deletions || 0;
    const filesChanged = pr.files?.length || 0;
    const url = `https://github.com/${data.github.repo}/pull/${number}`;
    const branch = pr.headRefName || 'unknown';
    const isDraft = pr.isDraft || false;
    const mergeable = pr.mergeable;
    const reviewDecision = pr.reviewDecision;

    // Determine merge status
    let mergeStatus = 'unknown';
    let mergeStatusClass = 'gray';
    if (isDraft) {
      mergeStatus = 'Draft';
      mergeStatusClass = 'gray';
    } else if (mergeable === 'MERGEABLE') {
      mergeStatus = 'Ready';
      mergeStatusClass = 'green';
    } else if (mergeable === 'CONFLICTING') {
      mergeStatus = 'Conflicts';
      mergeStatusClass = 'red';
    } else {
      mergeStatus = 'Pending';
      mergeStatusClass = 'yellow';
    }

    // Review status
    let reviewStatus = '';
    let reviewStatusClass = '';
    if (reviewDecision === 'APPROVED') {
      reviewStatus = 'Approved';
      reviewStatusClass = 'green';
    } else if (reviewDecision === 'CHANGES_REQUESTED') {
      reviewStatus = 'Changes Requested';
      reviewStatusClass = 'red';
    } else if (reviewDecision === 'REVIEW_REQUIRED') {
      reviewStatus = 'Review Required';
      reviewStatusClass = 'yellow';
    }

    // Comments status
    const totalComments = pr.totalCommentsCount || 0;
    const unresolvedComments = pr.comments?.filter(c => !c.isResolved).length || 0;

    return `
      <div class="pr-item" onclick="window.open('${url}', '_blank')">
        <div class="pr-item-header">
          <span class="pr-number">#${number}</span>
          <span class="pr-branch">${branch}</span>
          ${isDraft ? '<span class="pr-draft-badge">DRAFT</span>' : ''}
        </div>
        <div class="pr-title">${title}</div>
        <div class="pr-stats">
          <div class="pr-stat">
            <span class="pr-stat-label">Files</span>
            <span class="pr-stat-value">${filesChanged}</span>
          </div>
          <div class="pr-stat">
            <span class="pr-stat-label">+${additions}</span>
            <span class="pr-stat-value green">-${deletions}</span>
          </div>
        </div>
        <div class="pr-status-row">
          <span class="pr-status-badge ${mergeStatusClass}">${mergeStatus}</span>
          ${reviewStatus ? `<span class="pr-status-badge ${reviewStatusClass}">${reviewStatus}</span>` : ''}
          ${unresolvedComments > 0 ? `<span class="pr-comments-badge red">${unresolvedComments} unresolved</span>` : ''}
          ${totalComments > 0 && unresolvedComments === 0 ? `<span class="pr-comments-badge green">All resolved</span>` : ''}
        </div>
      </div>
    `;
  }).join('');
}

async function loadTokenData() {
  if (!currentProjectId) return;

  try {
    // Use plan-specific endpoint if plan is loaded, otherwise use project-wide
    const planId = data?.meta?.plan_id;
    const endpoint = planId
      ? `${API_BASE}/plan/${planId}/tokens`
      : `${API_BASE}/project/${currentProjectId}/tokens`;

    const res = await fetch(endpoint);
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
  // This function is deprecated - git panel uses git-panel.js instead
  // But we keep it with null checks for backwards compatibility
  const gitBranchEl = document.getElementById('gitCurrentBranchName');

  if (!data.git) {
    if (gitBranchEl) gitBranchEl.textContent = 'No git data';
    return;
  }

  if (gitBranchEl) gitBranchEl.textContent = data.git.currentBranch || '-';

  const uncommitted = data.git.uncommitted || {};
  const stagedCount = uncommitted.staged?.length || 0;
  const unstagedCount = uncommitted.unstaged?.length || 0;
  const untrackedCount = uncommitted.untracked?.length || 0;
  const totalUncommitted = stagedCount + unstagedCount + untrackedCount;

  // These elements may not exist in the new UI
  const gitUncommittedEl = document.getElementById('gitUncommitted');
  const gitAheadEl = document.getElementById('gitAhead');
  const gitBehindEl = document.getElementById('gitBehind');
  if (gitUncommittedEl) gitUncommittedEl.textContent = totalUncommitted;
  if (gitAheadEl) gitAheadEl.textContent = '-';
  if (gitBehindEl) gitBehindEl.textContent = '-';

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
      if (data.git.error) {
        gitHealth.classList.add('yellow');
        gitHealth.querySelector('.health-value').textContent = 'No remote';
      } else {
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
