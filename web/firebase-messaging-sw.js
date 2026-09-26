// Firebase Messaging Service Worker for web background push notifications
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCv5jf14fB1D-kT32ohDbF8sOPJTbEutGk',
  appId: '1:1048000775904:web:29a8bc9e7c63da03a67285',
  messagingSenderId: '1048000775904',
  projectId: 'laghari-family',
  authDomain: 'laghari-family.firebaseapp.com',
  storageBucket: 'laghari-family.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message: ', payload);
  const notificationTitle = payload.notification ? payload.notification.title : 'Laghari Family';
  const notificationOptions = {
    body: payload.notification ? payload.notification.body : 'You have a new update.',
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
