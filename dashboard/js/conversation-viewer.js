// Conversation Viewer Modal - Real-time Conversation Logs

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

// Render conversation content
function renderConversationContent(session, messages, isLive, projectId, taskId) {
  const modal = document.getElementById('conversationModal');
  if (!modal) return;

  const stats = {
    messageCount: messages.length,
    toolCalls: messages.filter(m => m.role === 'tool').length,
    totalTokens: 0, // TODO: sum from metadata
    duration: session.executor_started_at ? calculateDuration(session.executor_started_at, session.executor_last_activity) : null
  };

  const html = `
    <div class="conversation-modal-content">
      <div class="conversation-header">
        <div class="conversation-header-left">
          <h3>${session.task_id}: ${session.title}</h3>
          <span class="conversation-status ${session.status}">${session.status}</span>
          ${isLive && session.executor_status === 'running' ? '<span class="live-badge">● LIVE</span>' : ''}
        </div>
        <button class="conversation-close" onclick="closeConversationViewer()">×</button>
      </div>

      <div class="conversation-stats">
        <div class="stat-item">
          <span class="stat-label">Messages</span>
          <span class="stat-value">${stats.messageCount}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Tool Calls</span>
          <span class="stat-value">${stats.toolCalls}</span>
        </div>
        ${stats.duration ? `
          <div class="stat-item">
            <span class="stat-label">Duration</span>
            <span class="stat-value">${stats.duration}</span>
          </div>
        ` : ''}
        ${session.conversation_summary?.total_tokens ? `
          <div class="stat-item">
            <span class="stat-label">Tokens</span>
            <span class="stat-value">${session.conversation_summary.total_tokens.toLocaleString()}</span>
          </div>
        ` : ''}
      </div>

      <div class="conversation-actions">
        <button class="conversation-action-btn" onclick="exportConversation('${projectId}', '${taskId}')">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
            <polyline points="7 10 12 15 17 10"></polyline>
            <line x1="12" y1="15" x2="12" y2="3"></line>
          </svg>
          Export to Markdown
        </button>
        ${!isLive && session.executor_status === 'running' ? `
          <button class="conversation-action-btn primary" onclick="closeConversationViewer(); watchTaskLive('${projectId}', '${taskId}')">
            Switch to Live Mode
          </button>
        ` : ''}
      </div>

      <div class="conversation-body" id="conversationBody">
        ${renderConversationMessages(messages)}
      </div>
    </div>
  `;

  modal.innerHTML = html;

  // Auto-scroll to bottom
  setTimeout(() => {
    const body = document.getElementById('conversationBody');
    if (body) body.scrollTop = body.scrollHeight;
  }, 100);
}

// Render conversation messages
function renderConversationMessages(messages) {
  if (messages.length === 0) {
    return '<div class="conversation-empty">No messages yet</div>';
  }

  return messages.map(msg => {
    const time = new Date(msg.timestamp).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit', second: '2-digit' });

    if (msg.role === 'tool') {
      return renderToolMessage(msg, time);
    } else {
      return renderTextMessage(msg, time);
    }
  }).join('');
}

// Render text message (user/assistant/system)
function renderTextMessage(msg, time) {
  const roleClass = msg.role === 'user' ? 'msg-user' : msg.role === 'assistant' ? 'msg-assistant' : 'msg-system';
  const roleLabel = msg.role.charAt(0).toUpperCase() + msg.role.slice(1);

  return `
    <div class="conversation-message ${roleClass}">
      <div class="msg-header">
        <span class="msg-role">${roleLabel}</span>
        <span class="msg-time">${time}</span>
      </div>
      <div class="msg-content">${escapeHtml(msg.content || '')}</div>
    </div>
  `;
}

