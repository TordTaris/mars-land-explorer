// LOCAL MARS v4.0 — network-first updates with complete offline app shell.
const CACHE = "local-mars-v4-8";
const CORE = [
  "./", "./index.html", "./city.html", "./underground.html",
  "./m003-base.html", "./m003-dimension-gate.html", "./civilization.html", "./i18n.js",
  "./world-server.js", "./multiverse.js", "./easy-play.js", "./locales/th.json", "./locales/en.json",
  "./manifest.webmanifest", "./icon.svg"
];

self.addEventListener("install", event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await cache.addAll(CORE);
    await self.skipWaiting();
  })());
});

self.addEventListener("activate", event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys
      .filter(key => (key.startsWith("mars-land-") || key.startsWith("local-mars-")) && key !== CACHE)
      .map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin) return;
  event.respondWith((async () => {
    try {
      const fresh = await fetch(request, { cache: "no-store" });
      if (fresh.ok) {
        const cache = await caches.open(CACHE);
        await cache.put(request, fresh.clone());
      }
      return fresh;
    } catch (error) {
      return (await caches.match(request)) ||
        (request.mode === "navigate" ? await caches.match("./index.html") : Response.error());
    }
  })());
});
