// GitHub Data Loading Module
async function loadGitHubData() {
  const projectId = currentProjectId;
  if (!projectId) return;
  try {
    const res = await fetch(`${API_BASE}/project/${projectId}/github`);
    const github = await res.json();
    // Check if project changed during fetch
    if (projectId !== currentProjectId) return;
    if (github.error) {
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
async function loadTokenData() {
  if (!currentProjectId) return;
  try {
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
    data.tokens = null;
  }
}

