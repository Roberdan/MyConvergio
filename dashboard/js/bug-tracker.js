// Bug Tracker System - Fixed Version
// Allows collecting bugs/issues during debugging and converting them to executable plans

let bugTrackerItems = [];
let bugTrackerVisible = false;

// Initialize bug tracker
function initBugTracker() {
  if (!currentProjectId) return;

  const saved = localStorage.getItem(`bugTracker_${currentProjectId}`);
  if (saved) {
    try {
      bugTrackerItems = JSON.parse(saved);
    } catch (e) {
      console.warn('Failed to parse bug tracker:', e);
      bugTrackerItems = [];
    }
  } else {
    bugTrackerItems = [];
  }

  updateBugCount();
}

// Toggle bug tracker modal
function toggleBugTracker() {
  console.log('Bug tracker toggle called, visible:', bugTrackerVisible);
  if (bugTrackerVisible) {
    hideBugTracker();
  } else {
    showBugTracker();
  }
}

// Show bug tracker modal
function showBugTracker() {
  console.log('showBugTracker called');
  if (bugTrackerVisible) {
    console.log('Modal already visible');
    return;
  }

  const modal = document.getElementById('bugTrackerModal');
  if (!modal) {
    console.error('Bug tracker modal not found in DOM');
    return;
  }

  // Add click outside to close (if not already added)
  if (!modal._clickHandlerAdded) {
    modal.addEventListener('click', function(e) {
      if (e.target === modal) {
        hideBugTracker();
      }
    });
    modal._clickHandlerAdded = true;
  }

  renderBugTracker();
  modal.style.display = 'flex';
  modal.style.opacity = '1';
  bugTrackerVisible = true;
  console.log('Bug tracker modal opened');

  // Focus input after animation
  setTimeout(() => {
    const input = document.getElementById('bugInput');
    if (input) input.focus();
  }, 100);
}

// Hide bug tracker modal
function hideBugTracker() {
  const modal = document.getElementById('bugTrackerModal');
  if (modal) {
    modal.style.opacity = '0';
    setTimeout(() => {
      modal.style.display = 'none';
    }, 300);
  }
  bugTrackerVisible = false;
  console.log('Bug tracker modal closed');
}

// Handle Enter key in bug input
function handleBugInputKeypress(event) {
  if (event.key === 'Enter') {
    addBug();
  }
}

// Add a new bug
function addBug() {
  const input = document.getElementById('bugInput');
  const priority = document.getElementById('bugPriority');

  if (!input || !priority) return;

  const text = input.value.trim();
  if (!text) return;

  const bug = {
    id: Date.now().toString(),
    text: text,
    priority: priority.value,
    completed: false,
    createdAt: new Date().toISOString(),
    projectId: currentProjectId
  };

  bugTrackerItems.push(bug);
  saveBugTracker();
  renderBugTracker();

  // Clear input
  input.value = '';
  input.focus();

  updateBugCount();
}

// Toggle bug completion
function toggleBug(bugId) {
  const bug = bugTrackerItems.find(b => b.id === bugId);
  if (bug) {
    bug.completed = !bug.completed;
    saveBugTracker();
    renderBugTracker();
    updateBugCount();
  }
}

// Delete bug
function deleteBug(bugId) {
  bugTrackerItems = bugTrackerItems.filter(b => b.id !== bugId);
  saveBugTracker();
  renderBugTracker();
  updateBugCount();
}

// Clear all bugs
function clearAllBugs() {
  if (confirm('Are you sure you want to clear all tracked bugs?')) {
    bugTrackerItems = [];
    saveBugTracker();
    renderBugTracker();
    updateBugCount();
  }
}

