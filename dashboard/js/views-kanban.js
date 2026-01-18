// Kanban Rendering with Drag & Drop

// Drag state
let draggedPlanId = null;
let draggedFromStatus = null;
let kanbanDragInitialized = false;
let trashedPlans = []; // Local trash storage

function initKanbanDragDrop() {
  // Prevent duplicate listeners
  if (kanbanDragInitialized) return;

  ['todo', 'doing', 'done', 'trash'].forEach(status => {
    const container = document.getElementById(`kanban${status.charAt(0).toUpperCase() + status.slice(1)}`);
    const column = document.querySelector(`.cc-kanban-column[data-status="${status}"]`);

    if (!container) {
      console.warn('Kanban container not found:', status);
      return;
    }

    // Handle drop on both container and entire column
    const handleDrop = async (e) => {
      e.preventDefault();
      e.stopPropagation();
      container.classList.remove('drag-over');

      if (!draggedPlanId || draggedFromStatus === status) {
        draggedPlanId = null;
        draggedFromStatus = null;
        return;
      }

      // Handle trash drop
      if (status === 'trash') {
        await movePlanToTrash(draggedPlanId, draggedFromStatus);
        draggedPlanId = null;
        draggedFromStatus = null;
        // Don't reload - we're using local state for trash
        return;
      }

      // Handle restore from trash
      if (draggedFromStatus === 'trash') {
        await restorePlanFromTrash(draggedPlanId, status);
        draggedPlanId = null;
        draggedFromStatus = null;
        return;
      }

      // Show confirmation modal when moving to done
      if (status === 'done') {
        const planId = draggedPlanId;
        const fromStatus = draggedFromStatus;
        draggedPlanId = null;
        draggedFromStatus = null;
        showMarkDoneConfirmation(planId, fromStatus);
        return;
      }

      try {
        showToast(`Moving plan to ${status}...`, 'info');
        const res = await fetch(`${API_BASE}/plan/${draggedPlanId}/status`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status })
        });
        const result = await res.json();

        if (result.success) {
          showToast(`Plan moved to ${status}`, 'success');
          await loadKanban();
          await loadProjects();
        } else {
          showToast(result.error || 'Failed to move plan', 'error');
        }
      } catch (err) {
        showToast('Failed to move plan: ' + err.message, 'error');
      }

      draggedPlanId = null;
      draggedFromStatus = null;
    };

    // Listeners for cards container
    container.addEventListener('dragenter', (e) => {
      e.preventDefault();
      e.stopPropagation();
      container.classList.add('drag-over');
    });

    container.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.stopPropagation();
      e.dataTransfer.dropEffect = 'move';
      container.classList.add('drag-over');
    });

    container.addEventListener('dragleave', (e) => {
      e.preventDefault();
      if (!container.contains(e.relatedTarget)) {
        container.classList.remove('drag-over');
      }
    });

    container.addEventListener('drop', handleDrop);

    // Also handle drop on entire column (including header)
    if (column) {
      column.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        container.classList.add('drag-over');
      });

      column.addEventListener('dragleave', (e) => {
        if (!column.contains(e.relatedTarget)) {
          container.classList.remove('drag-over');
        }
      });

      column.addEventListener('drop', handleDrop);
    }
  });

  kanbanDragInitialized = true;
}

function handleKanbanDragStart(e, planId, status) {
  draggedPlanId = planId;
  draggedFromStatus = status;
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', planId);
  }
  if (e.target) {
    e.target.classList.add('dragging');
  }
}

function handleKanbanDragEnd(e) {
  if (e.target) {
    e.target.classList.remove('dragging');
  }
  document.querySelectorAll('.cc-column-cards').forEach(c => c.classList.remove('drag-over'));
}

