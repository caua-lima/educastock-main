// Service worker do Firebase Cloud Messaging (push na web).
// Sem este arquivo o navegador não consegue gerar o token de notificação e os alertas de
// validade não chegam com a aba fechada. A versão do SDK acompanha o firebase_core_web
// (supportedFirebaseJsSdkVersion = 11.9.1). A configuração abaixo é a pública do app web.
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAVkusQsv1GWJl7GRdiCai0mlw1UhSQpv0',
  appId: '1:250042290294:web:edf271cf681e98d8318f57',
  messagingSenderId: '250042290294',
  projectId: 'educastock-69936',
  authDomain: 'educastock-69936.firebaseapp.com',
  storageBucket: 'educastock-69936.firebasestorage.app',
});

const messaging = firebase.messaging();

// Mensagem com a aba fechada: mostra a notificação e, ao tocar, abre os alertas.
messaging.onBackgroundMessage((payload) => {
  const n = payload.notification || {};
  self.registration.showNotification(n.title || 'EducaStock', {
    body: n.body || 'Há um novo alerta de validade.',
    icon: '/icons/Icon-192.png',
    data: { url: '/alerts' },
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/alerts';
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then((lista) => {
    for (const c of lista) {
      if ('focus' in c) { c.navigate(url); return c.focus(); }
    }
    return clients.openWindow(url);
  }));
});
