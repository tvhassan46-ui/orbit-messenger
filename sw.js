const CACHE_NAME="orbit-shell-v2";
const CORE=["/","/manifest.json","/icon.svg"];
self.addEventListener("install",event=>{event.waitUntil(caches.open(CACHE_NAME).then(c=>c.addAll(CORE)).then(()=>self.skipWaiting()))});
self.addEventListener("activate",event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE_NAME).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
// Network first. API responses are never cached; only page loads fall back to the cached app shell.
self.addEventListener("fetch",event=>{const url=new URL(event.request.url);if(event.request.method!=="GET"||url.origin!==self.location.origin||url.pathname.startsWith("/api/"))return;event.respondWith(fetch(event.request).then(res=>{if(res.ok){const copy=res.clone();caches.open(CACHE_NAME).then(c=>c.put(event.request,copy))}return res}).catch(async()=>(await caches.match(event.request))||(event.request.mode==="navigate"&&(await caches.match("/")))||Response.error()))});

self.addEventListener('push',event=>{let data={};try{data=event.data?.json()||{}}catch(_){data={body:event.data?.text()}}event.waitUntil(self.registration.showNotification(data.title||'hello', {body:data.body||'New message',icon:'/icon.svg',tag:data.tag,data:{url:data.url||'/' ,conversation_id:data.conversation_id||null},vibrate:[120,60,120]}));});
self.addEventListener('notificationclick',event=>{event.notification.close();const data=event.notification.data||{};const url=data.url||'/';event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(async list=>{const open=list.find(c=>'focus' in c);if(open){if('navigate' in open)await open.navigate(url);return open.focus()}return clients.openWindow(url)}));});