function renderKanban(kanban) {
  // Update status indicator
  const statusDot = document.getElementById('ccStatusDot');
  const statusCount = document.getElementById('ccStatusCount');
  const statusContainer = document.getElementById('systemStatusCompact');
  const activePlans = kanban.doing?.length || 0;

  if (statusDot && statusCount) {
    statusCount.textContent = activePlans;
    if (activePlans > 0) {
      statusDot.style.animation = 'pulse 2s infinite';
      statusDot.classList.add('active');
      statusContainer.title = `${activePlans} mission${activePlans > 1 ? 's' : ''} in flight`;
    } else {
      statusDot.style.animation = 'none';
      statusDot.classList.remove('active');
      statusContainer.title = 'All systems nominal';
    }
  }

  // Update gauges and status
  updateControlCenterGauges(kanban);
  updateSystemStatus(kanban);

  // Render kanban columns
  ['todo', 'doing', 'done'].forEach(status => {
    const container = document.getElementById(`kanban${status.charAt(0).toUpperCase() + status.slice(1)}`);
    const countEl = document.getElementById(`kanban${status.charAt(0).toUpperCase() + status.slice(1)}Count`);

    if (!container) return;

    const plans = kanban[status] || [];
    if (countEl) countEl.textContent = plans.length;

    if (plans.length === 0) {
      container.innerHTML = '<div class="cc-empty">No missions</div>';
      return;
    }

    container.innerHTML = plans.map(plan => {
      const taskInfo = plan.tasksTotal ? `${plan.tasksDone}/${plan.tasksTotal}` : '0/0';
      const statusDotClass = plan.isRunning ? 'running' : '';
      const isClickable = status !== 'trash'; // Allow loading from any column
      const clickHandler = isClickable ? `onclick="activatePlanAndNavigate('${plan.planId}', '${plan.projectId}')"` : '';
      const clickableClass = isClickable ? 'clickable' : '';
      const isComplete = plan.tasksTotal > 0 && plan.tasksDone >= plan.tasksTotal;
      const isValidated = !!plan.validatedAt;
      const isDoneStatus = status === 'done';
      const needsValidation = isComplete && !isValidated;
      const isMismatch = isDoneStatus && (!isComplete || !isValidated);
      const confidenceLabel = isMismatch
        ? 'Inconsistent'
        : (isValidated && isComplete ? 'Verified' : (isComplete ? 'Unverified' : 'In Progress'));
      const confidenceClass = isMismatch
        ? 'inconsistent'
        : (isValidated && isComplete ? 'verified' : (isComplete ? 'unverified' : 'inprogress'));
      const gitLabel = plan.gitError ? 'Git Error' : (plan.gitDirty ? 'Uncommitted' : 'Committed');
      const gitClass = plan.gitError ? 'dirty' : (plan.gitDirty ? 'dirty' : 'clean');
      const statusLabel = isDoneStatus
        ? (isComplete && isValidated ? 'Done ✓' : (!isComplete ? 'Done? Tasks missing' : 'Done? Thor pending'))
        : (needsValidation ? 'Ready for Thor' : `${plan.progress}%`);
      const statusTitle = isMismatch
        ? (isComplete ? 'Plan marked done but missing Thor validation' : 'Plan marked done but tasks are incomplete')
        : (needsValidation ? 'All tasks done; waiting for Thor validation' : '');
      const cardClass = isMismatch ? 'warning' : '';
      const statusClass = isMismatch || needsValidation ? 'warning' : '';

      return `
        <div class="cc-plan-card ${clickableClass} ${cardClass}"
             draggable="true"
             data-plan-id="${plan.planId}"
             data-project-id="${plan.projectId}"
             ondragstart="handleKanbanDragStart(event, '${plan.planId}', '${status}')"
             ondragend="handleKanbanDragEnd(event)"
             ${clickHandler}>
          <div class="cc-plan-project">${plan.project}</div>
          <div class="cc-plan-name"><span class="cc-plan-id">#${plan.planId}</span> ${plan.name}</div>
          <div class="cc-plan-badges">
            <span class="cc-plan-confidence ${confidenceClass}">${confidenceLabel}</span>
            <span class="cc-plan-git ${gitClass}" title="${gitLabel}">${gitLabel}</span>
          </div>
          <div class="cc-plan-progress">
            <div class="cc-plan-progress-fill" style="width: ${plan.progress}%"></div>
          </div>
          <div class="cc-plan-meta">
            <span class="cc-plan-tasks">${taskInfo} tasks</span>
            <span class="cc-plan-status ${statusClass}" ${statusTitle ? `title="${statusTitle}"` : ''}>
              <span class="cc-plan-status-dot ${statusDotClass}"></span>
              ${statusLabel}
            </span>
          </div>
        </div>
      `;
    }).join('');
  });

  // Initialize drag & drop after all columns are rendered
  requestAnimationFrame(initKanbanDragDrop);
}

