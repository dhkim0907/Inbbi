// 페이지와 서비스 워커가 공유하는 수신함. 앱 목록에 저장된 항목만 제거한다.
self.inbbiPushInbox = (() => {
  function database() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('inbbi-push', 1);
      request.onupgradeneeded = () => request.result.createObjectStore('inbox', { keyPath: 'eventId' });
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(new Error('Inbox unavailable'));
    });
  }
  async function transaction(mode, operation) {
    const db = await database();
    return new Promise((resolve, reject) => {
      const tx = db.transaction('inbox', mode);
      const request = operation(tx.objectStore('inbox'));
      tx.oncomplete = () => { db.close(); resolve(request.result); };
      tx.onerror = tx.onabort = () => { db.close(); reject(new Error('Inbox transaction failed')); };
    });
  }
  return {
    load: () => transaction('readonly', store => store.getAll()),
    save: data => transaction('readwrite', store => store.put(data)),
    remove: id => transaction('readwrite', store => store.delete(id)),
  };
})();
