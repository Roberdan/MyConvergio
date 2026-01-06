// Simplified Navigation Functions

// Settings Menu Toggle
function toggleSettingsMenu() {
  const dropdown = document.getElementById('settingsDropdown');
  const isVisible = dropdown.style.display !== 'none';
  dropdown.style.display = isVisible ? 'none' : 'block';
}

// Close settings menu when clicking outside
document.addEventListener('click', (e) => {
  const settingsWrapper = document.querySelector('.settings-menu-wrapper');
  if (settingsWrapper && !settingsWrapper.contains(e.target)) {
    const dropdown = document.getElementById('settingsDropdown');
    if (dropdown) {
      dropdown.style.display = 'none';
    }
  }
});

// Theme Switcher
function switchTheme(theme) {
  // Use existing setTheme function if available
  if (typeof setTheme === 'function') {
    setTheme(theme);
  } else {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('dashboard-theme', theme);
  }
  showToast(`Theme changed to ${theme}`, 'success');
}

// Export Data
function exportData() {
  showToast('Exporting data...', 'info');
  
  // Export current project data
  if (!currentProjectId) {
    showToast('No project selected', 'warning');
    return;
  }
  
  fetch(`/api/export/project/${currentProjectId}`)
    .then(res => res.json())
    .then(data => {
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `project-${currentProjectId}-${Date.now()}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      showToast('Data exported successfully', 'success');
    })
    .catch(err => {
      console.error('Export failed:', err);
      showToast('Export failed', 'error');
    });
}

// Shutdown Dashboard
function shutdownDashboard() {
  if (!confirm('Are you sure you want to shutdown the dashboard server?')) {
    return;
  }
  
  showToast('Shutting down...', 'info');
  
  fetch('/api/shutdown', { method: 'POST' })
    .then(() => {
      showToast('Dashboard is shutting down', 'success');
      setTimeout(() => {
        window.close();
      }, 2000);
    })
    .catch(err => {
      console.error('Shutdown failed:', err);
      showToast('Shutdown failed', 'error');
    });
}

// Refresh Control Center
function refreshControlCenter() {
  showToast('Refreshing...', 'info');
  
  if (currentView === 'kanban' && typeof loadKanban === 'function') {
    loadKanban().then(() => {
      showToast('Control Center refreshed', 'success');
    }).catch(err => {
      console.error('Refresh failed:', err);
      showToast('Refresh failed', 'error');
    });
  } else if (currentView === 'dashboard' && typeof loadDashboard === 'function') {
    loadDashboard().then(() => {
      showToast('Dashboard refreshed', 'success');
    }).catch(err => {
      console.error('Refresh failed:', err);
      showToast('Refresh failed', 'error');
    });
  } else {
    // Generic refresh - reload projects and current view
    if (typeof loadProjects === 'function') {
      loadProjects().then(() => {
        showToast('Data refreshed', 'success');
      });
    }
  }
}

// ============================================
// NOTIFICATIONS
// ============================================

let allNotifications = [];
let currentFilter = 'all';

// Load All Notifications (called when switching to notifications view)
async function loadAllNotifications() {
  try {
    const response = await fetch('/api/notifications');
    const data = await response.json();
    allNotifications = data.notifications || [];
    renderNotifications();
    updateNotificationCount();
  } catch (err) {
    console.error('Failed to load notifications:', err);
    showToast('Failed to load notifications', 'error');
  }
}

// Filter Notifications
function filterNotifications(filter) {
  currentFilter = filter;
  
  // Update filter buttons
  document.querySelectorAll('.notification-filter-btn').forEach(btn => {
    if (btn.dataset.filter === filter) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });
  
  renderNotifications();
}

// Render Notifications
function renderNotifications() {
  const list = document.getElementById('notificationsList');
  if (!list) return;
  
  let filtered = allNotifications;
  
  if (currentFilter !== 'all') {
    filtered = allNotifications.filter(n => n.type === currentFilter);
  }
  
  if (filtered.length === 0) {
    list.innerHTML = '<div class="notifications-empty">No notifications</div>';
    return;
  }
  
  list.innerHTML = filtered.map(notif => renderNotificationItem(notif)).join('');
}

// Render Single Notification Item
function renderNotificationItem(notif) {
  const icon = getNotificationIcon(notif.type);
  const timeAgo = formatTimeAgo(notif.timestamp);
  const unreadClass = notif.read ? '' : 'unread';
  
  let actionsHTML = '';
  if (notif.actions && notif.actions.length > 0) {
    actionsHTML = `
      <div class="notification-actions">
        ${notif.actions.map(action => `
          <button class="notification-action-btn ${action.style || ''}" 
                  onclick="handleNotificationAction('${notif.id}', '${action.action}')">
            ${action.label}
          </button>
        `).join('')}
      </div>
    `;
  }
  
  return `
    <div class="notification-item ${unreadClass}" data-id="${notif.id}" onclick="markNotificationRead('${notif.id}')">
      <div class="notification-icon">${icon}</div>
      <div class="notification-content">
        <div class="notification-header">
          <span class="notification-title">${notif.title}</span>
          <span class="notification-time">${timeAgo}</span>
        </div>
        <div class="notification-message">${notif.message}</div>
        ${actionsHTML}
      </div>
      <button class="notification-dismiss" onclick="dismissNotification(event, '${notif.id}')">×</button>
    </div>
  `;
}

// Get Notification Icon
function getNotificationIcon(type) {
  const icons = {
    info: 'ℹ️',
    success: '✅',
    warning: '⚠️',
    error: '❌'
  };
  return icons[type] || icons.info;
}

// Format Time Ago
function formatTimeAgo(timestamp) {
  const now = Date.now();
  const diff = now - timestamp;
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  
  if (days > 0) return `${days}d ago`;
  if (hours > 0) return `${hours}h ago`;
  if (minutes > 0) return `${minutes}m ago`;
  return 'Just now';
}

// Mark Notification as Read
async function markNotificationRead(id) {
  try {
    await fetch(`/api/notifications/${id}/read`, { method: 'POST' });
    const notif = allNotifications.find(n => n.id === id);
    if (notif) {
      notif.read = true;
      renderNotifications();
      updateNotificationCount();
    }
  } catch (err) {
    console.error('Failed to mark notification as read:', err);
  }
}

// Mark All Notifications as Read
async function markAllNotificationsRead() {
  try {
    await fetch('/api/notifications/read-all', { method: 'POST' });
    allNotifications.forEach(n => n.read = true);
    renderNotifications();
    updateNotificationCount();
    showToast('All notifications marked as read', 'success');
  } catch (err) {
    console.error('Failed to mark all as read:', err);
    showToast('Failed to mark all as read', 'error');
  }
}

// Dismiss Notification
function dismissNotification(event, id) {
  event.stopPropagation();
  
  fetch(`/api/notifications/${id}`, { method: 'DELETE' })
    .then(() => {
      allNotifications = allNotifications.filter(n => n.id !== id);
      renderNotifications();
      updateNotificationCount();
      showToast('Notification dismissed', 'success');
    })
    .catch(err => {
      console.error('Failed to dismiss notification:', err);
      showToast('Failed to dismiss notification', 'error');
    });
}

// Clear All Notifications
async function clearAllNotifications() {
  if (!confirm('Are you sure you want to clear all notifications?')) {
    return;
  }
  
  try {
    await fetch('/api/notifications', { method: 'DELETE' });
    allNotifications = [];
    renderNotifications();
    updateNotificationCount();
    showToast('All notifications cleared', 'success');
  } catch (err) {
    console.error('Failed to clear notifications:', err);
    showToast('Failed to clear notifications', 'error');
  }
}

// Handle Notification Action
async function handleNotificationAction(notifId, action) {
  try {
    const response = await fetch(`/api/notifications/${notifId}/action`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action })
    });
    
    const result = await response.json();
    
    if (result.success) {
      showToast(result.message || 'Action completed', 'success');
      
      // Remove notification after action
      allNotifications = allNotifications.filter(n => n.id !== notifId);
      renderNotifications();
      updateNotificationCount();
    } else {
      showToast(result.error || 'Action failed', 'error');
    }
  } catch (err) {
    console.error('Failed to handle notification action:', err);
    showToast('Action failed', 'error');
  }
}

// Update Notification Count Badge
function updateNotificationCount() {
  const badge = document.getElementById('notificationCount');
  if (!badge) return;
  
  const unreadCount = allNotifications.filter(n => !n.read).length;
  
  if (unreadCount > 0) {
    badge.textContent = unreadCount;
    badge.classList.remove('hidden');
  } else {
    badge.classList.add('hidden');
  }
}

// Initialize on page load
if (typeof init === 'function') {
  const originalInit = init;
  init = function() {
    originalInit();
    // Load initial notification count
    loadAllNotifications();
  };
}

// Export functions for use in other modules
if (typeof window !== 'undefined') {
  window.toggleSettingsMenu = toggleSettingsMenu;
  window.switchTheme = switchTheme;
  window.exportData = exportData;
  window.shutdownDashboard = shutdownDashboard;
  window.refreshControlCenter = refreshControlCenter;
  window.loadAllNotifications = loadAllNotifications;
  window.filterNotifications = filterNotifications;
  window.markNotificationRead = markNotificationRead;
  window.markAllNotificationsRead = markAllNotificationsRead;
  window.dismissNotification = dismissNotification;
  window.clearAllNotifications = clearAllNotifications;
  window.handleNotificationAction = handleNotificationAction;
}
