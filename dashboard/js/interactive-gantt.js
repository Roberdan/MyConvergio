// Interactive Gantt View - Heart of Dashboard
// Hierarchical view: Waves -> Tasks with expandable/collapsible navigation

let ganttData = null;
let expandedWaves = new Set();
let showCompletedTasks = true;
let showBlockedTasks = true;

// Initialize the interactive Gantt view
async function initInteractiveGantt() {
  console.log('Initializing interactive Gantt view...');

  // Show loading state
  const ganttElement = document.getElementById('interactiveGantt');
  const contentArea = document.getElementById('ganttContentArea');

  if (!ganttElement || !contentArea) {
    console.error('Gantt elements not found');
    return;
  }

  // Load data
  await loadGanttData();

  // Set up filters
  document.getElementById('showCompletedTasks').checked = showCompletedTasks;
  document.getElementById('showBlockedTasks').checked = showBlockedTasks;
}

// Load complete Gantt data (waves + tasks)
async function loadGanttData() {
  const contentArea = document.getElementById('ganttContentArea');
  if (!contentArea) return;

  contentArea.innerHTML = `
    <div class="gantt-loading-state">
      <div class="gantt-loading-spinner"></div>
      <div class="gantt-loading-text">Loading project timeline...</div>
    </div>
  `;

  try {
    if (!currentProjectId) {
      contentArea.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">📊</div>
          <div class="empty-state-title">No Project Selected</div>
          <div class="empty-state-description">Select a project to view the execution timeline.</div>
        </div>
      `;
      return;
    }

    console.log('Loading Gantt data for project:', currentProjectId);

    // Load project dashboard data (contains waves summary)
    const dashboardRes = await fetch(`/api/project/${currentProjectId}/dashboard`);
    const dashboardData = await dashboardRes.json();

    console.log('Dashboard data loaded:', dashboardData);

    // Load detailed plan data for each wave
    const plansPromises = dashboardData.plans.map(async (planRef) => {
      try {
        const planRes = await fetch(`/api/plan/${planRef.id}`);
        const planData = await planRes.json();
        return {
          ...planRef,
          waves: planData.waves || []
        };
      } catch (e) {
        console.warn(`Failed to load plan ${planRef.id}:`, e);
        return planRef;
      }
    });

    const plansWithWaves = await Promise.all(plansPromises);

    // Build complete gantt data structure
    ganttData = {
      project: dashboardData.meta,
      plans: plansWithWaves,
      allWaves: []
    };

    // Flatten all waves for easier access
    plansWithWaves.forEach(plan => {
      if (plan.waves) {
        plan.waves.forEach(wave => {
          ganttData.allWaves.push({
            ...wave,
            planId: plan.id,
            planName: plan.name
          });
        });
      }
    });

    console.log('Gantt data structure built:', ganttData);

    // Calculate timeline bounds
    calculateTimelineBounds();

    // Render the Gantt
    renderInteractiveGantt();

  } catch (error) {
    console.error('Failed to load Gantt data:', error);
    contentArea.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">❌</div>
        <div class="empty-state-title">Failed to Load Timeline</div>
        <div class="empty-state-description">${error.message}</div>
      </div>
    `;
  }
}

// Calculate timeline bounds for all waves
function calculateTimelineBounds() {
  if (!ganttData || !ganttData.allWaves.length) return;

  let minDate = null;
  let maxDate = null;

  ganttData.allWaves.forEach(wave => {
    // Check planned dates
    if (wave.planned_start) {
      const start = new Date(wave.planned_start);
      if (!minDate || start < minDate) minDate = start;
    }
    if (wave.planned_end) {
      const end = new Date(wave.planned_end);
      if (!maxDate || end > maxDate) maxDate = end;
    }

    // Check actual dates
    if (wave.started_at) {
      const start = new Date(wave.started_at);
      if (!minDate || start < minDate) minDate = start;
    }
    if (wave.completed_at) {
      const end = new Date(wave.completed_at);
      if (!maxDate || end > maxDate) maxDate = end;
    }
  });

  // Set defaults if no dates found
  const now = new Date();
  if (!minDate) minDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000); // 1 week ago
  if (!maxDate) maxDate = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000); // 2 weeks from now

  // Add padding
  const padding = 2 * 24 * 60 * 60 * 1000; // 2 days
  ganttData.timelineStart = new Date(minDate.getTime() - padding);
  ganttData.timelineEnd = new Date(maxDate.getTime() + padding);
  ganttData.timelineDuration = ganttData.timelineEnd - ganttData.timelineStart;

  console.log('Timeline calculated:', {
    start: ganttData.timelineStart,
    end: ganttData.timelineEnd,
    duration: ganttData.timelineDuration
  });
}

