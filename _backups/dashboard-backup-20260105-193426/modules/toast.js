// Toast Notification System
import { API_BASE } from './state.js';

let lastNotificationId = 0;
let notificationPollingInterval = null;

const severityIcons = {
  info: '&#x2139;',
  success: '&#x2713;',
  warning: '&#x26A0;',
  error: '&#x2717;'
};

export function showToast(notification) {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  // Handle simple string toast
  if (typeof notification === 'string') {
    notification = { title: notification, severity: 'info' };
  }

  const toast = document.createElement('div');
  toast.className = `toast ${notification.severity || 'info'}`;
  toast.dataset.id = notification.id || '';

  toast.innerHTML = `
    <div class="toast-icon">${severityIcons[notification.severity] || severityIcons.info}</div>
    <div class="toast-content">
      <div class="toast-title">${notification.title}</div>
      ${notification.message ? `<div class="toast-message">${notification.message}</div>` : ''}
      ${notification.project_name ? `<div class="toast-project">${notification.project_name}</div>` : ''}
      ${notification.link ? `
        <div class="toast-actions">
          <button class="toast-action primary" onclick="window.dashboardApi.handleNotificationAction(${notification.id}, '${notification.link}', '${notification.link_type}')">View</button>
          <button class="toast-action" onclick="window.dashboardApi.dismissToast(this.closest('.toast'))">Dismiss</button>
        </div>
      ` : ''}
    </div>
    <button class="toast-close" onclick="window.dashboardApi.dismissToast(this.closest('.toast'))">&times;</button>
  `;

  if (notification.link) {
    toast.style.cursor = 'pointer';
  }

  container.appendChild(toast);

  const duration = notification.severity === 'error' ? 12000 : 8000;
  setTimeout(() => dismissToast(toast), duration);
}

export function dismissToast(toast) {
  if (!toast || toast.classList.contains('dismissing')) return;
  toast.classList.add('dismissing');

  const id = toast.dataset.id;
  if (id) {
    fetch(`${API_BASE}/notifications/${id}/read`, { method: 'POST' });
  }

  setTimeout(() => toast.remove(), 300);
}

export function handleNotificationAction(id, link, linkType, selectProjectFn, showViewFn, loadPlanFn) {
  fetch(`${API_BASE}/notifications/${id}/read`, { method: 'POST' });

  if (linkType === 'project') {
    selectProjectFn(link);
    showViewFn('dashboard');
  } else if (linkType === 'github') {
    window.open(link, '_blank');
  } else if (linkType === 'plan') {
    loadPlanFn(parseInt(link));
    showViewFn('dashboard');
  } else if (link.startsWith('http')) {
    window.open(link, '_blank');
  }
}

export async function pollNotifications() {
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

export function startNotificationPolling() {
  pollNotifications();
  notificationPollingInterval = setInterval(pollNotifications, 10000);
}

export function stopNotificationPolling() {
  if (notificationPollingInterval) {
    clearInterval(notificationPollingInterval);
    notificationPollingInterval = null;
  }
}
