// LOCAL MARS v4.0 — network-first updates with complete offline app shell.
const CACHE = "local-mars-v4-54";
const CORE = [
  "./", "./index.html", "./install.html", "./city.html", "./underground.html", "./mission-trainer.html",
  "./parcels/M-001/index.html",
  "./parcels/M-002/index.html",
  "./parcels/M-003/index.html",
  "./parcels/M-004/index.html",
  "./parcels/M-005/index.html",
  "./parcels/M-006/index.html",
  "./parcels/M-007/index.html",
  "./parcels/M-008/index.html",
  "./parcels/M-009/index.html",
  "./parcels/M-010/index.html",
  "./parcels/M-011/index.html",
  "./parcels/M-012/index.html",
  "./m003-base.html", "./m003-dimension-gate.html", "./top-secret-demo.html",
  "./civilization.html", "./i18n.js", "./premium-ui.css",
  "./world-server.js", "./nasa-data.js", "./member-workspace.js", "./multiverse.js", "./easy-play.js",
  "./locales/th.json", "./locales/en.json",
  "./manifest.webmanifest", "./icon.svg"
];

self.addEventListener("install", event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // Cache each core route independently: one missing optional page must not disable offline startup.
    const results = await Promise.allSettled(CORE.map(path => cache.add(path)));
    const failed = results.map((result,index)=>result.status==='rejected'?CORE[index]:null).filter(Boolean);
    if (failed.length) console.warn('LOCAL MARS: optional offline assets skipped:', failed);
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
    let timeoutId;
    const controller = request.mode === "navigate" ? new AbortController() : null;
    try {
      const options = { cache: "no-store" };
      if (controller) {
        options.signal = controller.signal;
        timeoutId = setTimeout(() => controller.abort(), 4500);
      }
      const fresh = await fetch(request, options);
      if (fresh.ok) {
        const cache = await caches.open(CACHE);
        await cache.put(request, fresh.clone());
      }
      return fresh;
    } catch (error) {
      const cached = await caches.match(request);
      if (cached) return cached;
      if (request.mode === "navigate") {
        return (await caches.match("./index.html")) || Response.error();
      }
      return Response.error();
    } finally {
      if (timeoutId) clearTimeout(timeoutId);
    }
  })());
});
