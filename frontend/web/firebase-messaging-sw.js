/*
 * Firebase Cloud Messaging service worker for the Purana Bazaar web app.
 *
 * 1. Create a Firebase project and a Web app.
 * 2. Copy the web config below (Project settings → General → Your apps).
 * 3. Generate a Web Push certificate (Project settings → Cloud Messaging →
 *    Web Push certificates) and pass it to the Flutter app with
 *    --dart-define=FIREBASE_VAPID_KEY=<key>.
 * 4. Run the app with the FIREBASE_* dart-defines listed in README.md.
 */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_WITH_FIREBASE_API_KEY',
  authDomain: 'REPLACE_WITH_FIREBASE_AUTH_DOMAIN',
  projectId: 'REPLACE_WITH_FIREBASE_PROJECT_ID',
  storageBucket: 'REPLACE_WITH_FIREBASE_STORAGE_BUCKET',
  messagingSenderId: 'REPLACE_WITH_FIREBASE_MESSAGING_SENDER_ID',
  appId: 'REPLACE_WITH_FIREBASE_APP_ID'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};
  self.registration.showNotification(notification.title || 'Purana Bazaar', {
    body: notification.body || 'You have a new update from Purana Bazaar.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: data
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const orderId = event.notification.data && event.notification.data.orderId;
  const target = orderId ? `/orders/${orderId}` : '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const client of windows) {
        if ('focus' in client) {
          client.navigate(target);
          return client.focus();
        }
      }
      return clients.openWindow(target);
    })
  );
});
