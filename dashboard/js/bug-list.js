// Bug/Todo List - Quick Entry and Planner Integration

let bugListItems = [];
let bugListEditing = null;

// Initialize bug list from localStorage
function initBugList() {
  const saved = localStorage.getItem(`bugList_${currentProjectId}`);
  if (saved) {
    bugListItems = JSON.parse(saved);
  }
  renderBugList();
}

// Save bug list to localStorage
function saveBugList() {
  localStorage.setItem(`bugList_${currentProjectId}`, JSON.stringify(bugListItems));
}

// Render bug list
function renderBugList() {
  const container = document.getElementById('bugListContainer');
  if (!container) return;

  if (bugListItems.length === 0) {
    container.innerHTML = `
      <div class="bug-list-empty">
        <p>No bugs or todos yet</p>
        <button class="bug-add-btn" onclick="addBugItem()">+ Add First Item</button>
      </div>
    `;
    return;
  }

  const html = `
    <div class="bug-list-header">
      <h4>Bugs & Todos (${bugListItems.length})</h4>
      <button class="bug-add-btn" onclick="addBugItem()">+ Add</button>
      <button class="bug-execute-btn" onclick="executeBugList()" ${bugListItems.length === 0 ? 'disabled' : ''}>
        ⚡ Execute with Planner
      </button>
    </div>
    <div class="bug-list-items">
      ${bugListItems.map((item, idx) => renderBugItem(item, idx)).join('')}
    </div>
  `;

  container.innerHTML = html;
}

// Render single bug item
function renderBugItem(item, idx) {
  const isEditing = bugListEditing === idx;

  if (isEditing) {
    return `
      <div class="bug-item editing" data-idx="${idx}">
        <input type="text" class="bug-item-input" id="bugEdit${idx}" value="${escapeHtml(item.text)}"
               onkeydown="handleBugEditKeydown(event, ${idx})" autofocus>
        <div class="bug-item-actions">
          <button class="bug-item-btn save" onclick="saveBugEdit(${idx})">✓</button>
          <button class="bug-item-btn cancel" onclick="cancelBugEdit()">×</button>
        </div>
      </div>
    `;
  }

  return `
    <div class="bug-item ${item.priority || ''}" data-idx="${idx}">
      <div class="bug-item-checkbox">
        <input type="checkbox" id="bug${idx}" ${item.done ? 'checked' : ''}
               onchange="toggleBugDone(${idx})">
        <label for="bug${idx}"></label>
      </div>
      <div class="bug-item-text ${item.done ? 'done' : ''}" onclick="editBugItem(${idx})">
        ${escapeHtml(item.text)}
      </div>
      <div class="bug-item-meta">
        ${item.priority ? `<span class="bug-priority ${item.priority}">${item.priority}</span>` : ''}
        <select class="bug-priority-select" onchange="setBugPriority(${idx}, this.value)">
          <option value="">-</option>
          <option value="P0" ${item.priority === 'P0' ? 'selected' : ''}>P0</option>
          <option value="P1" ${item.priority === 'P1' ? 'selected' : ''}>P1</option>
          <option value="P2" ${item.priority === 'P2' ? 'selected' : ''}>P2</option>
        </select>
      </div>
      <div class="bug-item-actions">
        <button class="bug-item-btn edit" onclick="editBugItem(${idx})" title="Edit">✎</button>
        <button class="bug-item-btn delete" onclick="deleteBugItem(${idx})" title="Delete">×</button>
      </div>
    </div>
  `;
}

// Add new bug item
function addBugItem() {
  const newItem = {
    text: '',
    done: false,
    priority: null,
    created: new Date().toISOString()
  };

  bugListItems.unshift(newItem);
  bugListEditing = 0;
  renderBugList();

  // Focus input
  setTimeout(() => {
    const input = document.getElementById('bugEdit0');
    if (input) input.focus();
  }, 50);
}

// Edit bug item
function editBugItem(idx) {
  bugListEditing = idx;
  renderBugList();
}

// Save bug edit
function saveBugEdit(idx) {
  const input = document.getElementById(`bugEdit${idx}`);
  if (!input) return;

  const text = input.value.trim();
  if (text === '') {
    // Remove if empty
    bugListItems.splice(idx, 1);
  } else {
    bugListItems[idx].text = text;
  }

  bugListEditing = null;
  saveBugList();
  renderBugList();
}

// Cancel bug edit
function cancelBugEdit() {
  // If it was a new item (empty text), remove it
  if (bugListEditing !== null && bugListItems[bugListEditing].text === '') {
    bugListItems.splice(bugListEditing, 1);
  }

  bugListEditing = null;
  renderBugList();
}

// Handle keydown in edit mode
function handleBugEditKeydown(event, idx) {
  if (event.key === 'Enter') {
    event.preventDefault();
    saveBugEdit(idx);
  } else if (event.key === 'Escape') {
    event.preventDefault();
    cancelBugEdit();
  }
}

// Toggle bug done status
function toggleBugDone(idx) {
  bugListItems[idx].done = !bugListItems[idx].done;
  saveBugList();
  renderBugList();
}

