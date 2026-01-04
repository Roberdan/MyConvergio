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

  document.getElementById('drilldownContent').innerHTML = tasks.map(t => {
    const statusClass = t.status === 'done' ? 'green' : t.status === 'in_progress' ? 'orange' : t.status === 'blocked' ? 'red' : '';
    return `
      <div class="task-item" onclick="drillIntoTask('${waveId}', '${t.id}')">
        <span class="task-id">${t.id}</span>
        <span class="task-title">${t.title}</span>
        <span class="task-status ${statusClass}">${t.status}</span>
        ${t.timing?.duration ? `<span class="task-duration">${t.timing.duration}m</span>` : ''}
      </div>
    `;
  }).join('');
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
    ? `<span class="thor-badge approved" title="Validated ${formatDate(task.validated_at)}">Thor Approved</span>`
    : task.status === 'done'
    ? `<span class="thor-badge pending">Pending Validation</span>`
    : '';

  document.getElementById('drilldownContent').innerHTML = `
    <div class="task-detail">
      <div class="task-header-row">
        <h3>${task.title}</h3>
        ${thorBadge}
      </div>
      <div class="task-meta">
        <div><strong>Status:</strong> ${task.status}</div>
        <div><strong>Assignee:</strong> ${task.assignee || '-'}</div>
        <div><strong>Priority:</strong> ${task.priority || '-'}</div>
        <div><strong>Type:</strong> ${task.type || '-'}</div>
      </div>
      <div class="task-timing">
        <div><strong>Started:</strong> ${formatDate(task.started_at)}</div>
        <div><strong>Completed:</strong> ${formatDate(task.completed_at)}</div>
        <div><strong>Duration:</strong> ${task.duration_minutes ? task.duration_minutes + ' min' : '-'}</div>
      </div>
      <div class="task-tokens">
        <strong>Tokens:</strong> ${task.tokens ? task.tokens.toLocaleString() : '0'}
      </div>
      ${task.files?.length ? `
        <div class="task-files">
          <strong>Files:</strong>
          <ul>${task.files.map(f => `<li>${f}</li>`).join('')}</ul>
        </div>
      ` : ''}
      ${task.notes ? `<div class="task-notes"><strong>Notes:</strong> ${task.notes}</div>` : ''}
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