// Create execution plan from bugs
async function createPlanFromBugs() {
  const activeBugs = bugTrackerItems.filter(b => !b.completed);
  if (activeBugs.length === 0) {
    alert('No active bugs to create a plan from!');
    return;
  }

  const planName = prompt('Enter plan name:', `BugFix-${new Date().toISOString().split('T')[0]}`);
  if (!planName) return;

  try {
    // Create plan structure
    const planData = {
      name: planName,
      project_id: currentProjectId,
      status: 'todo',
      tasks_total: activeBugs.length,
      tasks_done: 0,
      markdown_dir: null,
      is_master: 0,
      parent_plan_id: null
    };

    // Create waves from bug priorities
    const waves = [];
    const priorityGroups = {
      high: activeBugs.filter(b => b.priority === 'high'),
      medium: activeBugs.filter(b => b.priority === 'medium'),
      low: activeBugs.filter(b => b.priority === 'low')
    };

    let wavePosition = 1;
    for (const [priority, bugs] of Object.entries(priorityGroups)) {
      if (bugs.length > 0) {
        const waveId = `BUG-${priority.toUpperCase()}`;
        waves.push({
          wave_id: waveId,
          name: `${priority.charAt(0).toUpperCase() + priority.slice(1)} Priority Bug Fixes`,
          status: 'pending',
          assignee: null,
          tasks_done: 0,
          tasks_total: bugs.length,
          position: wavePosition++,
          depends_on: null,
          estimated_hours: bugs.length * 2,
          planned_start: null,
          planned_end: null
        });

        // Add tasks to wave
        bugs.forEach((bug, index) => {
          waves[waves.length - 1].tasks = waves[waves.length - 1].tasks || [];
          waves[waves.length - 1].tasks.push({
            task_id: `${waveId}.${index + 1}`,
            title: bug.text,
            status: 'pending',
            assignee: null,
            priority: bug.priority.toUpperCase(),
            type: 'bug',
            started_at: null,
            completed_at: null,
            duration_minutes: null,
            tokens: 0,
            validated_at: null,
            validated_by: null,
            files: []
          });
        });
      }
    }

    // Create the plan via API
    const createResponse = await fetch('/api/plans', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...planData,
        waves: waves
      })
    });

    if (!createResponse.ok) {
      throw new Error('Failed to create plan');
    }

    const result = await createResponse.json();

    // Mark bugs as completed (they're now in a plan)
    bugTrackerItems.forEach(bug => {
      if (!bug.completed) {
        bug.completed = true;
        bug.planId = result.id;
      }
    });
    saveBugTracker();

    // Refresh the dashboard
    if (typeof loadProjects === 'function') {
      await loadProjects();
    }

    // Show success message
    alert(`✅ Plan "${planName}" created successfully!\n\n${activeBugs.length} bugs converted to executable tasks.`);

    renderBugTracker();
    updateBugCount();

  } catch (error) {
    console.error('Failed to create plan:', error);
    alert('Failed to create plan: ' + error.message);
  }
}

// Render bug tracker
function renderBugTracker() {
  const itemsContainer = document.getElementById('bugItems');
  const countElement = document.getElementById('bugListCount');
  const createBtn = document.getElementById('createPlanBtn');

  if (!itemsContainer) return;

  // Update count
  const activeCount = bugTrackerItems.filter(b => !b.completed).length;
  if (countElement) {
    countElement.textContent = `${bugTrackerItems.length} items (${activeCount} active)`;
  }

  // Enable/disable create plan button
  if (createBtn) {
    createBtn.disabled = activeCount === 0;
  }

  // Render items
  if (bugTrackerItems.length === 0) {
    itemsContainer.innerHTML = `
      <div style="text-align: center; padding: 40px; color: var(--text-muted);">
        <div style="font-size: 48px; margin-bottom: 16px;">🐛</div>
        <div>No bugs tracked yet</div>
        <div style="font-size: 14px; margin-top: 8px;">Add bugs above to start tracking issues</div>
      </div>
    `;
  } else {
    itemsContainer.innerHTML = bugTrackerItems.map(bug => `
      <div class="bug-item ${bug.completed ? 'completed' : ''}">
        <input type="checkbox"
               class="bug-checkbox"
               ${bug.completed ? 'checked' : ''}
               onclick="toggleBug('${bug.id}')">
        <span class="bug-text ${bug.completed ? 'completed' : ''}">${bug.text}</span>
        <span class="bug-priority ${bug.priority}">${bug.priority}</span>
        <button onclick="deleteBug('${bug.id}')" class="bug-delete-btn" title="Delete">×</button>
      </div>
    `).join('');
  }
}

// Save bug tracker to localStorage
function saveBugTracker() {
  if (!currentProjectId) return;
  localStorage.setItem(`bugTracker_${currentProjectId}`, JSON.stringify(bugTrackerItems));
}

// Update bug count in header button
function updateBugCount() {
  const countElement = document.getElementById('bugCount');
  if (countElement) {
    const activeCount = bugTrackerItems.filter(b => !b.completed).length;
    countElement.textContent = activeCount;
    countElement.style.display = activeCount > 0 ? 'inline' : 'none';
  }
}

// Export functions
window.initBugTracker = initBugTracker;
window.toggleBugTracker = toggleBugTracker;
window.showBugTracker = showBugTracker;
window.hideBugTracker = hideBugTracker;
window.addBug = addBug;
window.toggleBug = toggleBug;
window.deleteBug = deleteBug;
window.clearAllBugs = clearAllBugs;
window.createPlanFromBugs = createPlanFromBugs;
window.handleBugInputKeypress = handleBugInputKeypress;