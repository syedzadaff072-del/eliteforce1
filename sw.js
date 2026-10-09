// ELITE FORCE service worker
// Static assets: cache-first. Pages: network-first with offline fallback.
// Chat / API / socket traffic is never cached (private guild data).
const CACHE_NAME = "elite-force-v2";

const PRECACHE = [
    "/static/offline.html",
    "/static/manifest.json",
    "/static/icons/icon-192.png",
    "/static/icons/icon-512.png",
    "/static/icons/icon-maskable-192.png",
    "/static/icons/icon-maskable-512.png",
    "/static/icons/apple-touch-icon.png",
    "/static/icons/icon.svg",
    "/static/favicon.ico"
];

self.addEventListener("install", function (event) {
    event.waitUntil(
        caches.open(CACHE_NAME).then(function (cache) {
            return Promise.all(
                PRECACHE.map(function (url) {
                    return cache.add(url).catch(function () {});
                })
            );
        })
    );
    self.skipWaiting();
});

self.addEventListener("activate", function (event) {
    event.waitUntil(
        caches.keys().then(function (names) {
            return Promise.all(
                names.map(function (name) {
                    if (name !== CACHE_NAME) {
                        return caches.delete(name);
                    }
                })
            );
        })
    );
    self.clients.claim();
});

self.addEventListener("fetch", function (event) {
    const request = event.request;

    if (request.method !== "GET") {
        return;
    }

    const url = new URL(request.url);

    // Only handle same-origin requests; never touch socket.io or CDN traffic
    if (url.origin !== self.location.origin || url.pathname.startsWith("/socket.io")) {
        return;
    }

    // Page navigations: network first, offline page if network fails
    if (request.mode === "navigate") {
        event.respondWith(
            fetch(request).catch(function () {
                return caches.match("/static/offline.html");
            })
        );
        return;
    }

    // Static files: cache first, refresh in background
    if (url.pathname.startsWith("/static/")) {
        event.respondWith(
            caches.match(request).then(function (cached) {
                const network = fetch(request)
                    .then(function (response) {
                        if (response && response.ok) {
                            const copy = response.clone();
                            caches.open(CACHE_NAME).then(function (cache) {
                                cache.put(request, copy);
                            });
                        }
                        return response;
                    })
                    .catch(function () {
                        return cached;
                    });
                return cached || network;
            })
        );
    }
});
