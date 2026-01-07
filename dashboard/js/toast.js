// Toast Notifications

function showToast(notification) {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  // Handle simple string messages
  if (typeof notification === 'string') {
    notification = { title: notification, severity: arguments[1] || 'info' };
  }

  const severityIcons = {
    info: '&#x2139;',
    success: '&#x2713;',
    warning: '&#x26A0;',
    error: '&#x2717;'
  };

  const toast = document.createElement('div');
  toast.className = `toast ${notification.severity || 'info'}`;
  toast.dataset.id = notification.id;

  toast.innerHTML = `
    <div class="toast-icon">${severityIcons[notification.severity] || severityIcons.info}</div>
    <div class="toast-content">
      <div class="toast-title">${notification.title}</div>
      ${notification.message ? `<div class="toast-message">${notification.message}</div>` : ''}
      ${notification.project_name || notification.project_id ? `<div class="toast-project">${notification.project_name || notification.project_id}</div>` : ''}
      ${notification.link ? `
        <div class="toast-actions">
          <button class="toast-action primary" onclick="handleNotificationAction(${notification.id}, '${notification.link}', '${notification.link_type}')">View</button>
          <button class="toast-action" onclick="dismissToast(this.closest('.toast'))">Dismiss</button>
        </div>
      ` : ''}
    </div>
    <button class="toast-close" onclick="dismissToast(this.closest('.toast'))">&times;</button>
  `;

  if (notification.link) {
    toast.style.cursor = 'pointer';
  }

  // Add click handler to navigate to notifications view
  toast.addEventListener('click', (e) => {
    // Don't navigate if clicking on buttons
    if (e.target.tagName === 'BUTTON') return;

    // Mark as read
    if (notification.id && notification.id !== 'undefined' && !isNaN(parseInt(notification.id))) {
      fetch(`${API_BASE}/notifications/${notification.id}/read`, { method: 'POST' }).then(() => {
        pollNotifications();
      });
    }

    // Navigate to notifications view
    showView('notifications');
    dismissToast(toast);
  });

  container.appendChild(toast);

  const duration = notification.severity === 'error' ? 12000 : 8000;
  setTimeout(() => dismissToast(toast), duration);
}

function dismissToast(toast) {
  if (!toast || toast.classList.contains('dismissing')) return;
  toast.classList.add('dismissing');

  const id = toast.dataset.id;
  if (id && id !== 'undefined' && !isNaN(parseInt(id))) {
    fetch(`${API_BASE}/notifications/${id}/read`, { method: 'POST' });
  }

  setTimeout(() => toast.remove(), 300);
}

function handleNotificationAction(id, link, linkType) {
  fetch(`${API_BASE}/notifications/${id}/read`, { method: 'POST' });

  if (linkType === 'project') {
    selectProject(link);
    showView('dashboard');
  } else if (linkType === 'github') {
    window.open(link, '_blank');
  } else if (linkType === 'plan') {
    loadPlanDetails(parseInt(link));
    showView('dashboard');
  } else if (link.startsWith('http')) {
    window.open(link, '_blank');
  }
}

// SSE-based real-time notifications
let notificationEventSource = null;

function updateNotificationCount(count) {
  const countEl = document.getElementById('notificationCount');
  if (countEl) {
    if (count > 0) {
      countEl.textContent = count > 99 ? '99+' : count;
      countEl.classList.remove('hidden');
    } else {
      countEl.classList.add('hidden');
    }
  }
}

async function pollNotifications() {
  // Fallback polling if SSE not connected
  if (notificationEventSource?.readyState === EventSource.OPEN) return;

  try {
    const res = await fetch(`${API_BASE}/notifications/unread`);
    const data = await res.json();
    updateNotificationCount(data.total || 0);
  } catch (e) {
    Logger.debug('Failed to poll notifications:', e.message);
  }
}