// Render tool call message
function renderToolMessage(msg, time) {
  const toolId = `tool-${msg.id}`;
  const isExpanded = false; // Default collapsed

  let input = msg.tool_input;
  let output = msg.tool_output;

  // Try to parse JSON for pretty display
  try {
    if (input && typeof input === 'string') input = JSON.parse(input);
    if (output && typeof output === 'string') output = JSON.parse(output);
  } catch (e) {
    // Keep as string if not JSON
  }

  const inputStr = typeof input === 'object' ? JSON.stringify(input, null, 2) : String(input || '');
  const outputStr = typeof output === 'object' ? JSON.stringify(output, null, 2) : String(output || '');

  return `
    <div class="conversation-message msg-tool">
      <div class="msg-header" onclick="toggleToolMessage('${toolId}')">
        <span class="msg-role">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path>
          </svg>
          Tool: ${msg.tool_name}
        </span>
        <span class="msg-time">${time}</span>
        <span class="tool-expand-icon">${isExpanded ? '▼' : '▶'}</span>
      </div>
      <div class="tool-details" id="${toolId}" style="display:${isExpanded ? 'block' : 'none'};">
        ${inputStr ? `
          <div class="tool-section">
            <div class="tool-section-label">Input:</div>
            <pre class="tool-code">${escapeHtml(inputStr)}</pre>
          </div>
        ` : ''}
        ${outputStr ? `
          <div class="tool-section">
            <div class="tool-section-label">Output:</div>
            <pre class="tool-code">${escapeHtml(outputStr)}</pre>
          </div>
        ` : ''}
      </div>
    </div>
  `;
}

// Toggle tool message expansion
function toggleToolMessage(toolId) {
  const details = document.getElementById(toolId);
  if (!details) return;

  const isVisible = details.style.display !== 'none';
  details.style.display = isVisible ? 'none' : 'block';

  // Update icon
  const header = details.previousElementSibling;
  const icon = header?.querySelector('.tool-expand-icon');
  if (icon) icon.textContent = isVisible ? '▶' : '▼';
}

// Start SSE live stream
function startConversationLiveStream(projectId, taskId) {
  if (conversationLiveStream) {
    conversationLiveStream.close();
  }

  const url = `${API_BASE}/project/${projectId}/task/${taskId}/live`;
  conversationLiveStream = new EventSource(url);

  conversationLiveStream.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);

      if (data.type === 'message' && data.message) {
        appendLiveMessage(data.message);
      }
    } catch (e) {
      console.error('SSE parse error:', e);
    }
  };

  conversationLiveStream.onerror = (err) => {
    console.error('SSE error:', err);
    conversationLiveStream.close();
    conversationLiveStream = null;

    // Show disconnected message
    const body = document.getElementById('conversationBody');
    if (body) {
      const notice = document.createElement('div');
      notice.className = 'conversation-notice';
      notice.textContent = 'Live stream disconnected';
      body.appendChild(notice);
    }
  };
}

// Append live message to conversation
function appendLiveMessage(msg) {
  const body = document.getElementById('conversationBody');
  if (!body) return;

  const time = new Date(msg.timestamp).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  const html = msg.role === 'tool' ? renderToolMessage(msg, time) : renderTextMessage(msg, time);

  body.insertAdjacentHTML('beforeend', html);
  body.scrollTop = body.scrollHeight;
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

// Export conversation to markdown
async function exportConversation(projectId, taskId) {
  try {
    const convRes = await fetch(`${API_BASE}/project/${projectId}/task/${taskId}/conversation`);
    const messages = await convRes.json();

    let markdown = `# Conversation: ${taskId}\n\n`;
    markdown += `**Date**: ${new Date().toLocaleString('it-IT')}\n\n`;
    markdown += `---\n\n`;

    messages.forEach(msg => {
      const time = new Date(msg.timestamp).toLocaleTimeString('it-IT');
      markdown += `## [${time}] ${msg.role.toUpperCase()}\n\n`;

      if (msg.role === 'tool') {
        markdown += `**Tool**: ${msg.tool_name}\n\n`;
        if (msg.tool_input) {
          markdown += `**Input**:\n\`\`\`json\n${JSON.stringify(JSON.parse(msg.tool_input), null, 2)}\n\`\`\`\n\n`;
        }
        if (msg.tool_output) {
          markdown += `**Output**:\n\`\`\`\n${msg.tool_output}\n\`\`\`\n\n`;
        }
      } else {
        markdown += `${msg.content}\n\n`;
      }

      markdown += `---\n\n`;
    });

    // Download as file
    const blob = new Blob([markdown], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `conversation-${taskId}-${Date.now()}.md`;
    a.click();
    URL.revokeObjectURL(url);

    showToast('Conversation exported', 'success');
  } catch (e) {
    showToast('Export failed: ' + e.message, 'error');
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

// Escape HTML
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