function updateControlCenterGauges(kanban) {
  const totalPlans = (kanban.todo?.length || 0) + (kanban.doing?.length || 0) + (kanban.done?.length || 0);
  const completedPlans = kanban.done?.length || 0;
  const activePlans = kanban.doing?.length || 0;

  // Completion Rate Gauge
  const completionRate = totalPlans > 0 ? Math.round((completedPlans / totalPlans) * 100) : 0;
  const completionGauge = document.getElementById('gaugeCompletion');
  const completionValue = document.getElementById('gaugeCompletionValue');
  if (completionGauge) {
    const rotation = -90 + (completionRate / 100) * 180;
    completionGauge.style.transform = `rotate(${rotation}deg)`;
  }
  if (completionValue) completionValue.textContent = completionRate + '%';

  // Active Workload Gauge (max 10 for scale)
  const workloadGauge = document.getElementById('gaugeWorkload');
  const workloadValue = document.getElementById('gaugeWorkloadValue');
  const workloadPercent = Math.min(activePlans / 10, 1);
  if (workloadGauge) {
    const rotation = -90 + workloadPercent * 180;
    workloadGauge.style.transform = `rotate(${rotation}deg)`;
  }
  if (workloadValue) workloadValue.textContent = activePlans;

  // Efficiency Score (calculate from completed plans)
  let totalTokens = 0;
  let totalTasks = 0;
  (kanban.done || []).forEach(plan => {
    totalTokens += plan.tokens || 0;
    totalTasks += plan.tasksDone || 0;
  });

  const avgTokensPerTask = totalTasks > 0 ? Math.round(totalTokens / totalTasks) : 0;
  const efficiencyGauge = document.getElementById('gaugeEfficiency');
  const efficiencyValue = document.getElementById('gaugeEfficiencyValue');

  // Scale: < 5000 = excellent, > 50000 = poor
  const efficiencyPercent = avgTokensPerTask > 0 ? Math.max(0, 1 - (avgTokensPerTask - 5000) / 45000) : 0.5;
  if (efficiencyGauge) {
    const rotation = -90 + Math.min(efficiencyPercent, 1) * 180;
    efficiencyGauge.style.transform = `rotate(${rotation}deg)`;
  }
  if (efficiencyValue) {
    efficiencyValue.textContent = avgTokensPerTask > 0 ? (avgTokensPerTask / 1000).toFixed(1) + 'K' : '-';
  }
}

// Status indicator functions
function toggleStatusDropdown() {
  const dropdown = document.getElementById('ccStatusDropdown');
  if (dropdown) {
    dropdown.classList.toggle('show');
  }
}

// Close dropdown when clicking outside
document.addEventListener('click', (e) => {
  const dropdown = document.getElementById('ccStatusDropdown');
  const indicator = e.target.closest('.cc-status-indicator');
  if (dropdown && !indicator) {
    dropdown.classList.remove('show');
  }
});

