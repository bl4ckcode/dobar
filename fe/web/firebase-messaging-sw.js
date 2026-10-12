importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDQU5emyfqWFkqf69-5cQWzgA41971Hb6A",
  authDomain: "barz777.firebaseapp.com",
  projectId: "barz777",
  storageBucket: "barz777.firebasestorage.app",
  messagingSenderId: "505844682559",
  appId: "1:505844682559:web:899702388de3eb0f2ccd8a",
  measurementId: "G-WQ02MVL783"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification?.title || 'Barz';
  const notificationOptions = {
    body: payload.notification?.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