function startNotificationPolling() {
  // Try SSE first
  if (typeof EventSource !== 'undefined') {
    notificationEventSource = new EventSource(`${API_BASE}/notifications/stream`);

    notificationEventSource.addEventListener('notification', (e) => {
      const notification = JSON.parse(e.data);
      if (notification.id > lastNotificationId) {
        showToast(notification);
        lastNotificationId = notification.id;
      }
      // Refresh count
      pollNotifications();
    });

    notificationEventSource.addEventListener('count', (e) => {
      const data = JSON.parse(e.data);
      updateNotificationCount(data.count || 0);
    });

    notificationEventSource.onerror = () => {
      Logger.warn('Notification SSE error, falling back to polling');
      notificationEventSource.close();
      notificationEventSource = null;
      // Fallback to polling
      notificationPollingInterval = setInterval(pollNotifications, 10000);
    };

    Logger.info('Notification SSE connected');
  } else {
    // Fallback to polling for older browsers
    pollNotifications();
    notificationPollingInterval = setInterval(pollNotifications, 10000);
  }
}

function stopNotificationPolling() {
  if (notificationEventSource) {
    notificationEventSource.close();
    notificationEventSource = null;
  }
  if (notificationPollingInterval) {
    clearInterval(notificationPollingInterval);
    notificationPollingInterval = null;
  }
}

// Notification Dropdown
async function toggleNotificationDropdown(event) {
  event.stopPropagation();
  const dropdown = document.getElementById('notificationDropdown');
  if (!dropdown) return;

  if (dropdown.classList.contains('visible')) {
    closeNotificationDropdown();
  } else {
    dropdown.classList.add('visible');
    await loadNotificationDropdown();
    // Close on outside click
    setTimeout(() => {
      document.addEventListener('click', closeNotificationDropdownOnOutside);
    }, 10);
  }
}

function closeNotificationDropdown() {
  const dropdown = document.getElementById('notificationDropdown');
  if (dropdown) dropdown.classList.remove('visible');
  document.removeEventListener('click', closeNotificationDropdownOnOutside);
}

function closeNotificationDropdownOnOutside(event) {
  const dropdown = document.getElementById('notificationDropdown');
  const bell = document.getElementById('notificationsButton');
  if (dropdown && !dropdown.contains(event.target) && !bell?.contains(event.target)) {
    closeNotificationDropdown();
  }
}

async function loadNotificationDropdown() {
  const list = document.getElementById('notificationDropdownList');
  if (!list) return;

  list.innerHTML = '<div class="notification-dropdown-empty">Loading...</div>';

  try {
    const res = await fetch(`${API_BASE}/notifications/unread`);
    const data = await res.json();

    if (!data.notifications || data.notifications.length === 0) {
      list.innerHTML = '<div class="notification-dropdown-empty">No new notifications</div>';
      return;
    }

    const severityIcons = { info: '&#x2139;', success: '&#x2713;', warning: '&#x26A0;', error: '&#x2717;' };

    list.innerHTML = data.notifications.slice(0, 10).map(n => {
      const time = n.created_at ? formatRelativeTime(new Date(n.created_at)) : '';
      return `
        <div class="notification-dropdown-item ${n.is_read ? '' : 'unread'}"
             onclick="handleDropdownNotificationClick(${n.id}, '${n.link || ''}', '${n.link_type || ''}')">
          <div class="notification-dropdown-icon ${n.severity}">${severityIcons[n.severity] || severityIcons.info}</div>
          <div class="notification-dropdown-content">
            <div class="notification-dropdown-title">${n.title}</div>
            ${n.message ? `<div class="notification-dropdown-message">${n.message}</div>` : ''}
            <div class="notification-dropdown-meta">
              <span class="notification-dropdown-project">${n.project_name || n.project_id}</span>
              <span>${time}</span>
            </div>
          </div>
        </div>
      `;
    }).join('');

    if (data.notifications.length > 10) {
      list.innerHTML += `
        <div class="notification-dropdown-footer">
          <a href="#" onclick="showView('notifications'); closeNotificationDropdown(); return false;">
            View all ${data.total} notifications
          </a>
        </div>
      `;
    }
  } catch (e) {
    list.innerHTML = `<div class="notification-dropdown-empty">Error loading notifications</div>`;
  }
}

function handleDropdownNotificationClick(id, link, linkType) {
  fetch(`${API_BASE}/notifications/${id}/read`, { method: 'POST' }).then(() => {
    loadNotificationDropdown();
    pollNotifications();
  });

  if (link) {
    closeNotificationDropdown();
    handleNotificationAction(id, link, linkType);
  }
}
