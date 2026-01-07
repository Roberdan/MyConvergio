// Git Actions - Staging Module
// Stage, unstage, discard, commit operations
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
  if (!currentProjectId) {
    showToast('No project selected', 'warning');
    return;
  }
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

// Export functions
window.stageFile = stageFile;
window.unstageFile = unstageFile;
window.stageAll = stageAll;
window.unstageAll = unstageAll;
window.commitChanges = commitChanges;

