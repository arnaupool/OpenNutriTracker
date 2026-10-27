// Web push for OpenNutriTracker reminders. Registered with scope "push/" so it
// never competes with Flutter's own service worker for the app page; it only
// receives push events and notification clicks.
//
// Payload (sent by the reminders-tick / reminders-test Edge Functions):
//   { "title": "...", "body": "...", "url": "/?open=meal&meal=lunch" }

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }
  event.waitUntil(
    self.registration.showNotification(data.title || 'OpenNutriTracker', {
      body: data.body || '',
      icon: 'icons/Icon-192.png',
      data: { url: data.url || '/' },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL((event.notification.data && event.notification.data.url) || '/', self.location.origin).href;
  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of windows) {
        if (new URL(client.url).origin !== self.location.origin) continue;
        try {
          await client.focus();
          // Only works for pages this worker controls; otherwise fall through to a new window.
          if ('navigate' in client) {
            await client.navigate(target);
            return;
          }
        } catch (_) {
          // try the next window, then open one
        }
      }
      if (self.clients.openWindow) await self.clients.openWindow(target);
    })(),
  );
});
