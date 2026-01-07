/**
 * Bug Dropdown - Actions Module
 * Execute, copy, archive operations
 */
BugDropdown.prototype.executeWithPlanner = function(id) {
  const bug = this.bugs.find(b => b.id === id);
  if (!bug) return;
  const params = new URLSearchParams({
    bug: bug.id,
    title: bug.title,
    priority: bug.priority,
    version: bug.version
  });
  window.open(`planner.html?${params.toString()}`, '_blank');
};
BugDropdown.prototype.copyCLICommand = function(id) {
  const bug = this.bugs.find(b => b.id === id);
  if (!bug) return;
  const command = `plan-db.sh add-task "${bug.title.replace(/"/g, '\\"')}" --priority ${bug.priority.toUpperCase()} --version ${bug.version}`;
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(command)
      .then(() => this.showToast('CLI command copied to clipboard!'))
      .catch(() => this.fallbackCopyToClipboard(command));
  } else {
    this.fallbackCopyToClipboard(command);
  }
};
BugDropdown.prototype.fallbackCopyToClipboard = function(text) {
  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.style.position = 'fixed';
  textarea.style.opacity = '0';
  textarea.style.top = '0';
  textarea.style.left = '0';
  document.body.appendChild(textarea);
  textarea.select();
  try {
    document.execCommand('copy');
    this.showToast('CLI command copied to clipboard!');
  } catch (e) {
    Logger.error('Failed to copy to clipboard:', e);
    this.showToast('Failed to copy command', 'error');
  }
  document.body.removeChild(textarea);
};
BugDropdown.prototype.archiveCompleted = function() {
  const completed = this.bugs.filter(b => b.done);
  if (completed.length === 0) {
    this.showToast('No completed bugs to archive', 'warning');
    return;
  }
  if (!confirm(`Archive ${completed.length} completed bug(s)?`)) return;
  try {
    const archive = JSON.parse(localStorage.getItem('myconvergio-bugs-archive') || '[]');
    archive.push(...completed);
    localStorage.setItem('myconvergio-bugs-archive', JSON.stringify(archive));
    this.bugs = this.bugs.filter(b => !b.done);
    this.saveBugs();
    this.render();
    this.showToast(`${completed.length} bug(s) archived`);
  } catch (e) {
    Logger.error('Failed to archive bugs:', e);
    this.showToast('Failed to archive bugs', 'error');
  }
};

