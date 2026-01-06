// Bug/Todo List - Item Module
// Individual item rendering and editing

// Render single bug item
function renderBugItem(item, idx) {
  const isEditing = bugListEditing === idx;

  if (isEditing) {
    return `
      <div class="bug-item editing" data-idx="${idx}">
        <input type="text" class="bug-item-input" id="bugEdit${idx}" value="${escapeHtml(item.text)}"
               onkeydown="handleBugEditKeydown(event, ${idx})" autofocus>
        <div class="bug-item-actions">
          <button class="bug-item-btn save" onclick="saveBugEdit(${idx})">OK</button>
          <button class="bug-item-btn cancel" onclick="cancelBugEdit()">X</button>
        </div>
      </div>
    `;
  }

  return `
    <div class="bug-item ${item.priority || ''}" data-idx="${idx}">
      <div class="bug-item-checkbox">
        <input type="checkbox" id="bug${idx}" ${item.done ? 'checked' : ''} onchange="toggleBugDone(${idx})">
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
        <button class="bug-item-btn edit" onclick="editBugItem(${idx})" title="Edit">E</button>
        <button class="bug-item-btn delete" onclick="deleteBugItem(${idx})" title="Delete">X</button>
      </div>
    </div>
  `;
}

// Add new bug item
function addBugItem() {
  bugListItems.unshift({
    text: '',
    done: false,
    priority: null,
    created: new Date().toISOString()
  });
  bugListEditing = 0;
  renderBugList();
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

console.log('Bug list item loaded');