function updateSystemStatus(kanban) {
  const icon = document.getElementById('ccStatusIcon');
  const activePlans = kanban.doing?.length || 0;
  const blockedTasks = 0; // TODO: get from API if available
  const openIssues = 0; // TODO: get from API if available

  // Update counts in dropdown
  const activeEl = document.querySelector('#statusActivePlans .cc-status-count');
  const blockedEl = document.querySelector('#statusBlockedTasks .cc-status-count');
  const issuesEl = document.querySelector('#statusOpenIssues .cc-status-count');

  if (activeEl) activeEl.textContent = activePlans;
  if (blockedEl) blockedEl.textContent = blockedTasks;
  if (issuesEl) issuesEl.textContent = openIssues;

  // Update dots
  const activeDot = document.querySelector('#statusActivePlans .cc-status-dot');
  const blockedDot = document.querySelector('#statusBlockedTasks .cc-status-dot');
  const issuesDot = document.querySelector('#statusOpenIssues .cc-status-dot');

  if (activeDot) {
    activeDot.className = 'cc-status-dot ' + (activePlans > 0 ? 'green' : 'gray');
  }
  if (blockedDot) {
    blockedDot.className = 'cc-status-dot ' + (blockedTasks > 0 ? 'orange' : 'gray');
  }
  if (issuesDot) {
    issuesDot.className = 'cc-status-dot ' + (openIssues > 5 ? 'red' : openIssues > 0 ? 'orange' : 'gray');
  }

  // Update main icon color
  if (icon) {
    icon.className = 'cc-status-icon';
    if (blockedTasks > 0 || openIssues > 5) {
      icon.classList.add('error');
    } else if (openIssues > 0) {
      icon.classList.add('warning');
    }
    // Default is green (no class added)
  }
}

// Trash Management Functions
async function movePlanToTrash(planId, fromStatus) {
  // Find the plan card element to get its data
  const cards = document.querySelectorAll('.cc-plan-card');
  let planData = null;
  let cardElement = null;
  
  cards.forEach(card => {
    const cardPlanId = card.getAttribute('data-plan-id');
    if (cardPlanId == planId) {
      cardElement = card;
      planData = {
        planId: planId,
        projectId: card.getAttribute('data-project-id'),
        project: card.querySelector('.cc-plan-project')?.textContent || 'Unknown',
        name: card.querySelector('.cc-plan-name')?.textContent || 'Unknown',
        fromStatus: fromStatus
      };
    }
  });

  if (planData) {
    trashedPlans.push(planData);
    showToast(`Plan "${planData.name}" moved to trash`, 'warning');
    
    // Remove card from DOM immediately (don't reload to avoid duplicates)
    if (cardElement) {
      cardElement.remove();
    }
    
    // Update count in original column
    const countEl = document.getElementById(`kanban${fromStatus.charAt(0).toUpperCase() + fromStatus.slice(1)}Count`);
    if (countEl) {
      const currentCount = parseInt(countEl.textContent) || 0;
      countEl.textContent = Math.max(0, currentCount - 1);
    }
    
    renderTrashColumn();
  }
}

async function restorePlanFromTrash(planId, toStatus) {
  const planIndex = trashedPlans.findIndex(p => p.planId == planId);
  if (planIndex === -1) return;

  const plan = trashedPlans[planIndex];
  
  try {
    showToast(`Restoring plan...`, 'info');
    const res = await fetch(`${API_BASE}/plan/${planId}/status`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: toStatus })
    });
    const result = await res.json();

    if (result.success) {
      trashedPlans.splice(planIndex, 1);
      showToast(`Plan "${plan.name}" restored to ${toStatus}`, 'success');
      await loadKanban();
      renderTrashColumn();
    } else {
      showToast(result.error || 'Failed to restore plan', 'error');
    }
  } catch (err) {
    showToast('Failed to restore plan: ' + err.message, 'error');
  }
}

