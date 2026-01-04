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
    const folderIcon = getFolderIcon(folder);
    html += `
      <div class="git-tree-folder" data-path="${folderPath}">
        <div class="git-tree-folder-header" onclick="toggleTreeFolder(this)">
          <span class="git-tree-arrow">
            <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
          </span>
          <span class="git-tree-folder-icon">${folderIcon}</span>
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

  if (repoName) repoName.textContent = data.meta?.project || 'Project';
  if (branchName) branchName.textContent = git.currentBranch || 'main';

  // Update repo avatar from GitHub
  const avatarEl = document.getElementById('gitRepoAvatar');
  const iconFallback = document.getElementById('gitRepoIconFallback');
  if (avatarEl && data.github?.repo) {
    const owner = data.github.repo.split('/')[0];
    if (owner) {
      avatarEl.src = `https://github.com/${owner}.png?size=40`;
      avatarEl.alt = owner;
      avatarEl.style.display = 'block';
      avatarEl.onerror = () => {
        avatarEl.style.display = 'none';
        if (iconFallback) iconFallback.style.display = 'block';
      };
      if (iconFallback) iconFallback.style.display = 'none';
    }
  }

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

// Git graph lazy loading state
let gitGraphState = {
  commits: [],
  hasMore: true,
  loading: false,
  skip: 0,
  limit: 30,
  showAllBranches: false
};

function renderGitHistory() {
  const graphContainer = document.getElementById('gitGraphContainer');
  if (!graphContainer) return;

  // Initialize with commits from data.git if available
  if (data.git?.commits && gitGraphState.commits.length === 0) {
    gitGraphState.commits = data.git.commits;
    gitGraphState.skip = data.git.commits.length;
  }

  renderCommitGraph(graphContainer);
  setupGraphScrollListener(graphContainer);
}

function renderCommitGraph(container) {
  const commits = gitGraphState.commits;
  if (commits.length === 0) {
    container.innerHTML = '<div class="git-empty">No commits</div>';
    return;
  }

  container.innerHTML = commits.map((c, i) => {
    const isMerge = c.isMerge || false;
    const dotClass = isMerge ? 'git-graph-dot merge' : 'git-graph-dot';
    const rowClass = isMerge ? 'git-commit-row merge' : 'git-commit-row';
    const showConnector = i < commits.length - 1 || gitGraphState.hasMore;

    // Branch labels
    const branchLabels = (c.branches || []).concat(c.refs || [])
      .filter(b => b && !b.includes('HEAD'))
      .slice(0, 2)
      .map(b => {
        const isRemote = b.includes('origin/');
        const shortName = b.replace('origin/', '');
        return `<span class="git-branch-label ${isRemote ? 'remote' : 'local'}">${escapeHtml(shortName)}</span>`;
      }).join('');

    return `
      <div class="${rowClass}" title="${escapeHtml(c.message || '')}" onclick="openCommitDetails('${c.fullHash || c.hash}')">
        <div class="git-graph-line">
          <div class="${dotClass}"></div>
          ${showConnector ? '<div class="git-graph-connector"></div>' : ''}
        </div>
        <div class="git-commit-info">
          <span class="git-commit-hash">${c.hash}</span>
          ${branchLabels}
          <span class="git-commit-message">${escapeHtml((c.message || '').substring(0, 30))}${(c.message || '').length > 30 ? '...' : ''}</span>
        </div>
        <div class="git-commit-meta">
          <span class="git-commit-date">${c.date || ''}</span>
        </div>
      </div>`;
  }).join('');

  if (gitGraphState.loading) {
    container.innerHTML += '<div class="git-loading">Loading...</div>';
  }
}

// Commit details state
let currentCommitSha = null;

