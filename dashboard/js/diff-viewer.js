// Diff Viewer - VS Code Style File Diff Display

let currentDiffFile = null;

// Helper to encode file paths while preserving slashes
function encodeFilePath(filePath) {
  return filePath.split('/').map(encodeURIComponent).join('/');
}

async function openFileDiff(filePath) {
  if (!currentProjectId) {
    showToast('No project selected', 'warning');
    return;
  }

  currentDiffFile = filePath;

  // Show diff view, hide dashboard
  showDiffView(filePath);

  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/git/diff/${encodeFilePath(filePath)}`);
    const data = await res.json();

    if (data.error) {
      showToast(data.error, 'error');
      return;
    }

    renderDiff(data);
  } catch (e) {
    showToast('Failed to load diff: ' + e.message, 'error');
  }
}

function showDiffView(filePath) {
  // Hide main content areas
  document.querySelectorAll('.main-content > *').forEach(el => {
    el.style.display = 'none';
  });

  // Disable scroll on main-content to prevent competition
  const mainContent = document.querySelector('.main-content');
  if (mainContent) mainContent.style.overflow = 'hidden';

  // Create or show diff viewer
  let diffViewer = document.getElementById('diffViewer');
  if (!diffViewer) {
    diffViewer = document.createElement('div');
    diffViewer.id = 'diffViewer';
    diffViewer.className = 'diff-viewer';
    document.querySelector('.main-content').appendChild(diffViewer);
  }

  const fileName = filePath.split('/').pop();
  const ext = fileName.split('.').pop().toLowerCase();
  const isMarkdown = ext === 'md' || ext === 'markdown';
  const isImage = ['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'ico'].includes(ext);

  // Preview button for markdown/images
  const previewBtn = (isMarkdown || isImage) ? `
    <button class="diff-action-btn diff-preview-btn" onclick="toggleMarkdownPreview()" title="Toggle preview" id="previewToggleBtn">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
        <circle cx="12" cy="12" r="3"></circle>
      </svg>
    </button>
  ` : '';

  diffViewer.innerHTML = `
    <div class="diff-header">
      <button class="diff-back" onclick="closeDiffView()">&#x2190; Back to Dashboard</button>
      <div class="diff-file-info">
        <span class="diff-file-icon">${getFileIcon(fileName)}</span>
        <span class="diff-file-path">${filePath}</span>
      </div>
      <div class="diff-actions">
        ${previewBtn}
        <button class="diff-action-btn" onclick="openFileExternally('${filePath}')" title="Open in editor">Edit</button>
        <button class="diff-action-btn" onclick="stageFile('${filePath}')" title="Stage file">+ Stage</button>
        <button class="diff-action-btn" onclick="discardFile('${filePath}')" title="Discard changes">Discard</button>
      </div>
    </div>
    <div class="diff-content" id="diffContent">
      <div class="diff-loading">Loading diff...</div>
    </div>
  `;
  diffViewer.style.display = 'block';
}

function closeDiffView() {
  currentDiffFile = null;

  const diffViewer = document.getElementById('diffViewer');
  if (diffViewer) diffViewer.style.display = 'none';

  // Restore scroll on main-content
  const mainContent = document.querySelector('.main-content');
  if (mainContent) mainContent.style.overflow = '';

  // Restore main content
  document.querySelectorAll('.main-content > *').forEach(el => {
    if (el.id !== 'diffViewer') {
      el.style.display = '';
    }
  });

  // Don't call showView here - it creates a recursive loop
  // showView already handles the diff viewer cleanup
}

function renderDiff(data) {
  const container = document.getElementById('diffContent');
  if (!container) return;

  // Handle image files
  const imageExts = ['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'ico'];
  if (imageExts.includes(data.extension)) {
    renderImagePreview(container, data.path);
    return;
  }

  // Handle markdown files
  if (data.language === 'markdown') {
    renderMarkdownWithDiff(container, data);
    return;
  }

  // Handle new files (no diff)
  if (data.isNew && data.content) {
    renderNewFile(container, data.content, data.language);
    return;
  }

  // Handle diff
  if (data.diff) {
    renderGitDiff(container, data.diff, data.language);
    return;
  }

  container.innerHTML = '<div class="diff-empty">No changes to display</div>';
}

function renderImagePreview(container, filePath) {
  const imgUrl = `${API_BASE}/project/${currentProjectId}/file-raw/${encodeFilePath(filePath)}`;
  container.innerHTML = `
    <div class="diff-image-preview">
      <img src="${imgUrl}" alt="${filePath}" onerror="this.src=''; this.alt='Failed to load image';" />
    </div>
  `;
}

async function openFileExternally(filePath) {
  if (!currentProjectId) return;
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/file/open`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ path: filePath })
    });
    const result = await res.json();
    if (!result.success) showToast(result.error || 'Failed to open file', 'error');
    else startFileWatcher(filePath); // Start watching for changes
  } catch (e) {
    showToast('Failed to open file: ' + e.message, 'error');
  }
}

// File watcher for auto-refresh when file is modified externally
let fileWatchInterval = null;
let lastFileModTime = null;

function startFileWatcher(filePath) {
  stopFileWatcher();
  lastFileModTime = Date.now();
  fileWatchInterval = setInterval(() => checkFileChanged(filePath), 2000);
}

