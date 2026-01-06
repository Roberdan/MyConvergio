// Bug Tracker - Dropdown Version
// Collect bugs/issues and convert to execution plans

let bugTrackerItems = [];
let bugTrackerVisible = false;

function initBugTracker() {
  if (!currentProjectId) return;
  const saved = localStorage.getItem(`bugTracker_${currentProjectId}`);
  if (saved) {
    try {
      bugTrackerItems = JSON.parse(saved);
    } catch (e) {
      Logger.warn('Failed to parse bug tracker:', e);
      bugTrackerItems = [];
    }
  }
  updateBugCount();
}

function toggleBugTracker() {
  const dropdown = document.getElementById('bugDropdown');
  if (!dropdown) return;

  bugTrackerVisible = !bugTrackerVisible;
  dropdown.style.display = bugTrackerVisible ? 'block' : 'none';

  if (bugTrackerVisible) {
    DropdownManager.closeAll('bugDropdown');
    renderBugTracker();
    setTimeout(() => {
      const input = document.getElementById('bugInput');
      if (input) input.focus();
    }, 50);
  }
}

function hideBugTracker() {
  bugTrackerVisible = false;
  const dropdown = document.getElementById('bugDropdown');
  if (dropdown) dropdown.style.display = 'none';
}

function addBug() {
  const input = document.getElementById('bugInput');
  const priority = document.getElementById('bugPriority');
  if (!input || !priority) return;

  const text = input.value.trim();
  if (!text) return;

  const bug = {
    id: `bug-${Date.now()}`,
    title: text,
    priority: priority.value,
    createdAt: new Date().toISOString(),
    completed: false
  };

  bugTrackerItems.push(bug);
  saveBugs();
  renderBugTracker();
  updateBugCount();
  input.value = '';
  input.focus();
}

function handleBugInputKeypress(event) {
  if (event.key === 'Enter') {
    event.preventDefault();
    addBug();
  }
}

function toggleBug(bugId) {
  const bug = bugTrackerItems.find(b => b.id === bugId);
  if (bug) {
    bug.completed = !bug.completed;
    saveBugs();
    renderBugTracker();
    updateBugCount();
  }
}

function deleteBug(bugId) {
  bugTrackerItems = bugTrackerItems.filter(b => b.id !== bugId);
  saveBugs();
  renderBugTracker();
  updateBugCount();
}

function clearAllBugs() {
  if (confirm('Clear all tracked bugs?')) {
    bugTrackerItems = [];
    saveBugs();
    renderBugTracker();
    updateBugCount();
  }
}

function saveBugs() {
  if (currentProjectId) {
    localStorage.setItem(`bugTracker_${currentProjectId}`, JSON.stringify(bugTrackerItems));
  }
}

function renderBugTracker() {
  const container = document.getElementById('bugItems');
  if (!container) return;

  if (bugTrackerItems.length === 0) {
    container.innerHTML = '<div class="bug-dropdown-empty">No bugs tracked</div>';
    const createBtn = document.getElementById('createPlanBtn');
    if (createBtn) createBtn.disabled = true;
    return;
  }

  container.innerHTML = bugTrackerItems.map(bug => `
    <div class="bug-item ${bug.completed ? 'completed' : ''}" onclick="toggleBug('${bug.id}')">
      <div class="bug-item-check">${bug.completed ? '✅' : '○'}</div>
      <div class="bug-item-content">
        <div class="bug-item-title">${escapeHtml(bug.title)}</div>
        <div class="bug-item-meta">${bug.priority} • ${formatDate(bug.createdAt)}</div>
      </div>
      <div class="bug-item-delete" onclick="event.stopPropagation(); deleteBug('${bug.id}')">×</div>
    </div>
  `).join('');

  const createBtn = document.getElementById('createPlanBtn');
  if (createBtn) {
    const activeCount = bugTrackerItems.filter(b => !b.completed).length;
    createBtn.disabled = activeCount === 0;
    createBtn.textContent = `Create Plan (${activeCount})`;
  }
}

function updateBugCount() {
  const countEl = document.getElementById('bugCount');
  if (countEl) {
    countEl.textContent = bugTrackerItems.length;
  }
}

async function createPlanFromBugs() {
  const activeBugs = bugTrackerItems.filter(b => !b.completed);
  if (activeBugs.length === 0) {
    showToast('No active bugs to create a plan from!', 'warning');
    return;
  }

  const planName = prompt('Enter plan name:', `BugFix-${new Date().toISOString().split('T')[0]}`);
  if (!planName) return;

  showToast(`Creating plan "${planName}"...`, 'info');

  try {
    const planData = {
      name: planName,
      project_id: currentProjectId,
      status: 'todo',
      tasks_total: activeBugs.length,
      tasks_done: 0
    };

    const res = await fetch('/api/plan', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(planData)
    });

    if (res.ok) {
      showToast(`Plan "${planName}" created!`, 'success');
      bugTrackerItems = [];
      saveBugs();
      renderBugTracker();
      updateBugCount();
    } else {
      showToast('Failed to create plan', 'error');
    }
  } catch (error) {
    Logger.error('Failed to create plan:', error);
    showToast('Failed to create plan: ' + error.message, 'error');
  }
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function formatDate(dateStr) {
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

window.initBugTracker = initBugTracker;
window.toggleBugTracker = toggleBugTracker;
window.hideBugTracker = hideBugTracker;
window.addBug = addBug;
window.handleBugInputKeypress = handleBugInputKeypress;
window.deleteBug = deleteBug;
window.clearAllBugs = clearAllBugs;
window.createPlanFromBugs = createPlanFromBugs;
