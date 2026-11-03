const CACHE="mars-local-shell-v10";
const ASSETS=["./","./index.html","./manifest.webmanifest","./icon.svg"];
self.addEventListener("install",event=>{
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS)));
  self.skipWaiting();
});
self.addEventListener("activate",event=>{
  event.waitUntil((async()=>{
    const keys=await caches.keys();
    await Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key)));
    await self.clients.claim();
  })());
});
self.addEventListener("fetch",event=>{
  const request=event.request;
  const url=new URL(request.url);
  if(request.method!=="GET"||url.origin!==self.location.origin)return;
  event.respondWith((async()=>{
    const isPage=request.mode==="navigate"||url.pathname.endsWith("/index.html")||url.pathname.endsWith("/");
    if(isPage){
      try{
        const fresh=await fetch(request,{cache:"no-store"});
        if(fresh.ok){const cache=await caches.open(CACHE);await cache.put(request,fresh.clone());}
        return fresh;
      }catch(error){
        return (await caches.match(request))||(await caches.match("./index.html"));
      }
    }
    const cached=await caches.match(request);
    if(cached)return cached;
    try{
      const fresh=await fetch(request);
      if(fresh.ok){const cache=await caches.open(CACHE);await cache.put(request,fresh.clone());}
      return fresh;
    }catch(error){return Response.error();}
  })());
});