// Set bug priority
function setBugPriority(idx, priority) {
  bugListItems[idx].priority = priority || null;
  saveBugList();
  renderBugList();
}

// Delete bug item
function deleteBugItem(idx) {
  if (!confirm('Delete this item?')) return;

  bugListItems.splice(idx, 1);
  saveBugList();
  renderBugList();
}

// Execute bug list with planner
async function executeBugList() {
  if (bugListItems.length === 0) {
    showToast('No items to execute', 'warning');
    return;
  }

  // Filter out completed items
  const activeBugs = bugListItems.filter(item => !item.done);
  if (activeBugs.length === 0) {
    showToast('All items are completed', 'info');
    return;
  }

  // Build prompt for planner
  const prompt = buildPlannerPrompt(activeBugs);

  // Show confirmation modal
  showPlannerExecutionModal(prompt, activeBugs);
}

// Build planner prompt from bug list
function buildPlannerPrompt(bugs) {
  let prompt = `# Bug/Todo List Execution Request\n\n`;
  prompt += `**Project**: ${currentProjectId}\n`;
  prompt += `**Date**: ${new Date().toLocaleString('it-IT')}\n\n`;
  prompt += `---\n\n`;
  prompt += `I have ${bugs.length} bug${bugs.length !== 1 ? 's' : ''}/todo${bugs.length !== 1 ? 's' : ''} to address:\n\n`;

  bugs.forEach((bug, idx) => {
    const priority = bug.priority ? `[${bug.priority}]` : '';
    prompt += `${idx + 1}. ${priority} ${bug.text}\n`;
  });

  prompt += `\n---\n\n`;
  prompt += `Please analyze these items, ask clarifying questions if needed, and create a comprehensive execution plan.\n`;

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
        <button class="planner-modal-close" onclick="closePlannerModal()">×</button>
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
          <p class="planner-hint">You can edit the prompt before sending to planner</p>
        </div>

        <div class="planner-section">
          <h4>Execution Options</h4>
          <label class="planner-option">
            <input type="checkbox" id="plannerArchiveBugs" checked>
            Archive completed bugs after plan creation
          </label>
        </div>
      </div>

      <div class="planner-modal-footer">
        <button class="planner-btn secondary" onclick="closePlannerModal()">Cancel</button>
        <button class="planner-btn primary" onclick="sendToPlanner()">
          Send to Planner
        </button>
      </div>
    </div>
  `;

  document.body.appendChild(modal);
  modal.style.display = 'block';
}

// Close planner modal
function closePlannerModal() {
  const modal = document.getElementById('plannerModal');
  if (modal) {
    modal.remove();
  }
}

// Send to planner (copy command to clipboard)
function sendToPlanner() {
  const promptEdit = document.getElementById('plannerPromptEdit');
  const archiveBugs = document.getElementById('plannerArchiveBugs');

  if (!promptEdit) return;

  const prompt = promptEdit.value;

  // Build claude command
  const command = `claude "${prompt.replace(/"/g, '\\"')}"`;

  // Copy to clipboard
  navigator.clipboard.writeText(command).then(() => {
    showToast('Command copied to clipboard!', 'success');

    // Show instruction modal
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
        <h3>✅ Command Ready</h3>
        <button class="planner-modal-close" onclick="closePlannerInstructionModal()">×</button>
      </div>

      <div class="planner-modal-body">
        <div class="planner-success-message">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#22c55e" stroke-width="2">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>
          <p>Command copied to clipboard!</p>
        </div>

        <div class="planner-section">
          <h4>Next Steps</h4>
          <ol class="planner-steps">
            <li>Open your terminal</li>
            <li>Paste the command (Cmd+V or Ctrl+V)</li>
            <li>Press Enter to start Claude</li>
            <li>Claude will analyze the bugs and create an execution plan</li>
            <li>Review the plan and approve when ready</li>
          </ol>
        </div>

        <div class="planner-section">
          <h4>Command Preview</h4>
          <pre class="planner-command-preview">${escapeHtml(command)}</pre>
        </div>
      </div>

      <div class="planner-modal-footer">
        <button class="planner-btn primary" onclick="closePlannerInstructionModal()">
          Got it!
        </button>
      </div>
    </div>
  `;

  document.body.appendChild(modal);
  modal.style.display = 'block';

  // If should archive, mark bugs as done after modal closes
  if (shouldArchive) {
    setTimeout(() => {
      bugListItems.forEach(item => {
        if (!item.done) item.done = true;
      });
      saveBugList();
      renderBugList();
    }, 5000);
  }
}

// Close planner instruction modal
function closePlannerInstructionModal() {
  const modal = document.getElementById('plannerInstructionModal');
  if (modal) {
    modal.remove();
  }
}

// Load bug list when project changes
if (typeof window !== 'undefined') {
  const originalSelectProject = window.selectProject;
  window.selectProject = function(projectId) {
    if (originalSelectProject) originalSelectProject(projectId);
    initBugList();
  };
}
