// Gantt Chart for Waves

function renderWavesGantt() {
  const wavesList = document.getElementById('wavesList');
  if (!wavesList || !data.waves || data.waves.length === 0) {
    if (wavesList) wavesList.innerHTML = '<div class="waves-loading">No waves</div>';
    return;
  }

  const now = new Date();
  let minDate = null;
  let maxDate = null;

  data.waves.forEach(wave => {
    const start = wave.planned_start ? new Date(wave.planned_start) : null;
    const end = wave.planned_end ? new Date(wave.planned_end) : null;
    if (start && (!minDate || start < minDate)) minDate = start;
    if (end && (!maxDate || end > maxDate)) maxDate = end;
  });

  if (!minDate) minDate = new Date(now.getTime() - 86400000);
  if (!maxDate) maxDate = new Date(now.getTime() + 7 * 86400000);

  // Smart padding: 15% of data range, min 30min, max 6h
  const dataRange = maxDate - minDate;
  const dynamicPadding = Math.max(30 * 60000, Math.min(6 * 3600000, dataRange * 0.15));
  minDate = new Date(minDate.getTime() - dynamicPadding);
  maxDate = new Date(maxDate.getTime() + dynamicPadding);

  const totalMs = maxDate - minDate;
  const totalDays = Math.ceil(totalMs / 86400000);
  const totalHours = totalMs / 3600000;

  // Smart header intervals based on total time range
  const headers = [];
  let interval, formatOpts;

  if (totalHours <= 3) {
    // Under 3 hours: 30-minute intervals
    interval = 30 * 60000;
    formatOpts = { hour: '2-digit', minute: '2-digit' };
  } else if (totalHours <= 8) {
    // 3-8 hours: 1-hour intervals
    interval = 3600000;
    formatOpts = { hour: '2-digit', minute: '2-digit' };
  } else if (totalDays <= 2) {
    // 8h - 2 days: 3-hour intervals
    interval = 3 * 3600000;
    formatOpts = { month: 'short', day: 'numeric', hour: '2-digit' };
  } else if (totalDays <= 7) {
    // 2-7 days: 6-hour intervals
    interval = 6 * 3600000;
    formatOpts = { month: 'short', day: 'numeric', hour: '2-digit' };
  } else {
    // Over 7 days: daily intervals
    interval = 86400000;
    formatOpts = { month: 'short', day: 'numeric' };
  }

  for (let t = minDate.getTime(); t <= maxDate.getTime(); t += interval) {
    const d = new Date(t);
    headers.push({
      label: d.toLocaleString('en-US', formatOpts),
      time: t
    });
  }

  const todayPos = ((now - minDate) / totalMs) * 100;
  const showToday = todayPos >= 0 && todayPos <= 100;

  wavesList.innerHTML = `
    <div class="gantt-container">
      <div class="gantt-header">
        <div class="gantt-header-label">WAVE</div>
        <div class="gantt-header-timeline">
          ${headers.map(h => `<div class="gantt-header-day">${h.label}</div>`).join('')}
        </div>
      </div>
      <div class="gantt-body">
        ${showToday ? `<div class="gantt-today-marker" style="left:calc(200px + ${todayPos}% * (100% - 200px) / 100);" title="Today"></div>` : ''}
        ${data.waves.map(wave => {
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
                  <span class="gantt-label-text">${wave.wave_id}</span>
                  ${hasDeps ? `<span class="gantt-dep-badge" title="Depends on: ${wave.depends_on}">&#x2192; ${wave.depends_on}</span>` : ''}
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
        }).join('')}
      </div>
    </div>
  `;
}
