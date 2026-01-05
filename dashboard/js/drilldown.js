// Drilldown and Navigation

function renderWaves() {
  const wavesList = document.getElementById('wavesList');
  if (!wavesList || !data.waves) return;

  wavesList.innerHTML = data.waves.map(w => {
    const progress = w.total > 0 ? Math.round((w.done / w.total) * 100) : 0;
    const statusClass = w.status === 'done' ? 'green' : w.status === 'in_progress' ? 'orange' : '';
    return `
      <div class="wave-item" onclick="drillIntoWave('${w.id}')">
        <div class="wave-item-header">
          <span class="wave-id">${w.id}</span>
          <span class="wave-name">${w.name}</span>
          <span class="wave-status ${statusClass}">${w.status}</span>
        </div>
        <div class="wave-item-progress">
          <div class="wave-bar">
            <div class="wave-bar-fill" style="width:${progress}%"></div>
          </div>
          <span class="wave-count">${w.done}/${w.total}</span>
        </div>
      </div>
    `;
  }).join('');
}

function drillIntoWave(waveId) {
  const wave = data.waves.find(w => w.id === waveId);
  if (!wave) return;

  drilldownState = { level: 'wave', waveId, taskId: null };
  document.getElementById('wavesSummary').style.display = 'none';
  document.getElementById('drilldownPanel').style.display = 'block';
  document.getElementById('drilldownTitle').textContent = `${wave.id} - ${wave.name}`;
  document.getElementById('drilldownBack').style.display = 'inline-block';

  const tasks = wave.tasks || [];
  if (tasks.length === 0) {
    document.getElementById('drilldownContent').innerHTML = `
      <div class="no-tasks">No task details available for this wave.</div>
    `;
    return;
  }

  // Helper function for status icon
  const getStatusIcon = (status) => {
    if (status === 'done') return '✓';
    if (status === 'in_progress') return '●';
    if (status === 'blocked') return '✖';
    return '○';
  };

  // Helper function for priority badge
  const getPriorityBadge = (priority) => {
    if (!priority) return '<span class="task-priority-badge">-</span>';
    const pClass = priority === 'P0' || priority === 'P1' ? 'high' : priority === 'P2' ? 'medium' : 'low';
    return `<span class="task-priority-badge ${pClass}">${priority}</span>`;
  };

  // Build table
  const tableHTML = `
    <div class="task-table-container">
      <table class="task-table">
        <thead>
          <tr>
            <th class="task-col-id">ID</th>
            <th class="task-col-title">Task</th>
            <th class="task-col-status">Status</th>
            <th class="task-col-priority">Priority</th>
            <th class="task-col-assignee">Assignee</th>
            <th class="task-col-tokens">Tokens</th>
          </tr>
        </thead>
        <tbody>
          ${tasks.map(t => {
            const statusClass = t.status === 'done' ? 'done' : t.status === 'in_progress' ? 'in-progress' : t.status === 'blocked' ? 'blocked' : 'pending';
            const tokens = t.tokens ? t.tokens.toLocaleString() : '-';
            const assignee = t.assignee || '-';

            return `
              <tr class="task-row" onclick="drillIntoTask('${waveId}', '${t.id}')">
                <td class="task-col-id">
                  <span class="task-id-badge">${t.id}</span>
                </td>
                <td class="task-col-title">
                  <div class="task-title-cell">
                    <span class="task-title-text">${t.title}</span>
                    ${t.type ? `<span class="task-type-badge">${t.type}</span>` : ''}
                    <button class="task-markdown-btn" onclick="event.stopPropagation(); showTaskMarkdown('${waveId}', '${t.task_id}')" title="View task in wave documentation">📄</button>
                  </div>
                </td>
                <td class="task-col-status">
                  <span class="task-status-badge ${statusClass}">
                    <span class="task-status-icon">${getStatusIcon(t.status)}</span>
                    ${t.status.replace('_', ' ')}
                  </span>
                </td>
                <td class="task-col-priority">
                  ${getPriorityBadge(t.priority)}
                </td>
                <td class="task-col-assignee">
                  <span class="task-assignee-badge">${assignee}</span>
                </td>
                <td class="task-col-tokens">
                  <span class="task-tokens-value">${tokens}</span>
                </td>
              </tr>
            `;
          }).join('')}
        </tbody>
      </table>
    </div>
    <div class="task-table-footer">
      <span>${tasks.length} task${tasks.length !== 1 ? 's' : ''}</span>
      <span>•</span>
      <span>${tasks.filter(t => t.status === 'done').length} completed</span>
      <span>•</span>
      <span>${tasks.filter(t => t.status === 'in_progress').length} in progress</span>
    </div>
  `;

  document.getElementById('drilldownContent').innerHTML = tableHTML;
}

