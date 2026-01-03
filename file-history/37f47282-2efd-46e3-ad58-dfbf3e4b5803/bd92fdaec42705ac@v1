// ============================================================================
// SERVICE WORKER - PWA Push Notifications (ADR-0014)
// Handles push notifications when app is closed/background
// ============================================================================

const SW_VERSION = '1.0.0';

// Install event - activate immediately
self.addEventListener('install', (_event) => {
  console.log(`[SW ${SW_VERSION}] Installing...`);
  self.skipWaiting();
});

// Activate event - claim clients immediately
self.addEventListener('activate', (event) => {
  console.log(`[SW ${SW_VERSION}] Activating...`);
  event.waitUntil(self.clients.claim());
});

// Push event - show notification
self.addEventListener('push', (event) => {
  console.log(`[SW ${SW_VERSION}] Push received`);

  if (!event.data) {
    console.warn('[SW] Push event but no data');
    return;
  }

  let data;
  try {
    data = event.data.json();
  } catch (e) {
    console.error('[SW] Failed to parse push data:', e);
    return;
  }

  const {
    title = 'MirrorBuddy',
    body = '',
    icon = '/icons/notification.png',
    badge = '/icons/badge.png',
    tag,
    data: notificationData = {},
    requireInteraction = false,
    actions = [],
  } = data;

  const options = {
    body,
    icon,
    badge,
    tag: tag || `mirrorbuddy-${Date.now()}`,
    data: notificationData,
    requireInteraction,
    actions,
    // Vibrate pattern for mobile (short-long-short)
    vibrate: [100, 50, 200],
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

// Notification click - open app or focus existing window
self.addEventListener('notificationclick', (event) => {
  console.log(`[SW ${SW_VERSION}] Notification clicked:`, event.notification.tag);

  event.notification.close();

  const urlToOpen = event.notification.data?.url || '/';

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Check if app is already open
        for (const client of clientList) {
          if (client.url.includes(self.location.origin) && 'focus' in client) {
            // Navigate to the specific URL if provided
            if (event.notification.data?.url) {
              client.navigate(urlToOpen);
            }
            return client.focus();
          }
        }
        // App not open - open new window
        if (self.clients.openWindow) {
          return self.clients.openWindow(urlToOpen);
        }
      })
  );
});

// Notification close - track dismissal (optional analytics)
self.addEventListener('notificationclose', (event) => {
  console.log(`[SW ${SW_VERSION}] Notification dismissed:`, event.notification.tag);

  // Could send analytics here if needed
  // But we keep it simple for privacy
});

// Handle push subscription change (browser may rotate keys)
self.addEventListener('pushsubscriptionchange', (event) => {
  console.log(`[SW ${SW_VERSION}] Push subscription changed`);

  event.waitUntil(
    self.registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: self.VAPID_PUBLIC_KEY,
    })
    .then((subscription) => {
      // Re-register with server
      return fetch('/api/push/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(subscription.toJSON()),
      });
    })
    .catch((err) => {
      console.error('[SW] Failed to re-subscribe:', err);
    })
  );
});

console.log(`[SW ${SW_VERSION}] Service Worker loaded`);
