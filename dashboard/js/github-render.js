// GitHub Render Module
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

