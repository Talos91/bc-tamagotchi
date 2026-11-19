importScripts('push-sw.js');
self.addEventListener('push', function (e) {
	var t = e.data ? e.data.text() : '';
	e.waitUntil(self.clients.matchAll({ includeUncontrolled: true, type: 'window' }).then(function (cs) {
		cs.forEach(function (c) { c.postMessage({ push: t, at: Date.now() }); });
	}));
});
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });
