// Caché de la app (no cachea las llamadas a Supabase: siempre van a la red)
const C = 'ventas-v20', F = ['./', './index.html', './admin.html', './parser.js', './manifest.json', './banner.jpg', './banner-wide.jpg', './logo.webp', './icon-192.png', './icon-512.png'];
self.addEventListener('install', e => e.waitUntil(caches.open(C).then(c => c.addAll(F))));
self.addEventListener('activate', e => e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== C).map(k => caches.delete(k))))));
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET' || e.request.url.includes('supabase.co')) return;
  e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
});
