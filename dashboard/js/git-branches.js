// Git Branch Operations

async function showBranchMenu() {
  if (!currentProjectId) return;

  const branchList = document.getElementById('gitBranchList');
  if (!branchList) return;

  if (branchList.style.display === 'block') {
    branchList.style.display = 'none';
    return;
  }

  branchList.innerHTML = '<div class="git-loading">Loading branches...</div>';
  branchList.style.display = 'block';

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/branches`);
    const result = await res.json();

    if (result.error) {
      branchList.innerHTML = `<div class="git-empty">${result.error}</div>`;
      return;
    }

    const current = result.current;
    const localBranches = result.branches.filter(b => !b.remote && !b.name.includes('HEAD'));
    const remoteBranches = result.branches.filter(b => b.remote && !b.name.includes('HEAD'));

    branchList.innerHTML = `
      <div class="git-branch-section">
        <div class="git-branch-section-header">Local</div>
        ${localBranches.map(b => `
          <div class="git-branch-item ${b.name === current ? 'current' : ''}" onclick="switchBranch('${b.name}')">
            <span class="git-branch-check">${b.name === current ? '&#x2713;' : ''}</span>
            <span class="git-branch-name">${b.name}</span>
          </div>
        `).join('')}
      </div>
      ${remoteBranches.length > 0 ? `
        <div class="git-branch-section">
          <div class="git-branch-section-header">Remote</div>
          ${remoteBranches.slice(0, 10).map(b => {
            const shortName = b.name.replace('remotes/origin/', '');
            return `
              <div class="git-branch-item remote" onclick="switchBranch('${shortName}')">
                <span class="git-branch-check"></span>
                <span class="git-branch-name">${shortName}</span>
              </div>
            `;
          }).join('')}
        </div>
      ` : ''}
      <div class="git-branch-section">
        <div class="git-branch-new" onclick="createNewBranch()">
          <span>+</span> Create new branch
        </div>
      </div>
    `;
  } catch (e) {
    branchList.innerHTML = `<div class="git-empty">Error: ${e.message}</div>`;
  }
}

async function switchBranch(branchName) {
  if (!currentProjectId) return;

  showToast(`Switching to ${branchName}...`, 'info');

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ branch: branchName })
    });
    const result = await res.json();

    if (result.success) {
      document.getElementById('gitBranchList').style.display = 'none';
      await loadGitData();
      showToast(`Switched to ${branchName}`, 'success');
    } else {
      showToast(result.error || 'Failed to switch branch', 'error');
    }
  } catch (e) {
    showToast('Failed to switch branch: ' + e.message, 'error');
  }
}

async function createNewBranch() {
  const name = prompt('Enter new branch name:');
  if (!name || !name.trim()) return;

  const branchName = name.trim().replace(/\s+/g, '-');

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/branch/create`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: branchName })
    });
    const result = await res.json();

    if (result.success) {
      document.getElementById('gitBranchList').style.display = 'none';
      await loadGitData();
      showToast(`Created and switched to ${branchName}`, 'success');
    } else {
      showToast(result.error || 'Failed to create branch', 'error');
    }
  } catch (e) {
    showToast('Failed to create branch: ' + e.message, 'error');
  }
}