// Render the complete interactive Gantt
function renderInteractiveGantt() {
  const contentArea = document.getElementById('ganttContentArea');
  if (!contentArea || !ganttData) return;

  console.log('Rendering interactive Gantt...');

  // Build timeline header labels
  const timelineLabels = buildTimelineLabels();

  // Update timeline header
  const timelineLabelsEl = document.getElementById('ganttTimelineLabels');
  if (timelineLabelsEl) {
    timelineLabelsEl.innerHTML = timelineLabels;
  }

  // Render waves and their tasks
  const wavesHTML = ganttData.allWaves.map(wave => renderWaveRow(wave)).join('');

  contentArea.innerHTML = wavesHTML || `
    <div class="empty-state">
      <div class="empty-state-icon">🌊</div>
      <div class="empty-state-title">No Waves Found</div>
      <div class="empty-state-description">This project doesn't have any waves or tasks defined yet.</div>
    </div>
  `;

  console.log('Interactive Gantt rendered successfully');
}

// Build timeline header labels
function buildTimelineLabels() {
  if (!ganttData || !ganttData.timelineStart) return '';

  const labels = [];
  const totalWidth = 100; // percentage

  for (let i = 0; i <= 7; i++) {
    const date = new Date(ganttData.timelineStart.getTime() + (i * ganttData.timelineDuration / 7));
    const label = date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric'
    });
    labels.push(`<div class="gantt-timeline-label" style="width: ${totalWidth/7}%">${label}</div>`);
  }

  return labels.join('');
}

// Render a single wave row
function renderWaveRow(wave) {
  const isExpanded = expandedWaves.has(wave.wave_id);
  const tasksHTML = isExpanded ? renderWaveTasks(wave) : '';

  return `
    <div class="gantt-wave-row ${isExpanded ? 'expanded' : ''}" data-wave-id="${wave.wave_id}">
      <div class="gantt-wave-info" onclick="toggleWaveExpansion('${wave.wave_id}')">
        <div class="gantt-wave-expand-icon">${isExpanded ? '▼' : '▶'}</div>
        <div class="gantt-wave-details">
          <div class="gantt-wave-id">${wave.wave_id}</div>
          <div class="gantt-wave-name">${wave.name}</div>
          <div class="gantt-wave-meta">
            <span>Plan: ${wave.planName}</span>
            <span>${wave.tasks_total || 0} tasks</span>
            ${wave.assignee ? `<span>👤 ${wave.assignee}</span>` : ''}
          </div>
        </div>
      </div>

      <div class="gantt-wave-timeline">
        ${renderWaveTimelineBar(wave)}
      </div>

      <div class="gantt-wave-status">
        <span class="gantt-status-badge ${wave.status}">${wave.status}</span>
      </div>

      <div class="gantt-wave-progress">
        ${renderWaveProgress(wave)}
      </div>
    </div>
    ${tasksHTML}
  `;
}

// Render timeline bar for a wave
function renderWaveTimelineBar(wave) {
  if (!ganttData || !ganttData.timelineStart) return '';

  let plannedLeft = 0;
  let plannedWidth = 0;
  let actualLeft = 0;
  let actualWidth = 0;

  // Calculate planned bar
  if (wave.planned_start && wave.planned_end) {
    const start = new Date(wave.planned_start);
    const end = new Date(wave.planned_end);

    plannedLeft = ((start - ganttData.timelineStart) / ganttData.timelineDuration) * 100;
    plannedWidth = Math.max(1, ((end - start) / ganttData.timelineDuration) * 100);
  }

  // Calculate actual bar
  if (wave.started_at) {
    const start = new Date(wave.started_at);
    const end = wave.completed_at ? new Date(wave.completed_at) : new Date();

    actualLeft = ((start - ganttData.timelineStart) / ganttData.timelineDuration) * 100;
    actualWidth = Math.max(1, ((end - start) / ganttData.timelineDuration) * 100);
  }

  return `
    <div class="gantt-wave-bar-container">
      ${plannedWidth > 0 ? `<div class="gantt-wave-bar planned" style="left: ${plannedLeft}%; width: ${plannedWidth}%"></div>` : ''}
      ${actualWidth > 0 ? `<div class="gantt-wave-bar actual" style="left: ${actualLeft}%; width: ${actualWidth}%"></div>` : ''}
    </div>
  `;
}

// Render progress circle for a wave
function renderWaveProgress(wave) {
  const progress = wave.tasks_total > 0 ? Math.round((wave.tasks_done / wave.tasks_total) * 100) : 0;
  const circumference = 2 * Math.PI * 18; // radius = 18
  const strokeDasharray = (progress / 100) * circumference;

  return `
    <div class="gantt-progress-circle">
      <svg viewBox="0 0 40 40">
        <circle cx="20" cy="20" r="18" class="gantt-progress-bg" />
        <circle cx="20" cy="20" r="18" class="gantt-progress-fill"
                stroke-dasharray="${strokeDasharray} ${circumference}" />
      </svg>
      <div class="gantt-progress-text">${progress}%</div>
    </div>
    <div class="gantt-progress-label">${wave.tasks_done}/${wave.tasks_total}</div>
  `;
}

