// Git Actions - Branch Module
// Branch management operations
async function showBranchMenu() {
  if (!currentProjectId) {
    showToast('No project selected', 'warning');
    return;
  }
  const branchList = document.getElementById('gitBranchList');
  if (!branchList) return;
  if (branchList.classList.contains('visible')) {
    branchList.classList.remove('visible');
    return;
  }
  branchList.innerHTML = '<div class="branch-loading">Loading...</div>';
  branchList.classList.add('visible');
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/branches`);
    const data = await res.json();
    if (data.error) {
      branchList.innerHTML = `<div class="branch-error">${data.error}</div>`;
      return;
    }
    const current = data.current;
    const branches = data.branches || [];
    branchList.innerHTML = `
      <div class="branch-menu-header">
        <span>Switch Branch</span>
        <button class="branch-close" onclick="hideBranchMenu()">&#x2715;</button>
      </div>
      <div class="branch-search">
        <input type="text" placeholder="Search branches..." oninput="filterBranches(this.value)">
      </div>
      <div class="branch-items" id="branchItems">
        ${branches.map(b => `
          <div class="branch-item ${b.name === current ? 'current' : ''}" onclick="checkoutBranch('${b.name}')">
            <span class="branch-check">${b.name === current ? '&#x2713;' : ''}</span>
            <span class="branch-name">${b.name}</span>
            ${b.remote ? '<span class="branch-remote">remote</span>' : ''}
          </div>
        `).join('')}
      </div>
      <div class="branch-menu-footer">
        <button class="branch-create-btn" onclick="promptNewBranch()">+ Create new branch</button>
      </div>
    `;
  } catch (e) {
    branchList.innerHTML = `<div class="branch-error">Failed to load branches</div>`;
  }
}
function hideBranchMenu() {
  const branchList = document.getElementById('gitBranchList');
  if (branchList) branchList.classList.remove('visible');
}
function filterBranches(query) {
  const items = document.querySelectorAll('#branchItems .branch-item');
  const q = query.toLowerCase();
  items.forEach(item => {
    const name = item.querySelector('.branch-name').textContent.toLowerCase();
    item.style.display = name.includes(q) ? '' : 'none';
  });
}
async function checkoutBranch(branch) {
  if (!currentProjectId) return;
  if (branch === data.git?.currentBranch) {
    hideBranchMenu();
    return;
  }
  showToast(`Switching to ${branch}...`, 'info');
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ branch })
    });
    const result = await res.json();
    if (result.success) {
      hideBranchMenu();
      await loadGitData();
      showToast(`Switched to ${branch}`, 'success');
    } else {
      showToast(result.error || 'Checkout failed', 'error');
    }
  } catch (e) {
    showToast('Checkout failed: ' + e.message, 'error');
  }
}
function promptNewBranch() {
  const name = prompt('New branch name:');
  if (name && name.trim()) {
    createNewBranch(name.trim());
  }
}
async function createNewBranch(name) {
  if (!currentProjectId) return;
  showToast(`Creating branch ${name}...`, 'info');
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/branch/create`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name })
    });
    const result = await res.json();
    if (result.success) {
      hideBranchMenu();
      await loadGitData();
      showToast(`Created and switched to ${name}`, 'success');
    } else {
      showToast(result.error || 'Failed to create branch', 'error');
    }
  } catch (e) {
    showToast('Failed to create branch: ' + e.message, 'error');
  }
}

