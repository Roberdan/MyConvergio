// Notification Archive View

async function loadNotificationsView() {
  const list = document.getElementById('notificationsList');
  if (!list) return;

  list.innerHTML = '<div class="notifications-empty">Loading...</div>';

  try {
    let url = `${API_BASE}/notifications?limit=50`;
    if (notificationsFilter === 'unread') url += '&unread=true';
    if (notificationsFilter === 'success') url += '&severity=success';
    if (notificationsFilter === 'error') url += '&severity=error';
    if (notificationsSearch) url += `&search=${encodeURIComponent(notificationsSearch)}`;

    const res = await fetch(url);
    const data = await res.json();

    if (!data.notifications || data.notifications.length === 0) {
      list.innerHTML = '<div class="notifications-empty">No notifications found</div>';
      return;
    }

    list.innerHTML = data.notifications.map(n => {
      const time = n.created_at ? formatRelativeTime(new Date(n.created_at)) : '';
      const severityIcons = { info: '&#x2139;', success: '&#x2713;', warning: '&#x26A0;', error: '&#x2717;' };

      return `
        <div class="notification-item ${n.is_read ? '' : 'unread'}" onclick="handleNotificationClick(${n.id}, '${n.link || ''}', '${n.link_type || ''}')">
          <div class="notification-item-icon ${n.severity}">${severityIcons[n.severity] || severityIcons.info}</div>
          <div class="notification-item-content">
            <div class="notification-item-header">
              <span class="notification-item-title">${n.title}</span>
              <span class="notification-item-time">${time}</span>
            </div>
            ${n.message ? `<div class="notification-item-message">${n.message}</div>` : ''}
            <div class="notification-item-project">${n.project_name || n.project_id}</div>
          </div>
        </div>
      `;
    }).join('');
  } catch (e) {
    list.innerHTML = `<div class="notifications-empty">Error: ${e.message}</div>`;
  }
}

function handleNotificationClick(id, link, linkType) {
  fetch(`${API_BASE}/notifications/${id}/read`, { method: 'POST' }).then(() => {
    loadNotificationsView();
    pollNotifications();
  });

  if (link) {
    handleNotificationAction(id, link, linkType);
  }
}

function filterNotifications(filter) {
  notificationsFilter = filter;

  document.querySelectorAll('.notifications-filter').forEach(btn => {
    btn.classList.toggle('active', btn.textContent.toLowerCase().includes(filter) || (filter === 'all' && btn.textContent === 'All'));
  });

  loadNotificationsView();
}

function searchNotifications(query) {
  notificationsSearch = query;
  clearTimeout(window.notificationSearchTimeout);
  window.notificationSearchTimeout = setTimeout(loadNotificationsView, 300);
}

async function markAllNotificationsRead() {
  await fetch(`${API_BASE}/notifications/read-all`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
  loadNotificationsView();
  pollNotifications();
}

function formatRelativeTime(date) {
  const now = new Date();
  const diffMs = now - date;
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return 'just now';
  if (diffMins < 60) return diffMins + 'm ago';
  if (diffHours < 24) return diffHours + 'h ago';
  if (diffDays < 7) return diffDays + 'd ago';
  return date.toLocaleDateString();
}

// Trigger Settings Modal
async function showTriggerSettings() {
  const modal = document.getElementById('triggerModal');
  if (!modal) return;

  modal.style.display = 'flex';
  await loadTriggerSettings();

  // Close on overlay click
  modal.onclick = (e) => {
    if (e.target === modal) closeTriggerModal();
  };
}

function closeTriggerModal() {
  const modal = document.getElementById('triggerModal');
  if (modal) modal.style.display = 'none';
}

async function loadTriggerSettings() {
  const list = document.getElementById('triggerList');
  if (!list) return;

  list.innerHTML = '<div class="trigger-loading">Loading triggers...</div>';

  try {
    const res = await fetch(`${API_BASE}/notifications/triggers`);
    const triggers = await res.json();

    if (!triggers || triggers.length === 0) {
      list.innerHTML = '<div class="trigger-loading">No triggers configured</div>';
      return;
    }

    list.innerHTML = triggers.map(t => {
      const eventLabel = t.event_type.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
      return `
        <div class="trigger-item">
          <div class="trigger-toggle ${t.is_enabled ? 'active' : ''}"
               onclick="toggleTrigger(${t.id}, this)"
               data-id="${t.id}"></div>
          <div class="trigger-info">
            <div class="trigger-title">${eventLabel}</div>
            <div class="trigger-description">${t.title_template}</div>
          </div>
          <span class="trigger-severity ${t.severity}">${t.severity}</span>
        </div>
      `;
    }).join('');
  } catch (e) {
    list.innerHTML = `<div class="trigger-loading">Error: ${e.message}</div>`;
  }
}

async function toggleTrigger(id, element) {
  try {
    const res = await fetch(`${API_BASE}/notifications/triggers/${id}/toggle`, { method: 'POST' });
    const result = await res.json();

    if (result.success) {
      element.classList.toggle('active');
    }
  } catch (e) {
    showToast('Failed to toggle trigger', 'error');
  }
}