// Render tasks for an expanded wave
function renderWaveTasks(wave) {
  if (!wave.tasks || wave.tasks.length === 0) {
    return `
      <div class="gantt-task-row">
        <div class="gantt-task-info" style="grid-column: 1 / -1; padding: 20px; text-align: center; color: var(--text-muted);">
          No tasks defined for this wave
        </div>
      </div>
    `;
  }

  return wave.tasks
    .filter(task => {
      if (!showCompletedTasks && task.status === 'done') return false;
      if (!showBlockedTasks && task.status === 'blocked') return false;
      return true;
    })
    .map(task => renderTaskRow(task, wave))
    .join('');
}

// Render a single task row
function renderTaskRow(task, wave) {
  return `
    <div class="gantt-task-row" data-task-id="${task.task_id}" onclick="showTaskDetails('${wave.wave_id}', '${task.task_id}')">
      <div class="gantt-task-info">
        <div class="gantt-task-icon">📋</div>
        <div class="gantt-task-details">
          <div class="gantt-task-id">${task.task_id}</div>
          <div class="gantt-task-title">${task.title}</div>
          <div class="gantt-task-meta">
            <span class="gantt-task-priority ${task.priority?.toLowerCase() || 'p3'}">${task.priority || 'P3'}</span>
            ${task.assignee ? `<span>👤 ${task.assignee}</span>` : ''}
            ${task.tokens ? `<span>🤖 ${task.tokens} tokens</span>` : ''}
          </div>
        </div>
      </div>

      <div class="gantt-task-timeline">
        ${renderTaskTimelineBar(task)}
      </div>

      <div class="gantt-task-status">
        <span class="gantt-status-badge ${task.status}">${task.status}</span>
      </div>

      <div class="gantt-task-progress">
        ${task.status === 'done' ? '✅' : task.status === 'doing' ? '🔄' : task.status === 'blocked' ? '🚫' : '⏳'}
      </div>
    </div>
  `;
}

// Render timeline bar for a task
function renderTaskTimelineBar(task) {
  // Tasks typically don't have timeline bars like waves
  // Could show duration or progress
  return `<div class="gantt-task-bar-container"></div>`;
}

// Toggle wave expansion
function toggleWaveExpansion(waveId) {
  console.log('Toggling wave expansion:', waveId);

  if (expandedWaves.has(waveId)) {
    expandedWaves.delete(waveId);
  } else {
    expandedWaves.add(waveId);
  }

  // Re-render to show/hide tasks
  renderInteractiveGantt();
}

// Show task details
function showTaskDetails(waveId, taskId) {
  console.log('Showing task details:', waveId, taskId);

  // Find the task
  const wave = ganttData.allWaves.find(w => w.wave_id === waveId);
  if (!wave || !wave.tasks) return;

  const task = wave.tasks.find(t => t.task_id === taskId);
  if (!task) return;

  // Show task details modal or expand inline
  const details = `
    Task: ${task.title}
    Status: ${task.status}
    Priority: ${task.priority}
    Assignee: ${task.assignee || 'Unassigned'}
    Tokens: ${task.tokens || 0}
  `;

  alert(details); // Temporary - will be replaced with proper modal
}

// Control functions
function expandAllWaves() {
  ganttData.allWaves.forEach(wave => {
    expandedWaves.add(wave.wave_id);
  });
  renderInteractiveGantt();
}

function collapseAllWaves() {
  expandedWaves.clear();
  renderInteractiveGantt();
}

function refreshGanttData() {
  loadGanttData();
}

function toggleCompletedTasks() {
  showCompletedTasks = document.getElementById('showCompletedTasks').checked;
  renderInteractiveGantt();
}

function toggleBlockedTasks() {
  showBlockedTasks = document.getElementById('showBlockedTasks').checked;
  renderInteractiveGantt();
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  // Initialize after project data is loaded
  setTimeout(initInteractiveGantt, 1000);
});

// Export functions
window.initInteractiveGantt = initInteractiveGantt;
window.loadGanttData = loadGanttData;
window.toggleWaveExpansion = toggleWaveExpansion;
window.showTaskDetails = showTaskDetails;
window.expandAllWaves = expandAllWaves;
window.collapseAllWaves = collapseAllWaves;
window.refreshGanttData = refreshGanttData;
window.toggleCompletedTasks = toggleCompletedTasks;
window.toggleBlockedTasks = toggleBlockedTasks;</content>
<parameter name="filePath">/Users/roberdan/.claude/dashboard/js/interactive-gantt.js