// Conversation Viewer - Core Module
// State and modal management
let conversationViewerOpen = false;
let conversationLiveStream = null;
// Open conversation viewer modal
async function openConversationViewer(projectId, taskId, isLive = false) {
  conversationViewerOpen = true;
  // Create modal if not exists
  let modal = document.getElementById('conversationModal');
  if (!modal) {
    modal = document.createElement('div');
    modal.id = 'conversationModal';
    modal.className = 'conversation-modal';
    document.body.appendChild(modal);
  }
  // Show loading state
  modal.innerHTML = `
    <div class="conversation-modal-content">
      <div class="conversation-header">
        <h3>Conversation: ${taskId}</h3>
        <button class="conversation-close" onclick="closeConversationViewer()">×</button>
      </div>
      <div class="conversation-body">
        <div class="conversation-loading">Loading conversation...</div>
      </div>
    </div>
  `;
  modal.style.display = 'block';
  // Fetch task info and conversation
  try {
    const sessionRes = await fetch(`${API_BASE}/project/${projectId}/task/${taskId}/session`);
    const session = await sessionRes.json();
    const convRes = await fetch(`${API_BASE}/project/${projectId}/task/${taskId}/conversation`);
    const messages = await convRes.json();
    renderConversationContent(session, messages, isLive, projectId, taskId);
    // If live mode, start SSE stream
    if (isLive && session.executor_status === 'running') {
      startConversationLiveStream(projectId, taskId);
    }
  } catch (e) {
    modal.querySelector('.conversation-body').innerHTML = `
      <div class="conversation-error">Failed to load conversation: ${e.message}</div>
    `;
  }
}
// Close conversation viewer
function closeConversationViewer() {
  conversationViewerOpen = false;
  const modal = document.getElementById('conversationModal');
  if (modal) {
    modal.style.display = 'none';
  }
  if (conversationLiveStream) {
    conversationLiveStream.close();
    conversationLiveStream = null;
  }
}
// Calculate duration between two timestamps
function calculateDuration(start, end) {
  const startDate = new Date(start);
  const endDate = end ? new Date(end) : new Date();
  const diff = endDate - startDate;
  const hours = Math.floor(diff / 3600000);
  const minutes = Math.floor((diff % 3600000) / 60000);
  const seconds = Math.floor((diff % 60000) / 1000);
  if (hours > 0) return `${hours}h ${minutes}m`;
  if (minutes > 0) return `${minutes}m ${seconds}s`;
  return `${seconds}s`;
}