function stopFileWatcher() {
  if (fileWatchInterval) {
    clearInterval(fileWatchInterval);
    fileWatchInterval = null;
  }
}

async function checkFileChanged(filePath) {
  if (!currentProjectId || !currentDiffFile) {
    stopFileWatcher();
    return;
  }
  try {
    const res = await fetch(`${API_BASE}/project/${currentProjectId}/file/mtime/${encodeFilePath(filePath)}`);
    const result = await res.json();
    if (result.mtime && result.mtime > lastFileModTime) {
      lastFileModTime = result.mtime;
      showToast('File changed, refreshing...', 'info');
      openFileDiff(filePath); // Reload the diff
    }
  } catch (e) {
    Logger.debug('File watcher error (non-critical):', e);
  }
}

function renderGitDiff(container, diff, language) {
  const lines = diff.split('\n');
  let html = '<div class="diff-lines">';
  let oldLineNum = 0;
  let newLineNum = 0;
  let inHunk = false;

  lines.forEach((line, i) => {
    // Parse hunk header @@ -a,b +c,d @@
    const hunkMatch = line.match(/^@@ -(\d+),?\d* \+(\d+),?\d* @@/);
    if (hunkMatch) {
      oldLineNum = parseInt(hunkMatch[1]) - 1;
      newLineNum = parseInt(hunkMatch[2]) - 1;
      inHunk = true;
      html += `<div class="diff-line hunk"><span class="diff-gutter">...</span><span class="diff-gutter">...</span><span class="diff-text">${escapeHtml(line)}</span></div>`;
      return;
    }

    // Skip diff headers
    if (line.startsWith('diff --git') || line.startsWith('index ') ||
        line.startsWith('---') || line.startsWith('+++') || line.startsWith('\\')) {
      return;
    }

    if (!inHunk) return;

    const type = line.startsWith('+') ? 'add' : line.startsWith('-') ? 'del' : 'ctx';
    const content = line.substring(1);

    if (type === 'add') {
      newLineNum++;
      html += `<div class="diff-line ${type}"><span class="diff-gutter"></span><span class="diff-gutter">${newLineNum}</span><span class="diff-text">${highlightLine(content, language)}</span></div>`;
    } else if (type === 'del') {
      oldLineNum++;
      html += `<div class="diff-line ${type}"><span class="diff-gutter">${oldLineNum}</span><span class="diff-gutter"></span><span class="diff-text">${highlightLine(content, language)}</span></div>`;
    } else {
      oldLineNum++;
      newLineNum++;
      html += `<div class="diff-line ${type}"><span class="diff-gutter">${oldLineNum}</span><span class="diff-gutter">${newLineNum}</span><span class="diff-text">${highlightLine(content, language)}</span></div>`;
    }
  });

  html += '</div>';
  container.innerHTML = html;
}

function renderNewFile(container, content, language) {
  const lines = content.split('\n');
  let html = '<div class="diff-lines new-file">';
  html += '<div class="diff-line hunk"><span class="diff-gutter">+</span><span class="diff-gutter"></span><span class="diff-text">New file</span></div>';

  lines.forEach((line, i) => {
    html += `<div class="diff-line add"><span class="diff-gutter"></span><span class="diff-gutter">${i + 1}</span><span class="diff-text">${highlightLine(line, language)}</span></div>`;
  });

  html += '</div>';
  container.innerHTML = html;
}

// Markdown with Diff - Full-width toggle between code and preview
let markdownPreviewVisible = false;
let cachedMarkdownHtml = '';
let cachedDiffHtml = '';

function renderMarkdownWithDiff(container, data) {
  const content = data.content || '';
  const diff = data.diff || '';

  // Convert markdown to HTML and cache it
  cachedMarkdownHtml = markdownToHtml(content);

  // Build diff HTML if there's a diff
  if (diff) {
    cachedDiffHtml = buildDiffHtml(diff, 'markdown');
  } else if (data.isNew) {
    cachedDiffHtml = buildNewFileHtml(content);
  } else {
    cachedDiffHtml = '<div class="diff-empty">No diff available</div>';
  }

  // Show only code/diff by default (full width)
  markdownPreviewVisible = false;
  container.innerHTML = `
    <div class="diff-markdown-container" id="diffMarkdownContainer">
      <div class="diff-pane-full" id="diffPane">
        ${cachedDiffHtml}
      </div>
      <div class="diff-preview-pane" id="previewPane" style="display: none;">
        <div class="diff-pane-content markdown-body">
          ${cachedMarkdownHtml}
        </div>
      </div>
    </div>
  `;
  updatePreviewButton();
}

function toggleMarkdownPreview() {
  markdownPreviewVisible = !markdownPreviewVisible;
  const diffPane = document.getElementById('diffPane');
  const previewPane = document.getElementById('previewPane');

  if (!diffPane || !previewPane) return;

  // Full-width toggle: show one OR the other, never both
  if (markdownPreviewVisible) {
    diffPane.style.display = 'none';
    previewPane.style.display = 'block';
  } else {
    diffPane.style.display = 'block';
    previewPane.style.display = 'none';
  }
  updatePreviewButton();
}

function updatePreviewButton() {
  const btn = document.getElementById('previewToggleBtn');
  if (btn) {
    btn.classList.toggle('active', markdownPreviewVisible);
  }
}
