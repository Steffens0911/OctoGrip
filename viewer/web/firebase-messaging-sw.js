/* eslint-disable no-undef */
// Service worker do FCM (Web). Os valores devem coincidir com o app Web no Firebase Console
// e com `FIREBASE_*` passados no `flutter build` (ver docs/PUSH_NOTIFICATIONS.md).
// No Docker, `__FIREBASE_WEB_APP_ID__` é substituído pelo ARG antes do build.

importScripts('https://www.gstatic.com/firebasejs/11.6.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.6.0/firebase-messaging-compat.js');

// Valores por defeito = projeto do repo; no Docker o Dockerfile substitui antes do `flutter build`
// para coincidir com os mesmos --dart-define (obrigatório: apiKey + appId do MESMO objecto na consola).
firebase.initializeApp({
  apiKey: 'AIzaSyAby3LjFqiQysgqFJF3TDkFyIQbj7XeD2A',
  appId: '__FIREBASE_WEB_APP_ID__',
  messagingSenderId: '914963189561',
  projectId: 'octogrip',
  authDomain: 'octogrip.firebaseapp.com',
  storageBucket: 'octogrip.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js]', payload.notification?.title || payload.data);
});