function renderTrashColumn() {
  const container = document.getElementById('kanbanTrash');
  const countEl = document.getElementById('kanbanTrashCount');
  const emptyBtn = document.getElementById('emptyTrashBtn');

  if (!container) return;

  if (countEl) countEl.textContent = trashedPlans.length;
  if (emptyBtn) emptyBtn.style.display = trashedPlans.length > 0 ? 'block' : 'none';

  if (trashedPlans.length === 0) {
    container.innerHTML = '<div class="cc-empty">🗑️ Drag plans here to delete</div>';
    return;
  }

  container.innerHTML = trashedPlans.map(plan => `
    <div class="cc-plan-card"
         draggable="true"
         ondragstart="handleKanbanDragStart(event, ${plan.planId}, 'trash')"
         ondragend="handleKanbanDragEnd(event)">
      <div class="cc-plan-project">${plan.project}</div>
      <div class="cc-plan-name"><span class="cc-plan-id">#${plan.planId}</span> ${plan.name}</div>
      <div class="cc-plan-meta">
        <span class="cc-plan-tasks">Was: ${plan.fromStatus}</span>
        <span class="cc-plan-status">🗑️</span>
      </div>
    </div>
  `).join('');
}

async function emptyTrash() {
  if (trashedPlans.length === 0) {
    showToast('Trash is already empty', 'info');
    return;
  }

  const confirmed = confirm(`Permanently delete ${trashedPlans.length} plan(s)? This cannot be undone.`);
  if (!confirmed) return;

  showToast('Deleting plans...', 'info');

  let deleted = 0;
  let failed = 0;
  const projectsToCheck = new Set();

  for (const plan of trashedPlans) {
    try {
      const res = await fetch(`${API_BASE}/plan/${plan.planId}`, {
        method: 'DELETE'
      });
      const result = await res.json();
      
      if (result.success) {
        deleted++;
        // Track which projects need to be checked for emptiness
        if (plan.projectId) {
          projectsToCheck.add(plan.projectId);
        }
      } else {
        failed++;
        console.error('Failed to delete plan:', plan.planId, result.error);
      }
    } catch (err) {
      failed++;
      console.error('Error deleting plan:', plan.planId, err);
    }
  }

  // Clean up empty projects
  let projectsDeleted = 0;
  for (const projectId of projectsToCheck) {
    try {
      const res = await fetch(`${API_BASE}/project/${projectId}`, {
        method: 'DELETE'
      });
      const result = await res.json();
      
      if (result.success) {
        projectsDeleted++;
        console.log('Deleted empty project:', result.deleted);
      }
    } catch (err) {
      // Project might have other plans or already deleted - ignore errors
      console.log('Could not delete project:', projectId, err.message);
    }
  }

  trashedPlans = [];
  renderTrashColumn();
  await loadKanban();
  await loadProjects();

  let message = `${deleted} plan(s) permanently deleted`;
  if (projectsDeleted > 0) {
    message += `, ${projectsDeleted} empty project(s) removed`;
  }
  if (failed > 0) {
    message += ` (${failed} failed)`;
  }

  showToast(message, failed === 0 ? 'success' : 'warning');
}

// Activate plan and navigate to dashboard
async function activatePlanAndNavigate(planId, projectId) {
  try {
    showToast('Loading plan...', 'info');
    
    // Select the project
    await selectProject(projectId);
    
    // Load the plan details
    await loadPlanDetails(planId);

    // Reload git/github data after loadPlanDetails (it overwrites data object)
    loadGitHubData();
    loadGitData();

    // Enable dashboard link
    const dashboardLink = document.getElementById('dashboardLink');
    if (dashboardLink) {
      dashboardLink.classList.remove('disabled');
    }
    
    // Navigate to dashboard view
    showView('dashboard');
    
    showToast('Plan activated', 'success');
  } catch (err) {
    console.error('Failed to activate plan:', err);
    showToast('Failed to load plan: ' + err.message, 'error');
  }
}

