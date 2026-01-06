// Git Actions - Basic Module
// Pull, Push, Fetch operations
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

