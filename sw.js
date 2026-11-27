const CACHE_NAME="orbit-shell-v1";
const CORE=["/","/manifest.json","/icon.svg"];
self.addEventListener("install",event=>{event.waitUntil(caches.open(CACHE_NAME).then(c=>c.addAll(CORE)).then(()=>self.skipWaiting()))});
self.addEventListener("activate",event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE_NAME).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener("fetch",event=>{if(event.request.method!=="GET"||new URL(event.request.url).origin!==self.location.origin)return;event.respondWith(fetch(event.request).then(res=>{if(res.ok){const copy=res.clone();caches.open(CACHE_NAME).then(c=>c.put(event.request,copy))}return res}).catch(()=>caches.match(event.request).then(r=>r||caches.match("/"))))});
self.addEventListener("notificationclick",event=>{event.notification.close();event.waitUntil(clients.matchAll({type:"window",includeUncontrolled:true}).then(list=>{for(const c of list){if("focus" in c)return c.focus()}return clients.openWindow("/") }))});

self.addEventListener('push',event=>{let data={};try{data=event.data?.json()||{}}catch(_){data={body:event.data?.text()}}event.waitUntil(self.registration.showNotification(data.title||'hello', {body:data.body||'New message',icon:'/icon.svg',data:{url:data.url||'/'},vibrate:[120,60,120]}));});
self.addEventListener('notificationclick',event=>{event.notification.close();const url=event.notification.data?.url||'/';event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(list=>{for(const c of list){if('focus' in c){c.navigate(url);return c.focus()}}return clients.openWindow(url)}));});
