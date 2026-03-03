// BM Exam - Custom Service Worker
// Versi cache - update ini setiap kali ada perubahan assets
const CACHE_VERSION = 'bm-exam-v1.0.0';
const STATIC_CACHE = `${CACHE_VERSION}-static`;
const DYNAMIC_CACHE = `${CACHE_VERSION}-dynamic`;
const OFFLINE_URL = '/offline.html';

// Assets yang di-cache saat install (app shell)
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter.js',
  '/manifest.json',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/offline.html',
  // Flutter web assets
  '/assets/FontManifest.json',
  '/assets/AssetManifest.json',
];

// Install event: cache static assets
self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker...');
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      console.log('[SW] Caching static assets');
      // Gunakan addAll dengan error handling individual
      return Promise.allSettled(
        STATIC_ASSETS.map(url => 
          cache.add(url).catch(err => console.warn(`[SW] Failed to cache ${url}:`, err))
        )
      );
    }).then(() => {
      console.log('[SW] Static assets cached');
      return self.skipWaiting();
    })
  );
});

// Activate event: hapus cache lama
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter(name => name.startsWith('bm-exam-') && name !== STATIC_CACHE && name !== DYNAMIC_CACHE)
          .map(name => {
            console.log('[SW] Deleting old cache:', name);
            return caches.delete(name);
          })
      );
    }).then(() => {
      console.log('[SW] Service worker activated');
      return self.clients.claim();
    })
  );
});

// Fetch event: strategi cache-first untuk static, network-first untuk API
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') return;

  // Skip Chrome extensions dan requests lainnya
  if (!url.protocol.startsWith('http')) return;

  // Skip Firebase requests - selalu online
  if (url.hostname.includes('firestore.googleapis.com') ||
      url.hostname.includes('firebase.googleapis.com') ||
      url.hostname.includes('identitytoolkit.googleapis.com') ||
      url.hostname.includes('firebaseio.com') ||
      url.hostname.includes('googleapis.com')) {
    return;
  }

  // Strategi berdasarkan tipe request
  if (isStaticAsset(url)) {
    // Cache-first untuk static assets (Flutter app shell)
    event.respondWith(cacheFirst(request));
  } else if (isNavigationRequest(request)) {
    // Network-first untuk navigasi, fallback ke cache, lalu offline page
    event.respondWith(networkFirstNavigation(request));
  } else {
    // Network-first untuk request lainnya
    event.respondWith(networkFirst(request));
  }
});

// Helper: cek apakah ini static asset
function isStaticAsset(url) {
  return url.pathname.match(/\.(js|css|png|jpg|jpeg|gif|ico|woff|woff2|ttf|svg|json)$/) ||
         url.pathname.startsWith('/assets/') ||
         url.pathname.startsWith('/icons/') ||
         url.pathname === '/manifest.json';
}

// Helper: cek apakah ini navigation request
function isNavigationRequest(request) {
  return request.mode === 'navigate';
}

// Strategi Cache-First
async function cacheFirst(request) {
  try {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(STATIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.error('[SW] Cache-first failed:', error);
    return new Response('Offline', { status: 503 });
  }
}

// Strategi Network-First untuk navigasi
async function networkFirstNavigation(request) {
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.log('[SW] Network failed for navigation, trying cache...');
    const cachedResponse = await caches.match(request);
    if (cachedResponse) return cachedResponse;
    
    // Fallback ke index.html untuk Flutter routing
    const indexResponse = await caches.match('/index.html');
    if (indexResponse) return indexResponse;
    
    // Fallback ke halaman offline
    const offlineResponse = await caches.match(OFFLINE_URL);
    if (offlineResponse) return offlineResponse;
    
    return new Response('Anda sedang offline. Silakan periksa koneksi internet Anda.', {
      status: 503,
      headers: { 'Content-Type': 'text/html; charset=utf-8' }
    });
  }
}

// Strategi Network-First umum
async function networkFirst(request) {
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) return cachedResponse;
    throw error;
  }
}

// Push notification handler (untuk notifikasi ujian di masa mendatang)
self.addEventListener('push', (event) => {
  if (!event.data) return;
  
  try {
    const data = event.data.json();
    const options = {
      body: data.body || 'Ada notifikasi baru dari BM Exam',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      tag: data.tag || 'bm-exam-notification',
      data: data.url || '/',
      actions: [
        { action: 'open', title: 'Buka Aplikasi' },
        { action: 'dismiss', title: 'Tutup' }
      ],
      requireInteraction: data.requireInteraction || false,
    };
    
    event.waitUntil(
      self.registration.showNotification(data.title || 'BM Exam', options)
    );
  } catch (error) {
    console.error('[SW] Push notification error:', error);
  }
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  if (event.action === 'dismiss') return;
  
  const urlToOpen = event.notification.data || '/';
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // Cari window yang sudah terbuka
      for (const client of windowClients) {
        if (client.url === urlToOpen && 'focus' in client) {
          return client.focus();
        }
      }
      // Buka window baru jika tidak ada yang terbuka
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});

// Background sync untuk submit ujian saat offline
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-exam-submission') {
    console.log('[SW] Background sync: exam submission');
    event.waitUntil(syncExamSubmissions());
  }
});

async function syncExamSubmissions() {
  // Implementasi sync submission yang tertunda
  // Data submission disimpan di IndexedDB saat offline
  console.log('[SW] Syncing pending exam submissions...');
}
