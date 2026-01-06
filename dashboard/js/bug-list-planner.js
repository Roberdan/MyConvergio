// Bug/Todo List - Planner Integration Module
// Execute bugs with planner, modal handling
// Execute bug list with planner
async function executeBugList() {
  if (bugListItems.length === 0) {
    showToast('No items to execute', 'warning');
    return;
  }
  const activeBugs = bugListItems.filter(item => !item.done);
  if (activeBugs.length === 0) {
    showToast('All items are completed', 'info');
    return;
  }
  const prompt = buildPlannerPrompt(activeBugs);
  showPlannerExecutionModal(prompt, activeBugs);
}
// Build planner prompt from bug list
function buildPlannerPrompt(bugs) {
  let prompt = `# Bug/Todo List Execution Request\n\n`;
  prompt += `**Project**: ${currentProjectId}\n`;
  prompt += `**Date**: ${new Date().toLocaleString('it-IT')}\n\n---\n\n`;
  prompt += `I have ${bugs.length} bug${bugs.length !== 1 ? 's' : ''}/todo${bugs.length !== 1 ? 's' : ''} to address:\n\n`;
  bugs.forEach((bug, idx) => {
    const priority = bug.priority ? `[${bug.priority}]` : '';
    prompt += `${idx + 1}. ${priority} ${bug.text}\n`;
  });
  prompt += `\n---\n\nPlease analyze these items, ask clarifying questions if needed, and create an execution plan.\n`;
  return prompt;
}
// Show planner execution modal
function showPlannerExecutionModal(prompt, bugs) {
  const modal = document.createElement('div');
  modal.id = 'plannerModal';
  modal.className = 'planner-modal';
  modal.innerHTML = `
    <div class="planner-modal-content">
      <div class="planner-modal-header">
        <h3>Execute with Planner</h3>
        <button class="planner-modal-close" onclick="closePlannerModal()">X</button>
      </div>
      <div class="planner-modal-body">
        <div class="planner-section">
          <h4>Items to Process (${bugs.length})</h4>
          <ul class="planner-items-list">
            ${bugs.map(bug => `
              <li class="${bug.priority || ''}">
                ${bug.priority ? `<span class="bug-priority ${bug.priority}">${bug.priority}</span>` : ''}
                ${escapeHtml(bug.text)}
              </li>
            `).join('')}
          </ul>
        </div>
        <div class="planner-section">
          <h4>Generated Prompt</h4>
          <textarea class="planner-prompt-edit" id="plannerPromptEdit" rows="12">${escapeHtml(prompt)}</textarea>
          <p class="planner-hint">You can edit the prompt before sending</p>
        </div>
        <div class="planner-section">
          <h4>Options</h4>
          <label class="planner-option">
            <input type="checkbox" id="plannerArchiveBugs" checked>
            Archive completed bugs after plan creation
          </label>
        </div>
      </div>
      <div class="planner-modal-footer">
        <button class="planner-btn secondary" onclick="closePlannerModal()">Cancel</button>
        <button class="planner-btn primary" onclick="sendToPlanner()">Send to Planner</button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);
  modal.style.display = 'block';
}
// Close planner modal
function closePlannerModal() {
  const modal = document.getElementById('plannerModal');
  if (modal) modal.remove();
}
// Send to planner
function sendToPlanner() {
  const promptEdit = document.getElementById('plannerPromptEdit');
  const archiveBugs = document.getElementById('plannerArchiveBugs');
  if (!promptEdit) return;
  const command = `claude "${promptEdit.value.replace(/"/g, '\\"')}"`;
  navigator.clipboard.writeText(command).then(() => {
    showToast('Command copied to clipboard!', 'success');
    showPlannerInstructionModal(command, archiveBugs?.checked);
    closePlannerModal();
  }).catch(err => {
    showToast('Failed to copy: ' + err.message, 'error');
  });
}
// Show planner instruction modal
function showPlannerInstructionModal(command, shouldArchive) {
  const modal = document.createElement('div');
  modal.id = 'plannerInstructionModal';
  modal.className = 'planner-modal';
  modal.innerHTML = `
    <div class="planner-modal-content">
      <div class="planner-modal-header">
        <h3>Command Ready</h3>
        <button class="planner-modal-close" onclick="closePlannerInstructionModal()">X</button>
      </div>
      <div class="planner-modal-body">
        <div class="planner-success-message">
          <p>Command copied to clipboard!</p>
        </div>
        <div class="planner-section">
          <h4>Next Steps</h4>
          <ol class="planner-steps">
            <li>Open your terminal</li>
            <li>Paste the command (Cmd+V)</li>
            <li>Press Enter to start Claude</li>
            <li>Claude will analyze and create a plan</li>
            <li>Review and approve when ready</li>
          </ol>
        </div>
        <div class="planner-section">
          <h4>Command Preview</h4>
          <pre class="planner-command-preview">${escapeHtml(command)}</pre>
        </div>
      </div>
      <div class="planner-modal-footer">
        <button class="planner-btn primary" onclick="closePlannerInstructionModal()">Got it!</button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);
  modal.style.display = 'block';
  if (shouldArchive) {
    setTimeout(() => {
      bugListItems.forEach(item => { if (!item.done) item.done = true; });
      saveBugList();
      renderBugList();
    }, 5000);
  }
}
// Close planner instruction modal
function closePlannerInstructionModal() {
  const modal = document.getElementById('plannerInstructionModal');
  if (modal) modal.remove();
}