async function openCommitDetails(sha) {
  if (!currentProjectId) {
    showToast('No project selected', 'warning');
    return;
  }

  currentCommitSha = sha;

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/commit/${sha}`);
    const data = await res.json();

    if (data.error) {
      showToast(data.error, 'error');
      return;
    }

    showCommitDetailsView(data.commit, data.files);
  } catch (e) {
    showToast('Failed to load commit: ' + e.message, 'error');
  }
}

function showCommitDetailsView(commit, files) {
  // Hide main content areas
  document.querySelectorAll('.main-content > *').forEach(el => {
    el.style.display = 'none';
  });

  // Create or show commit viewer
  let commitViewer = document.getElementById('commitViewer');
  if (!commitViewer) {
    commitViewer = document.createElement('div');
    commitViewer.id = 'commitViewer';
    commitViewer.className = 'commit-viewer';
    document.querySelector('.main-content').appendChild(commitViewer);
  }

  const statsHtml = `+${commit.insertions} -${commit.deletions}`;
  const tree = buildFileTree(files);

  commitViewer.innerHTML = `
    <div class="commit-header">
      <button class="diff-back" onclick="closeCommitDetails()">&#x2190; Back</button>
      <div class="commit-info">
        <span class="commit-hash-badge">${commit.shortHash}</span>
        <span class="commit-subject">${escapeHtml(commit.subject)}</span>
      </div>
      <div class="commit-stats">
        <span class="commit-stat additions">+${commit.insertions}</span>
        <span class="commit-stat deletions">-${commit.deletions}</span>
      </div>
    </div>
    <div class="commit-details-panel">
      <div class="commit-meta-card">
        <div class="commit-meta-row">
          <span class="commit-meta-label">Author</span>
          <span class="commit-meta-value">${escapeHtml(commit.author)} &lt;${escapeHtml(commit.email)}&gt;</span>
        </div>
        <div class="commit-meta-row">
          <span class="commit-meta-label">Date</span>
          <span class="commit-meta-value">${commit.date}</span>
        </div>
        <div class="commit-meta-row">
          <span class="commit-meta-label">Commit</span>
          <span class="commit-meta-value commit-full-hash">${commit.hash}</span>
        </div>
        ${commit.body ? `<div class="commit-body">${escapeHtml(commit.body)}</div>` : ''}
      </div>
      <div class="commit-files-panel">
        <div class="commit-files-header">
          <span>Changed Files</span>
          <span class="commit-files-count">${files.length} file${files.length !== 1 ? 's' : ''}</span>
        </div>
        <div class="commit-files-tree" id="commitFilesTree">
          ${renderCommitFileTree(tree, commit.hash)}
        </div>
      </div>
    </div>
    <div class="commit-diff-container" id="commitDiffContainer">
      <div class="commit-diff-placeholder">Select a file to view changes</div>
    </div>
  `;

  commitViewer.style.display = 'flex';
}

function renderCommitFileTree(tree, commitHash, parentPath = '') {
  let html = '';
  const folders = Object.keys(tree).filter(k => k !== '_files').sort();
  const files = tree._files || [];

  folders.forEach(folder => {
    const folderPath = parentPath ? `${parentPath}/${folder}` : folder;
    const fileCount = countFilesInTree(tree[folder]);
    const folderIcon = getFolderIcon(folder);
    html += `
      <div class="git-tree-folder">
        <div class="git-tree-folder-header" onclick="toggleTreeFolder(this)">
          <span class="git-tree-arrow">
            <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
          </span>
          <span class="git-tree-folder-icon">${folderIcon}</span>
          <span class="git-tree-folder-name">${folder}</span>
          <span class="git-tree-folder-count">${fileCount}</span>
        </div>
        <div class="git-tree-folder-content">
          ${renderCommitFileTree(tree[folder], commitHash, folderPath)}
        </div>
      </div>`;
  });

  files.forEach(file => {
    const icon = getFileIcon(file.name);
    const statusClass = file.status === 'A' ? 'added' : file.status === 'D' ? 'deleted' : 'modified';
    html += `
      <div class="git-tree-file commit-file" onclick="openCommitFileDiff('${currentCommitSha}', '${file.path}')" title="${file.path}">
        <span class="git-tree-file-icon">${icon}</span>
        <span class="git-tree-file-name">${file.name}</span>
        <span class="git-tree-file-status ${statusClass}">${file.status}</span>
      </div>`;
  });

  return html;
}

async function openCommitFileDiff(sha, filePath) {
  if (!currentProjectId) return;

  const container = document.getElementById('commitDiffContainer');
  if (!container) return;

  container.innerHTML = '<div class="commit-diff-loading">Loading diff...</div>';

  try {
    const encodedPath = filePath.split('/').map(encodeURIComponent).join('/');
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/commit/${sha}/diff/${encodedPath}`);
    const data = await res.json();

    if (data.error) {
      container.innerHTML = `<div class="commit-diff-error">${data.error}</div>`;
      return;
    }

    renderCommitDiff(container, data);
  } catch (e) {
    container.innerHTML = `<div class="commit-diff-error">Error: ${e.message}</div>`;
  }
}

