// Git Panel (Left Sidebar) - VS Code Style

function toggleGitPanel() {
  const panel = document.getElementById('gitPanel');
  if (panel) {
    if (window.innerWidth < 1200) {
      panel.classList.toggle('visible');
    } else {
      panel.classList.toggle('collapsed');
      localStorage.setItem('git-panel-collapsed', panel.classList.contains('collapsed'));
    }
  }
}

function toggleGitSection(section) {
  const sectionEl = document.querySelector(`.git-section[data-section="${section}"]`) ||
    document.getElementById('git' + section.charAt(0).toUpperCase() + section.slice(1))?.closest('.git-section');
  if (sectionEl) {
    sectionEl.classList.toggle('collapsed');
    localStorage.setItem(`git-section-${section}`, sectionEl.classList.contains('collapsed'));
  }
}

function toggleTreeFolder(el) {
  const folder = el.closest('.git-tree-folder');
  if (folder) {
    folder.classList.toggle('collapsed');
  }
}

// Build tree structure from flat file list
function buildFileTree(files) {
  const tree = {};
  files.forEach(file => {
    const path = typeof file === 'string' ? file : file.path;
    const status = typeof file === 'string' ? 'U' : file.status;
    const parts = path.split('/');
    let current = tree;
    parts.forEach((part, i) => {
      if (i === parts.length - 1) {
        if (!current._files) current._files = [];
        current._files.push({ name: part, path, status });
      } else {
        if (!current[part]) current[part] = {};
        current = current[part];
      }
    });
  });
  return tree;
}

// Render tree recursively
function renderTreeNode(tree, depth = 0, parentPath = '') {
  let html = '';
  const folders = Object.keys(tree).filter(k => k !== '_files').sort();
  const files = tree._files || [];

  folders.forEach(folder => {
    const folderPath = parentPath ? `${parentPath}/${folder}` : folder;
    const fileCount = countFilesInTree(tree[folder]);
    html += `
      <div class="git-tree-folder" data-path="${folderPath}">
        <div class="git-tree-folder-header" onclick="toggleTreeFolder(this)">
          <span class="git-tree-arrow">&#x25BC;</span>
          <span class="git-tree-folder-icon">&#x1F4C1;</span>
          <span class="git-tree-folder-name">${folder}</span>
          <span class="git-tree-folder-count">${fileCount}</span>
        </div>
        <div class="git-tree-folder-content">
          ${renderTreeNode(tree[folder], depth + 1, folderPath)}
        </div>
      </div>`;
  });

  files.forEach(file => {
    const icon = getFileIcon(file.name);
    html += `
      <div class="git-tree-file" title="${file.path}" onclick="openFileDiff('${file.path}')">
        <span class="git-tree-file-icon">${icon}</span>
        <span class="git-tree-file-name">${file.name}</span>
        <span class="git-tree-file-status ${file.status}">${file.status}</span>
        <div class="git-tree-file-actions">
          <button class="git-tree-action" onclick="event.stopPropagation(); stageFile('${file.path}')" title="Stage">+</button>
          <button class="git-tree-action" onclick="event.stopPropagation(); discardFile('${file.path}')" title="Discard">&#x21BA;</button>
        </div>
      </div>`;
  });
  return html;
}

function countFilesInTree(tree) {
  let count = (tree._files || []).length;
  Object.keys(tree).filter(k => k !== '_files').forEach(k => {
    count += countFilesInTree(tree[k]);
  });
  return count;
}

// getFileIcon is now defined in file-icons.js

function renderGitPanel() {
  if (!data.git) return;
  const git = data.git;

  // Update repo info
  const repoName = document.getElementById('gitRepoName');
  const branchName = document.getElementById('gitCurrentBranchName');
  const dirtyIndicator = document.getElementById('gitBranchDirty');

  if (repoName) repoName.textContent = data.project?.name || 'Project';
  if (branchName) branchName.textContent = git.currentBranch || 'main';

  const uncommitted = git.uncommitted || { staged: [], unstaged: [], untracked: [] };
  const totalChanges = (uncommitted.staged?.length || 0) + (uncommitted.unstaged?.length || 0) + (uncommitted.untracked?.length || 0);

  if (dirtyIndicator) dirtyIndicator.style.display = totalChanges > 0 ? '' : 'none';

  const changesCount = document.getElementById('gitChangesCount');
  if (changesCount) changesCount.textContent = totalChanges;

  // Build combined file tree
  const allFiles = [
    ...(uncommitted.staged || []).map(f => ({ ...f, staged: true })),
    ...(uncommitted.unstaged || []),
    ...(uncommitted.untracked || []).map(f => ({ path: f, status: 'U' }))
  ];

  const fileTree = document.getElementById('gitFileTree');
  if (fileTree) {
    if (allFiles.length === 0) {
      fileTree.innerHTML = '<div class="git-empty">No changes</div>';
    } else {
      const tree = buildFileTree(allFiles);
      fileTree.innerHTML = renderTreeNode(tree);
    }
  }

  renderGitHistory();
}

function renderGitHistory() {
  const graphContainer = document.getElementById('gitGraphContainer');
  if (!graphContainer || !data.git?.commits) return;

  const commits = data.git.commits.slice(0, 15);
  graphContainer.innerHTML = commits.map((c, i) => `
    <div class="git-commit-item" title="${c.message}">
      <div class="git-commit-graph">
        <div class="git-commit-dot"></div>
        ${i < commits.length - 1 ? '<div class="git-commit-line"></div>' : ''}
      </div>
      <div class="git-commit-info">
        <span class="git-commit-hash">${c.hash}</span>
        <span class="git-commit-message">${c.message?.substring(0, 40) || ''}${c.message?.length > 40 ? '...' : ''}</span>
      </div>
      <span class="git-commit-date">${c.date}</span>
    </div>
  `).join('') || '<div class="git-empty">No commits</div>';
}
