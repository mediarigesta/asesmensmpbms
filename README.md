# Panduan Integrasi PWA - BM Exam

## File yang Dihasilkan

```
web/
├── index.html          ← Gantikan file index.html yang ada
├── manifest.json       ← File baru: Web App Manifest
├── sw.js               ← File baru: Service Worker
└── offline.html        ← File baru: Halaman offline fallback
```

## Cara Integrasi

### 1. Copy semua file ke folder `web/` proyek Flutter kamu

```bash
cp index.html  /path/to/your/flutter-project/web/index.html
cp manifest.json  /path/to/your/flutter-project/web/manifest.json
cp sw.js  /path/to/your/flutter-project/web/sw.js
cp offline.html  /path/to/your/flutter-project/web/offline.html
```

### 2. Pastikan icons sudah ada

Folder `web/icons/` harus berisi:
- `Icon-192.png` (192×192 px)
- `Icon-512.png` (512×512 px)
- `Icon-maskable-192.png` (192×192 px, dengan safe zone)
- `Icon-maskable-512.png` (512×512 px, dengan safe zone)

Flutter biasanya sudah men-generate icons ini. Jika belum, jalankan:
```bash
flutter pub add flutter_launcher_icons
# Edit pubspec.yaml dengan icon path, lalu:
flutter pub run flutter_launcher_icons
```

### 3. Build Flutter Web

```bash
flutter build web --release
```

### 4. Deploy

File `sw.js` dan `manifest.json` **harus** disajikan dari root domain (misalnya `https://exam.bmschool.id/sw.js`), bukan dari subfolder.

Jika deploy di subfolder, update `scope` dan `start_url` di `manifest.json`:
```json
{
  "start_url": "/subfolder/",
  "scope": "/subfolder/"
}
```

---

## Fitur PWA yang Ditambahkan

### ✅ Web App Manifest
- Nama app, ikon, tema warna
- Mode `standalone` (tampak seperti app native)
- Dukungan shortcut dan screenshot

### ✅ Service Worker (`sw.js`)
- **Cache-first** untuk Flutter app shell (JS, CSS, fonts)
- **Network-first** untuk navigasi dan data
- **Halaman offline** saat tidak ada koneksi
- **Background sync** (siap untuk submit jawaban saat offline)
- **Push notification** (siap untuk notifikasi jadwal ujian)
- Firebase requests **tidak** di-cache (selalu online untuk data real-time)

### ✅ Install Prompt
- Banner install otomatis muncul setelah 3 detik
- User bisa dismiss dan tidak muncul lagi
- Tracking status install (`appinstalled` event)

### ✅ Offline Indicator
- Banner merah muncul otomatis saat koneksi terputus
- Hilang otomatis saat koneksi kembali

### ✅ Splash Screen
- Loading screen custom saat Flutter pertama kali load
- Transisi halus ke app Flutter

---

## Catatan Penting

### Firebase & Anti-Kecurangan
- Semua request ke Firebase (Firestore, Auth) **dilewati** oleh service worker
- Fitur kamera, kiosk mode, dan anti-kecurangan **tidak berubah**
- PWA di web tetap menggunakan stub (non-fungsional) untuk fitur Android-only

### Limitasi PWA vs Native
| Fitur | Android Native | PWA (Web) |
|-------|---------------|-----------|
| Kiosk Mode | ✅ Screen pinning | ❌ Tidak didukung |
| Camera | ✅ Native | ✅ via WebRTC |
| Battery Monitor | ✅ | ⚠️ Battery API (terbatas) |
| Keyboard Blocking | ✅ Windows only | ❌ Tidak bisa |
| Install ke HP | ✅ APK | ✅ Add to Home Screen |
| Offline | ✅ | ✅ App shell saja |

### Update Cache
Setiap update aplikasi, update nilai `CACHE_VERSION` di `sw.js`:
```js
const CACHE_VERSION = 'bm-exam-v1.0.1'; // Increment versi
```

---

## Testing PWA

1. Buka Chrome DevTools → Application → Service Workers
2. Cek manifest di Application → Manifest
3. Test offline di Application → Service Workers → Offline checkbox
4. Lighthouse audit untuk skor PWA