// Mark Done Confirmation Modal
async function showMarkDoneConfirmation(planId, fromStatus) {
  // Fetch plan details for the checklist
  let planData = null;
  try {
    const res = await fetch(`${API_BASE}/plan/${planId}`);
    const result = await res.json();
    if (result.success) planData = result.plan;
  } catch (e) {
    console.error('Failed to fetch plan details:', e);
  }

  const tasksDone = planData?.tasks_done || 0;
  const tasksTotal = planData?.tasks_total || 0;
  const isTasksComplete = tasksTotal > 0 && tasksDone >= tasksTotal;
  const isValidated = !!planData?.validated_at;
  const gitDirty = planData?.git_dirty || false;
  const gitError = planData?.git_error || false;
  const gitClean = !gitDirty && !gitError;

  const warnings = [];
  if (!isTasksComplete) warnings.push('Tasks incomplete');
  if (!isValidated) warnings.push('Thor validation pending');
  if (!gitClean) warnings.push('Git has uncommitted changes');

  const modal = document.createElement('div');
  modal.className = 'mark-done-modal-overlay';
  modal.innerHTML = `
    <div class="mark-done-modal">
      <div class="mark-done-header">
        <h3>Mark Plan as Done?</h3>
        <button class="mark-done-close" onclick="closeMarkDoneModal()">&times;</button>
      </div>
      <div class="mark-done-body">
        <p class="mark-done-plan-name">${planData?.name || 'Plan'}</p>
        <div class="mark-done-checklist">
          <div class="checklist-item ${isTasksComplete ? 'pass' : 'fail'}">
            <span class="checklist-icon">${isTasksComplete ? '✓' : '✗'}</span>
            <span>Tasks: ${tasksDone}/${tasksTotal} completed</span>
          </div>
          <div class="checklist-item ${isValidated ? 'pass' : 'warn'}">
            <span class="checklist-icon">${isValidated ? '✓' : '⚠'}</span>
            <span>Thor Validation: ${isValidated ? 'Passed' : 'Pending'}</span>
          </div>
          <div class="checklist-item ${gitClean ? 'pass' : 'warn'}">
            <span class="checklist-icon">${gitClean ? '✓' : '⚠'}</span>
            <span>Git: ${gitClean ? 'Clean' : (gitError ? 'Error' : 'Dirty')}</span>
          </div>
        </div>
        ${warnings.length > 0 ? `
          <div class="mark-done-warning">
            <strong>Warning:</strong> ${warnings.join(', ')}
          </div>
        ` : ''}
      </div>
      <div class="mark-done-footer">
        <button class="mark-done-btn cancel" onclick="closeMarkDoneModal()">Cancel</button>
        <button class="mark-done-btn confirm ${warnings.length > 0 ? 'warn' : ''}"
                onclick="confirmMarkDone('${planId}')">
          ${warnings.length > 0 ? 'Mark Done Anyway' : 'Confirm Done'}
        </button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) closeMarkDoneModal();
  });
}

function closeMarkDoneModal() {
  const modal = document.querySelector('.mark-done-modal-overlay');
  if (modal) modal.remove();
}

async function confirmMarkDone(planId) {
  closeMarkDoneModal();
  try {
    showToast('Moving plan to done...', 'info');
    const res = await fetch(`${API_BASE}/plan/${planId}/status`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'done' })
    });
    const result = await res.json();
    if (result.success) {
      showToast('Plan marked as done', 'success');
      await loadKanban();
      await loadProjects();
    } else {
      showToast(result.error || 'Failed to mark done', 'error');
    }
  } catch (err) {
    showToast('Failed to mark done: ' + err.message, 'error');
  }
}

// Export trash functions
window.emptyTrash = emptyTrash;
window.renderTrashColumn = renderTrashColumn;
window.activatePlanAndNavigate = activatePlanAndNavigate;
window.showMarkDoneConfirmation = showMarkDoneConfirmation;
window.closeMarkDoneModal = closeMarkDoneModal;
window.confirmMarkDone = confirmMarkDone;
