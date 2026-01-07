// GitHub Health & Status Module
function renderGitTab() {
  // Deprecated - git panel uses git-panel.js instead
  // Kept with null checks for backwards compatibility
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

