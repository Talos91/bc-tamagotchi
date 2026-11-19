// Web Push handler for the Black Cabin PWA (docs/design/08b-presence-api.md §4). tools/build_web.py copies this
// file next to index.html and puts importScripts('push-sw.js') at the top of Godot's index.service.worker.js.
// Payload from the `verb` Edge Function: {title, body, tag, url}.
self.addEventListener('push', function (e) {
	var d = {};
	try { d = e.data ? e.data.json() : {}; } catch (x) { d = { body: e.data ? e.data.text() : '' }; }
	e.waitUntil(self.registration.showNotification(d.title || 'Black Cabin', {
		body: d.body || '',
		tag: d.tag || 'bc',
		renotify: true,
		icon: 'index.144x144.png',
		badge: 'index.144x144.png',
		data: { url: d.url || './' }
	}));
});

self.addEventListener('notificationclick', function (e) {
	e.notification.close();
	var url = (e.notification.data && e.notification.data.url) || './';
	e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (cs) {
		for (var i = 0; i < cs.length; i++) { if ('focus' in cs[i]) { return cs[i].focus(); } }
		return self.clients.openWindow ? self.clients.openWindow(url) : null;
	}));
});
