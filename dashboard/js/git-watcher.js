// Git Watcher - Real-time SSE connection for git changes

let gitWatcherConnection = null; // EventSource connection
let currentWatchedProjectId = null;

/**
 * Connect to SSE endpoint for git changes
 * @param {string} projectId - Project ID to watch
 */
function connectGitWatcher(projectId) {
  // Close existing connection if watching different project
  if (gitWatcherConnection && currentWatchedProjectId !== projectId) {
    disconnectGitWatcher();
  }

  // Already connected to this project
  if (currentWatchedProjectId === projectId && gitWatcherConnection) {
    return;
  }

  try {
    const url = `${API_BASE}/project/${projectId}/git/watch`;
    gitWatcherConnection = new EventSource(url);
    currentWatchedProjectId = projectId;

    gitWatcherConnection.onopen = () => {
    };

    gitWatcherConnection.onmessage = (event) => {
      const message = JSON.parse(event.data);

      if (message.type === 'connected') {
      } else if (message.type === 'git-change') {
        // Only refresh if still watching this project
        if (message.projectId === currentProjectId) {
          loadGitData();
        }
      }
    };

    gitWatcherConnection.onerror = (error) => {
      console.error('Git watcher error:', error);

      // EventSource automatically reconnects, but we log the error
      // If connection is closed, we'll reconnect when project is selected again
    };

  } catch (e) {
    console.error('Failed to connect git watcher:', e);
  }
}

/**
 * Disconnect from SSE endpoint
 */
function disconnectGitWatcher() {
  if (gitWatcherConnection) {
    gitWatcherConnection.close();
    gitWatcherConnection = null;
    currentWatchedProjectId = null;
  }
}

/**
 * Reconnect to git watcher (useful after network issues)
 */
function reconnectGitWatcher() {
  if (currentWatchedProjectId) {
    disconnectGitWatcher();
    connectGitWatcher(currentWatchedProjectId);
  }
}

// Auto-cleanup on page unload
window.addEventListener('beforeunload', () => {
  disconnectGitWatcher();
});
