// Views - Waves Loading and Gantt Rendering
// Loads waves view and renders Gantt chart

async function loadWavesView() {
  const content = document.getElementById('wavesViewContent');
  if (!content) return;

  if (!currentProjectId) {
    content.innerHTML = '<div class="cc-empty">Select a project to view waves</div>';
    return;
  }

  content.innerHTML = '<div class="waves-loading">Loading waves...</div>';

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/dashboard`);
    const projectData = await res.json();

    if (!projectData.waves || projectData.waves.length === 0) {
      content.innerHTML = '<div class="cc-empty">No waves in this project</div>';
      return;
    }

    renderWavesGanttInContainer(projectData.waves, content);
  } catch (e) {
    content.innerHTML = '<div class="cc-empty">Error: ' + e.message + '</div>';
  }
}

function renderWavesGanttInContainer(waves, container) {
  if (!waves || waves.length === 0) {
    container.innerHTML = '<div class="waves-empty">No waves available</div>';
    return;
  }

  const now = new Date();
  let minDate = null;
  let maxDate = null;

  waves.forEach(wave => {
    const start = wave.planned_start ? new Date(wave.planned_start) : null;
    const end = wave.planned_end ? new Date(wave.planned_end) : null;
    if (start && (!minDate || start < minDate)) minDate = start;
    if (end && (!maxDate || end > maxDate)) maxDate = end;
  });

  if (!minDate) minDate = new Date(now.getTime() - 86400000);
  if (!maxDate) maxDate = new Date(now.getTime() + 7 * 86400000);

  const dataRange = maxDate - minDate;
  const dynamicPadding = Math.max(30 * 60000, Math.min(6 * 3600000, dataRange * 0.15));
  minDate = new Date(minDate.getTime() - dynamicPadding);
  maxDate = new Date(maxDate.getTime() + dynamicPadding);

  const totalMs = maxDate - minDate;
  const totalDays = Math.ceil(totalMs / 86400000);
  const totalHours = totalMs / 3600000;

  const headers = buildGanttHeaders(minDate, maxDate, totalHours, totalDays);
  const todayPos = ((now - minDate) / totalMs) * 100;
  const showToday = todayPos >= 0 && todayPos <= 100;

  container.innerHTML = `
    <div class="gantt-container">
      <div class="gantt-header">
        <div class="gantt-header-label">WAVE</div>
        <div class="gantt-header-timeline">
          ${headers.map(h => `<div class="gantt-header-day">${h.label}</div>`).join('')}
        </div>
      </div>
      <div class="gantt-body">
        ${showToday ? `<div class="gantt-today-marker" style="left:calc(200px + ${todayPos}% * (100% - 200px - 180px) / 100);" title="Today"></div>` : ''}
        ${waves.map(wave => renderWaveGanttRow(wave, minDate, totalMs, now)).join('')}
      </div>
    </div>
  `;
}

function buildGanttHeaders(minDate, maxDate, totalHours, totalDays) {
  const headers = [];
  let interval, formatOpts;

  if (totalHours <= 3) {
    interval = 30 * 60000;
    formatOpts = { hour: '2-digit', minute: '2-digit' };
  } else if (totalHours <= 8) {
    interval = 3600000;
    formatOpts = { hour: '2-digit', minute: '2-digit' };
  } else if (totalDays <= 2) {
    interval = 3 * 3600000;
    formatOpts = { month: 'short', day: 'numeric', hour: '2-digit' };
  } else if (totalDays <= 7) {
    interval = 6 * 3600000;
    formatOpts = { month: 'short', day: 'numeric', hour: '2-digit' };
  } else {
    interval = 86400000;
    formatOpts = { month: 'short', day: 'numeric' };
  }

  for (let t = minDate.getTime(); t <= maxDate.getTime(); t += interval) {
    const d = new Date(t);
    headers.push({ label: d.toLocaleString('en-US', formatOpts), time: t });
  }

  return headers;
}

function renderWaveGanttRow(wave, minDate, totalMs, now) {
  const start = wave.planned_start ? new Date(wave.planned_start) : null;
  const end = wave.planned_end ? new Date(wave.planned_end) : null;
  const actual_start = wave.started_at ? new Date(wave.started_at) : null;
  const actual_end = wave.completed_at ? new Date(wave.completed_at) : null;

  let plannedLeft = 0, plannedWidth = 5;
  if (start && end) {
    plannedLeft = ((start - minDate) / totalMs) * 100;
    plannedWidth = Math.max(2, ((end - start) / totalMs) * 100);
  }

  let actualLeft = plannedLeft, actualWidth = 0;
  if (actual_start) {
    actualLeft = ((actual_start - minDate) / totalMs) * 100;
    const actualEndTime = actual_end || now;
    actualWidth = Math.max(1, ((actualEndTime - actual_start) / totalMs) * 100);
  }

  const progress = wave.tasks_total > 0 ? Math.round((wave.tasks_done / wave.tasks_total) * 100) : 0;
  const startStr = start ? start.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'Not planned';
  const endStr = end ? end.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'Not planned';
  const hasDeps = wave.depends_on && wave.depends_on.length > 0;

  return `
    <div class="gantt-row" onclick="drillIntoWave('${wave.wave_id}')" title="${wave.name}&#10;Start: ${startStr}&#10;End: ${endStr}&#10;Progress: ${progress}%">
      <div class="gantt-label">
        <div class="gantt-label-status ${wave.status}"></div>
        <div class="gantt-label-info">
          <div class="gantt-label-header">
            <span class="gantt-label-text">${wave.wave_id}</span>
            ${hasDeps ? `<span class="gantt-dep-badge" title="Depends on: ${wave.depends_on}">&#x2192; ${wave.depends_on}</span>` : ''}
            <button class="gantt-markdown-btn" onclick="event.stopPropagation(); showWaveMarkdown('${wave.wave_id}')" title="View wave documentation">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                <path d="M22.27 19.385H1.73A1.73 1.73 0 0 1 0 17.655V6.345a1.73 1.73 0 0 1 1.73-1.73h20.54A1.73 1.73 0 0 1 24 6.345v11.308a1.73 1.73 0 0 1-1.73 1.731zM5.769 15.923v-4.5l2.308 2.885 2.307-2.885v4.5h2.308V8.078h-2.308l-2.307 2.885-2.308-2.885H3.46v7.847zM21.232 12h-2.309V8.077h-2.307V12h-2.308l3.461 4.039z"/>
              </svg>
            </button>
          </div>
          <div class="gantt-label-summary" title="${wave.name}">${wave.name}</div>
        </div>
      </div>
      <div class="gantt-timeline">
        ${start && end ? `
          <div class="gantt-bar planned ${wave.status}" style="left:${plannedLeft}%;width:${plannedWidth}%;">
            <div class="gantt-bar-progress" style="width:${progress}%"></div>
            <span class="gantt-bar-label">${wave.tasks_done}/${wave.tasks_total}</span>
          </div>
        ` : `<div class="gantt-no-dates">No dates</div>`}
        ${actual_start && wave.status !== 'done' ? `
          <div class="gantt-bar actual" style="left:${actualLeft}%;width:${actualWidth}%;"></div>
        ` : ''}
      </div>
      <div class="gantt-dates">
        <span class="gantt-date-start">${startStr}</span>
        <span class="gantt-date-end">${endStr}</span>
      </div>
    </div>
  `;
}

console.log('Views waves loaded');
