// Metalnini — service worker : notifications push uniquement. Aucun cache hors ligne : GitHub Pages sert toujours la dernière version.
self.addEventListener('install', function(){ self.skipWaiting(); });
self.addEventListener('activate', function(e){ e.waitUntil(self.clients.claim()); });
self.addEventListener('push', function(e){
  var d = {}; try{ d = e.data ? e.data.json() : {}; }catch(err){ d = {body: e.data ? e.data.text() : ''}; }
  e.waitUntil(self.registration.showNotification(d.title || 'Metalnini', {
    body: d.body || '', icon: '../icons/icon-192.png', tag: d.tag || 'metalnini', data: {url: new URL(d.url || './', self.registration.scope).href}
  }));
});
// toucher la notification : on revient sur l'app déjà ouverte, sinon on l'ouvre
self.addEventListener('notificationclick', function(e){
  e.notification.close();
  var url = (e.notification.data && e.notification.data.url) || self.registration.scope;
  e.waitUntil(self.clients.matchAll({type: 'window', includeUncontrolled: true}).then(function(list){
    for(var i = 0; i < list.length; i++) if(list[i].url.indexOf(self.registration.scope) === 0) return list[i].focus();
    return self.clients.openWindow(url);
  }));
});
