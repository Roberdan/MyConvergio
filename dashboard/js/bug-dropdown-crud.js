/**
 * Bug Dropdown - CRUD Module
 * Add, edit, delete, toggle operations
 */
BugDropdown.prototype.addBug = function() {
  const title = prompt('Enter bug title:');
  if (!title || !title.trim()) return;
  let priority = (prompt('Priority (p0/p1/p2):', 'p1') || 'p1').toLowerCase();
  if (!['p0', 'p1', 'p2'].includes(priority)) {
    this.showToast('Invalid priority. Using p1.', 'warning');
    priority = 'p1';
  }
  const bug = {
    id: `bug-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    title: title.trim(),
    priority,
    version: this.getAppVersion(),
    date: new Date().toISOString().split('T')[0],
    done: false,
    createdAt: new Date().toISOString()
  };
  this.bugs.push(bug);
  this.saveBugs();
  this.render();
  this.showToast(`Bug "${bug.title}" added`);
};
BugDropdown.prototype.editBug = function(id) {
  const bug = this.bugs.find(b => b.id === id);
  if (!bug) return;
  const newTitle = prompt('Edit bug title:', bug.title);
  if (newTitle && newTitle.trim()) {
    bug.title = newTitle.trim();
    this.saveBugs();
    this.render();
    this.showToast(`Bug updated`);
  }
};
BugDropdown.prototype.deleteBug = function(id) {
  const bug = this.bugs.find(b => b.id === id);
  if (!bug) return;
  if (!confirm(`Delete bug "${bug.title}"?`)) return;
  this.bugs = this.bugs.filter(b => b.id !== id);
  this.saveBugs();
  this.render();
  this.showToast(`Bug deleted`);
};
BugDropdown.prototype.toggleBugDone = function(id, done) {
  const bug = this.bugs.find(b => b.id === id);
  if (bug) {
    bug.done = done;
    this.saveBugs();
    this.render();
  }
};

