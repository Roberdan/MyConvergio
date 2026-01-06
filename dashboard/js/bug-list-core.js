// Bug/Todo List - Core Module
// State management, initialization, and main rendering
let bugListItems = [];
let bugListEditing = null;
// Initialize bug list from localStorage
function initBugList() {
  if (!currentProjectId) {
    bugListItems = [];
    renderBugListNoProject();
    return;
  }
  const saved = localStorage.getItem(`bugList_${currentProjectId}`);
  if (saved) {
    try {
      bugListItems = JSON.parse(saved);
    } catch (e) {
      console.warn('Failed to parse bug list:', e);
      bugListItems = [];
    }
  } else {
    bugListItems = [];
  }
  renderBugList();
}
// Render empty state when no project selected
function renderBugListNoProject() {
  const container = document.getElementById('bugListContainer');
  if (!container) return;
  container.innerHTML = `
    <div class="bug-list-empty">
      <p>Select a project to view bugs/todos</p>
    </div>
  `;
}
// Save bug list to localStorage
function saveBugList() {
  if (!currentProjectId) {
    console.warn('Cannot save bug list: no project selected');
    return;
  }
  localStorage.setItem(`bugList_${currentProjectId}`, JSON.stringify(bugListItems));
}
// Render bug list
function renderBugList() {
  const container = document.getElementById('bugListContainer');
  if (!container) {
    console.warn('Bug list container not found');
    return;
  }
  if (bugListItems.length === 0) {
    container.innerHTML = `
      <div class="bug-list-empty">
        <p>No bugs or todos yet</p>
        <button class="bug-add-btn" onclick="addBugItem()">+ Add First Item</button>
      </div>
    `;
    return;
  }
  container.innerHTML = `
    <div class="bug-list-header">
      <h4>Bugs & Todos (${bugListItems.length})</h4>
      <button class="bug-add-btn" onclick="addBugItem()">+ Add</button>
      <button class="bug-execute-btn" onclick="executeBugList()" ${bugListItems.length === 0 ? 'disabled' : ''}>
        Execute with Planner
      </button>
    </div>
    <div class="bug-list-items">
      ${bugListItems.map((item, idx) => renderBugItem(item, idx)).join('')}
    </div>
  `;
}

