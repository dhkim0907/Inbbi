/* Firebase 공개 클라이언트 설정만 로드한다. 서비스 계정 키를 넣지 않는다. */
importScripts('./push-inbox.js');
// Firebase 기본 클릭 핸들러보다 먼저 등록한다.
self.addEventListener('notificationclick', event => {
  const data = event.notification.data?.FCM_MSG?.data;
  if (!data?.eventId) return;
  event.stopImmediatePropagation();
  event.notification.close();
  event.waitUntil((async () => {
    await self.inbbiPushInbox.save({ ...data, _opened: true });
    const windows = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    const appUrl = new URL('./', self.location.href);
    const target = windows.find(client => new URL(client.url).pathname.startsWith(appUrl.pathname));
    if (target) {
      await target.focus();
      target.postMessage({ type: 'inbbi-push-opened' });
    } else {
      await clients.openWindow(appUrl.href);
    }
  })());
});
importScripts('./firebase-config.js');
if (self.inbbiFirebaseConfig) {
  importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js');
  importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js');
  firebase.initializeApp(self.inbbiFirebaseConfig);
  firebase.messaging().onBackgroundMessage(async payload => {
    if (payload.data?.eventId) await self.inbbiPushInbox.save(payload.data);
    // notification 페이로드는 FCM이 표시한다. showNotification을 중복 호출하지 않는다.
  });
}