function renderCommitDiff(container, data) {
  const fileName = data.path.split('/').pop();
  const icon = getFileIcon(fileName);

  let diffHtml = '';
  if (data.diff) {
    diffHtml = buildDiffHtml(data.diff, data.language);
  } else {
    diffHtml = '<div class="diff-empty">No changes in this file</div>';
  }

  container.innerHTML = `
    <div class="commit-diff-header">
      <div class="commit-diff-file">
        <span class="commit-diff-file-icon">${icon}</span>
        <span class="commit-diff-file-path">${data.path}</span>
      </div>
      <div class="commit-diff-commit-info">
        <span class="commit-diff-hash">${data.commit.shortHash}</span>
        <span class="commit-diff-subject">${escapeHtml(data.commit.subject)}</span>
      </div>
    </div>
    <div class="commit-diff-content">
      ${diffHtml}
    </div>
  `;
}

function closeCommitDetails() {
  currentCommitSha = null;

  const commitViewer = document.getElementById('commitViewer');
  if (commitViewer) commitViewer.style.display = 'none';

  // Restore main content
  document.querySelectorAll('.main-content > *').forEach(el => {
    if (el.id !== 'commitViewer' && el.id !== 'diffViewer') {
      el.style.display = '';
    }
  });
}

function toggleAllBranches() {
  gitGraphState.showAllBranches = !gitGraphState.showAllBranches;
  gitGraphState.commits = [];
  gitGraphState.skip = 0;
  gitGraphState.hasMore = true;

  const btn = document.getElementById('gitShowAllBranches');
  if (btn) btn.classList.toggle('active', gitGraphState.showAllBranches);

  loadMoreCommits();
}

function setupGraphScrollListener(container) {
  const scrollContainer = container.closest('.git-graph-content') || container;

  scrollContainer.removeEventListener('scroll', handleGraphScroll);
  scrollContainer.addEventListener('scroll', handleGraphScroll);
}

function handleGraphScroll(e) {
  const container = e.target;
  const nearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 100;

  if (nearBottom && gitGraphState.hasMore && !gitGraphState.loading) {
    loadMoreCommits();
  }
}

async function loadMoreCommits() {
  if (!currentProjectId || gitGraphState.loading || !gitGraphState.hasMore) return;

  gitGraphState.loading = true;
  const graphContainer = document.getElementById('gitGraphContainer');

  try {
    const allParam = gitGraphState.showAllBranches ? '&all=true' : '';
    const res = await fetch(
      `${API_BASE}/project/${currentProjectId}/git/commits?skip=${gitGraphState.skip}&limit=${gitGraphState.limit}${allParam}`
    );
    const result = await res.json();

    if (result.error) {
      console.log('Failed to load commits:', result.error);
      gitGraphState.hasMore = false;
    } else {
      gitGraphState.commits = [...gitGraphState.commits, ...result.commits];
      gitGraphState.skip += result.commits.length;
      gitGraphState.hasMore = result.hasMore;
    }
  } catch (e) {
    console.error('Error loading commits:', e);
    gitGraphState.hasMore = false;
  }

  gitGraphState.loading = false;
  if (graphContainer) renderCommitGraph(graphContainer);
}

function resetGitGraphState() {
  gitGraphState = { commits: [], hasMore: true, loading: false, skip: 0, limit: 30 };
}

function escapeHtml(text) {
  if (!text) return '';
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