function drillIntoTask(waveId, taskId) {
  const wave = data.waves.find(w => w.id === waveId);
  const task = wave?.tasks?.find(t => t.id === taskId);
  if (!task) return;

  drilldownState = { level: 'task', waveId, taskId };
  document.getElementById('drilldownTitle').textContent = `Task ${task.id}`;

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    const d = new Date(dateStr);
    return d.toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  };

  const thorBadge = task.validated_by
    ? `<span class="thor-badge approved" title="Validated ${formatDate(task.validated_at)}">✓ Thor Approved</span>`
    : task.status === 'done'
    ? `<span class="thor-badge pending">⏳ Pending Validation</span>`
    : '';

  const statusIcon = task.status === 'done' ? '✓' : task.status === 'in_progress' ? '●' : task.status === 'blocked' ? '✖' : '○';
  const statusClass = task.status === 'done' ? 'done' : task.status === 'in_progress' ? 'in-progress' : task.status === 'blocked' ? 'blocked' : 'pending';

  document.getElementById('drilldownContent').innerHTML = `
    <div class="task-detail-card">
      <!-- Header -->
      <div class="task-detail-header">
        <div class="task-detail-title-row">
          <h2 class="task-detail-title">${task.title}</h2>
          ${thorBadge}
        </div>
        <div class="task-detail-meta-row">
          <span class="task-detail-status ${statusClass}">
            <span class="task-status-icon">${statusIcon}</span>
            ${task.status.replace('_', ' ').toUpperCase()}
          </span>
          <span class="task-detail-separator">•</span>
          <span class="task-detail-id">${task.id}</span>
        </div>
      </div>

      <!-- Info Grid -->
      <div class="task-detail-grid">
        <div class="task-detail-section">
          <div class="task-detail-section-title">Overview</div>
          <div class="task-detail-info-grid">
            <div class="task-detail-info-item">
              <span class="task-detail-label">Assignee</span>
              <span class="task-detail-value">${task.assignee || '-'}</span>
            </div>
            <div class="task-detail-info-item">
              <span class="task-detail-label">Priority</span>
              <span class="task-detail-value priority-${task.priority || 'none'}">${task.priority || '-'}</span>
            </div>
            <div class="task-detail-info-item">
              <span class="task-detail-label">Type</span>
              <span class="task-detail-value">${task.type || '-'}</span>
            </div>
            <div class="task-detail-info-item">
              <span class="task-detail-label">Tokens</span>
              <span class="task-detail-value tokens">${task.tokens ? task.tokens.toLocaleString() : '0'}</span>
            </div>
          </div>
        </div>

        <div class="task-detail-section">
          <div class="task-detail-section-title">Timeline</div>
          <div class="task-detail-timeline">
            <div class="task-detail-timeline-item">
              <div class="task-detail-timeline-dot start"></div>
              <div class="task-detail-timeline-content">
                <span class="task-detail-timeline-label">Started</span>
                <span class="task-detail-timeline-value">${formatDate(task.started_at)}</span>
              </div>
            </div>
            ${task.completed_at ? `
              <div class="task-detail-timeline-item">
                <div class="task-detail-timeline-dot end"></div>
                <div class="task-detail-timeline-content">
                  <span class="task-detail-timeline-label">Completed</span>
                  <span class="task-detail-timeline-value">${formatDate(task.completed_at)}</span>
                </div>
              </div>
            ` : ''}
            ${task.duration_minutes ? `
              <div class="task-detail-timeline-item">
                <div class="task-detail-timeline-dot duration"></div>
                <div class="task-detail-timeline-content">
                  <span class="task-detail-timeline-label">Duration</span>
                  <span class="task-detail-timeline-value">${task.duration_minutes} min</span>
                </div>
              </div>
            ` : ''}
          </div>
        </div>

        ${task.files?.length ? `
          <div class="task-detail-section">
            <div class="task-detail-section-title">Files Modified (${task.files.length})</div>
            <div class="task-detail-files">
              ${task.files.map(f => `
                <div class="task-detail-file">
                  <span class="task-file-icon">📄</span>
                  <span class="task-file-path">${f}</span>
                </div>
              `).join('')}
            </div>
          </div>
        ` : ''}

        ${task.notes ? `
          <div class="task-detail-section full-width">
            <div class="task-detail-section-title">Notes</div>
            <div class="task-detail-notes">${task.notes}</div>
          </div>
        ` : ''}
      </div>
    </div>
  `;
}

function navigateBack() {
  if (drilldownState.level === 'task') {
    drillIntoWave(drilldownState.waveId);
  } else if (drilldownState.level === 'wave') {
    drilldownState = { level: 'plan', waveId: null, taskId: null };
    document.getElementById('drilldownPanel').style.display = 'none';
    document.getElementById('wavesSummary').style.display = 'block';
  }
}

function refreshWaves() {
  renderWaves();
}
