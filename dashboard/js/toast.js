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

async function pollNotifications() {
  try {
    const res = await fetch(`${API_BASE}/notifications/unread`);
    const data = await res.json();

    const countEl = document.getElementById('notificationCount');
    if (countEl) {
      if (data.total > 0) {
        countEl.textContent = data.total > 99 ? '99+' : data.total;
        countEl.classList.remove('hidden');
      } else {
        countEl.classList.add('hidden');
      }
    }

    if (data.notifications) {
      data.notifications.forEach(n => {
        if (n.id > lastNotificationId) {
          showToast(n);
          lastNotificationId = n.id;
        }
      });
    }
  } catch (e) {
    console.log('Failed to poll notifications:', e.message);
  }
}

function startNotificationPolling() {
  pollNotifications();
  notificationPollingInterval = setInterval(pollNotifications, 10000);
}

function stopNotificationPolling() {
  if (notificationPollingInterval) {
    clearInterval(notificationPollingInterval);
    notificationPollingInterval = null;
  }
}
