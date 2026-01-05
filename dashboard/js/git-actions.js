// Git Actions (Pull, Push, Stage, Commit)

async function gitPull() {
  if (!currentProjectId) return;
  showToast('Pulling...', 'info');
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/pull`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
    const result = await res.json();
    if (result.success) {
      await loadGitData();
      showToast(result.output || 'Pull completed', 'success');
    } else {
      showToast(result.error || 'Pull failed', 'error');
    }
  } catch (e) {
    showToast('Pull failed: ' + e.message, 'error');
  }
}

async function gitPush() {
  if (!currentProjectId) return;
  showToast('Pushing...', 'info');
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/push`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    });
    const result = await res.json();
    if (result.success) {
      await loadGitData();
      showToast(result.output || 'Push completed', 'success');
    } else if (result.error?.includes('upstream')) {
      const res2 = await fetch(`${API_BASE}/project/${currentProjectId}/git/push`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ setUpstream: true })
      });
      const result2 = await res2.json();
      if (result2.success) {
        await loadGitData();
        showToast('Pushed with upstream set', 'success');
      } else {
        showToast(result2.error || 'Push failed', 'error');
      }
    } else {
      showToast(result.error || 'Push failed', 'error');
    }
  } catch (e) {
    showToast('Push failed: ' + e.message, 'error');
  }
}

async function gitFetch() {
  if (!currentProjectId) {
    showToast('No project selected', 'warning');
    return;
  }
  showToast('Fetching...', 'info');
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/fetch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
    const result = await res.json();
    if (result.success) {
      await loadGitData();
      showToast('Fetch completed', 'success');
    } else {
      showToast(result.error || 'Fetch failed', 'error');
    }
  } catch (e) {
    showToast('Fetch failed: ' + (e?.message || 'Unknown error'), 'error');
  }
}

async function stageFile(filePath) {
  if (!currentProjectId) return;
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/stage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ files: [filePath] })
    });
    const result = await res.json();
    if (result.success) {
      await loadGitData();
      renderGitPanel();
      showToast(`Staged: ${filePath.split('/').pop()}`, 'success');
    } else {
      showToast(result.error || 'Failed to stage file', 'error');
    }
  } catch (e) {
    showToast('Failed to stage file: ' + e.message, 'error');
  }
}

async function unstageFile(filePath) {
  if (!currentProjectId) return;
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/unstage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ files: [filePath] })
    });
    const result = await res.json();
    if (result.success) {
      await loadGitData();
      renderGitPanel();
      showToast(`Unstaged: ${filePath.split('/').pop()}`, 'success');
    } else {
      showToast(result.error || 'Failed to unstage file', 'error');
    }
  } catch (e) {
    showToast('Failed to unstage file: ' + e.message, 'error');
  }
}

async function discardFile(filePath) {
  if (!currentProjectId) return;
  if (!confirm(`Discard changes to ${filePath.split('/').pop()}?`)) return;
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/discard`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ files: [filePath] })
    });
    const result = await res.json();
    if (result.success) {
      await loadGitData();
      renderGitPanel();
      showToast(`Discarded: ${filePath.split('/').pop()}`, 'success');
    } else {
      showToast(result.error || 'Failed to discard file', 'error');
    }
  } catch (e) {
    showToast('Failed to discard file: ' + e.message, 'error');
  }
}

async function stageAll() {
  if (!currentProjectId) return;
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/stage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ all: true })
    });
    const result = await res.json();
    if (result.success) {
      await loadGitData();
      renderGitPanel();
      showToast('All changes staged', 'success');
    } else {
      showToast(result.error || 'Failed to stage all', 'error');
    }
  } catch (e) {
    showToast('Failed to stage all: ' + e.message, 'error');
  }
}

async function unstageAll() {
  if (!currentProjectId) return;
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/unstage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ all: true })
    });
    const result = await res.json();
    if (result.success) {
      await loadGitData();
      renderGitPanel();
      showToast('All changes unstaged', 'success');
    } else {
      showToast(result.error || 'Failed to unstage all', 'error');
    }
  } catch (e) {
    showToast('Failed to unstage all: ' + e.message, 'error');
  }
}

async function commitChanges(andPush = false) {
  if (!currentProjectId) return;

  const messageEl = document.getElementById('gitCommitMessage');
  const message = messageEl?.value?.trim();

  if (!message) {
    showToast('Please enter a commit message', 'warning');
    messageEl?.focus();
    return;
  }

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/commit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message, push: andPush })
    });
    const result = await res.json();

    if (result.success) {
      messageEl.value = '';
      await loadGitData();
      renderGitPanel();
      showToast(andPush ? 'Committed and pushed!' : 'Committed!', 'success');
    } else {
      showToast(result.error || 'Commit failed', 'error');
    }
  } catch (e) {
    showToast('Commit failed: ' + e.message, 'error');
  }
}

// Branch Management
async function showBranchMenu() {
  if (!currentProjectId) {
    showToast('No project selected', 'warning');
    return;
  }

  const branchList = document.getElementById('gitBranchList');
  if (!branchList) return;

  // Toggle visibility
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
