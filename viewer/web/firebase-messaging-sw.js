/* eslint-disable no-undef */
// Service worker do FCM (Web). Os valores devem coincidir com o app Web no Firebase Console
// e com `FIREBASE_*` passados no `flutter build` (ver docs/PUSH_NOTIFICATIONS.md).
// No Docker, `__FIREBASE_WEB_APP_ID__` é substituído pelo ARG antes do build.

importScripts('https://www.gstatic.com/firebasejs/11.6.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.6.0/firebase-messaging-compat.js');

// Valores por defeito = projeto do repo; no Docker o Dockerfile substitui antes do `flutter build`
// para coincidir com os mesmos --dart-define (obrigatório: apiKey + appId do MESMO objecto na consola).
firebase.initializeApp({
  apiKey: '__FIREBASE_WEB_API_KEY__',
  appId: '__FIREBASE_WEB_APP_ID__',
  messagingSenderId: '__FIREBASE_MESSAGING_SENDER_ID__',
  projectId: '__FIREBASE_PROJECT_ID__',
  authDomain: '__FIREBASE_AUTH_DOMAIN__',
  storageBucket: '__FIREBASE_STORAGE_BUCKET__',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js]', payload.notification?.title || payload.data);
});
