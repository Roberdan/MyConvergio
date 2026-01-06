// Tasks View - Full page expanded waves and tasks
// Target: ganttContent element

async function loadTasksView() {
  Logger.info('Loading tasks view...');
  const content = document.getElementById('ganttContent');
  if (!content) return;

  content.innerHTML = '<div class="gantt-loading">Loading tasks...</div>';

  if (currentProjectId) {
    GanttView.renderTarget = 'ganttContent';
    await GanttView.load(currentProjectId);
    // Auto-expand all waves to show all tasks
    GanttView.expandAll();
  } else {
    content.innerHTML = '<div class="empty-state"><div class="empty-state-title">Select a project</div></div>';
  }
}

// Keep loadWavesView as alias for backwards compatibility
const loadWavesView = loadTasksView;

function showWaveDetails(waveId, waveName, status, done, total) {
  showToast(`Wave: ${waveName}\nID: ${waveId}\nStatus: ${status}\nTasks: ${done}/${total}`, 'info');
}

function setGanttViewMode(mode) {
  Logger.info('View mode:', mode);
}

function expandAllGantt() {
  GanttView.expandAll();
}

function collapseAllGantt() {
  GanttView.collapseAll();
}

function exportGantt() {
  Logger.info('Export Gantt data');
}

function openFile(filePath) {
  Logger.info('Open file:', filePath);
}

function viewFileDiff(filePath) {
  Logger.info('View diff for:', filePath);
}

window.loadWavesView = loadWavesView;
window.loadTasksView = loadTasksView;
window.showWaveDetails = showWaveDetails;
window.setGanttViewMode = setGanttViewMode;
window.expandAllGantt = expandAllGantt;
window.collapseAllGantt = collapseAllGantt;
window.exportGantt = exportGantt;
window.openFile = openFile;
window.viewFileDiff = viewFileDiff;
