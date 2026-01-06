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
// NOTIFICATIONS OVERLAY
// ============================================

let allNotifications = [];
let currentFilter = 'all';

// Toggle Notifications Overlay
function toggleNotificationsOverlay() {
  const overlay = document.getElementById('notificationsOverlay');
  if (!overlay) return;
  
  const isVisible = overlay.style.display !== 'none';
  
  if (isVisible) {
    closeNotificationsOverlay();
  } else {
    currentFilter = 'all';
    setActiveFilterButtons('all');
    overlay.style.display = 'flex';
    loadAllNotifications();
  }
}

// Close Notifications Overlay
function closeNotificationsOverlay() {
  const overlay = document.getElementById('notificationsOverlay');
  if (overlay) {
    overlay.style.display = 'none';
  }
}

// Load All Notifications
async function loadAllNotifications() {
  try {
    const response = await fetch('/api/notifications');
    const data = await response.json();
    allNotifications = (data.notifications || []).map(n => ({
      ...n,
      severity: (n.severity || '').toString().toLowerCase(),
      is_read: Number(n.is_read) || 0
    }));
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

  setActiveFilterButtons(filter);
  renderNotifications();
}

function setActiveFilterButtons(filter) {
  document.querySelectorAll('.notification-filter-btn').forEach(btn => {
    if (btn.dataset.filter === filter) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });
}

// Render Notifications
function renderNotifications() {
  // For overlay
  const listOverlay = document.getElementById('notificationsListOverlay');
  
  let filtered = allNotifications;
  
  // Apply filters
  if (currentFilter === 'unread') {
    filtered = allNotifications.filter(n => Number(n.is_read) === 0);
  } else if (currentFilter !== 'all') {
    filtered = allNotifications.filter(n => n.severity === currentFilter);
  }
  
  if (filtered.length === 0) {
    const emptyMsg = currentFilter === 'unread' ? 'No unread notifications' : 
                     currentFilter === 'all' ? 'No notifications' : 
                     `No ${currentFilter} notifications`;
    if (listOverlay) listOverlay.innerHTML = `<div class="notifications-empty">${emptyMsg}</div>`;
    return;
  }
  
  const html = filtered.map(notif => renderNotificationItem(notif)).join('');
  if (listOverlay) listOverlay.innerHTML = html;
}

// Render Single Notification Item
function renderNotificationItem(notif) {
  const icon = getNotificationIcon(notif.severity);
  const timeAgo = formatTimeAgo(new Date(notif.created_at).getTime());
  const unreadClass = notif.is_read === 0 ? 'unread' : '';
  
  return `
    <div class="notification-item ${unreadClass}" data-id="${notif.id}" onclick="markNotificationRead('${notif.id}')">
      <div class="notification-icon ${notif.severity}">${icon}</div>
      <div class="notification-content">
        <div class="notification-header">
          <span class="notification-title">${notif.title}</span>
          <span class="notification-time">${timeAgo}</span>
        </div>
        <div class="notification-message">${notif.message || ''}</div>
        <div class="notification-project">${notif.project_name || 'Unknown Project'}</div>
      </div>
      <button class="notification-dismiss" onclick="dismissNotification(event, '${notif.id}')">×</button>
    </div>
  `;
}

// Get Notification Icon
function getNotificationIcon(severity) {
  const icons = {
    info: `
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="9" />
        <path d="M12 9.5v-.1" />
        <path d="M11 12.5h1v4" />
      </svg>
    `,
    success: `
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="9" />
        <path d="M8 12.5l2.5 2.5 5-5" />
      </svg>
    `,
    warning: `
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
        <path d="M12 4l8 14H4l8-14z" />
        <path d="M12 10v3.5" />
        <path d="M12 17.5v.1" />
      </svg>
    `,
    error: `
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="9" />
        <path d="M9 9l6 6" />
        <path d="M15 9l-6 6" />
      </svg>
    `
  };
  return icons[severity] || icons.info;
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
      notif.is_read = 1;
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
    allNotifications.forEach(n => { n.is_read = 1; });
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
  
  const unreadCount = allNotifications.filter(n => Number(n.is_read) === 0).length;
  
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
  window.toggleNotificationsOverlay = toggleNotificationsOverlay;
  window.closeNotificationsOverlay = closeNotificationsOverlay;
  window.loadAllNotifications = loadAllNotifications;
  window.filterNotifications = filterNotifications;
  window.markNotificationRead = markNotificationRead;
  window.markAllNotificationsRead = markAllNotificationsRead;
  window.dismissNotification = dismissNotification;
  window.clearAllNotifications = clearAllNotifications;
  window.handleNotificationAction = handleNotificationAction;
}
