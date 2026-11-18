# ARENASPORTS Mobile

Aplikasi Flutter untuk pengguna **ARENASPORTS** yang terhubung langsung ke backend
Laravel (`C:\xampp\htdocs\ARENASPORTS_WEB`). Seluruh data (venue, lapangan, jadwal,
booking, pembayaran, tiket, review, open match, chat, poin/reward, notifikasi,
profil, dan pengajuan venue) dibaca dari MySQL melalui REST API, bukan lagi data
demo lokal.

## Fitur (role user)

- **Auth**: login email/no. HP, register, login Google (Firebase ID token),
  OTP WhatsApp, lupa password, ubah password, logout.
- **Venue & lapangan**: daftar venue dengan filter olahraga, pencarian, layar
  **Venue Terdekat** berbasis GPS (urut jarak, galeri semua foto, fasilitas,
  rating), serta detail venue (galeri layar penuh, fasilitas, rating, dan daftar
  ulasan pemain seperti di web).
- **Jadwal & booking**: ketersediaan slot per tanggal, slot harus berurutan
  (maksimal 8 jam), pembayaran Midtrans atau Cash, tiket dengan QR, riwayat
  booking dengan foto venue, perpanjangan, dan review wajib komentar.
- **Open match**: buat event dari booking aktif, gabung/keluar, dan chat grup
  dengan lampiran gambar.
- **Poin & reward**: saldo poin, daftar reward, penukaran dengan kode/QR, dan
  riwayat penukaran.
- **Notifikasi**: daftar, tandai dibaca, hapus, dan hapus semua.
- **Profil**: ubah nama/email/telepon/foto profil, hapus foto, statistik booking.
- **Pengajuan venue**: form lengkap dengan unggah dokumen dan foto lapangan,
  status pengajuan, catatan Superadmin, serta riwayat pengajuan.
- **Chatbot**: asisten virtual berbasis API, opsional memakai lokasi untuk venue
  terdekat.

## Konfigurasi API

Base URL diatur di `lib/config/api_config.dart`. Secara default aplikasi
terhubung ke backend produksi (Railway) yang sama dengan versi web:

| Target | URL default |
| --- | --- |
| Android / iOS / desktop / web | `https://arenasports.up.railway.app/api` |

Untuk memakai backend lokal saat pengembangan, override saat menjalankan
aplikasi:

```bash
# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# iOS simulator / desktop
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000

# Perangkat fisik (IP LAN komputer server)
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

`API_BASE_URL` diisi alamat root server (tanpa `/api`, karena aplikasi
menambahkan `/api` otomatis; akhiran `/api` tetap ditoleransi). Di build
release tanpa `--dart-define`, aplikasi otomatis memakai server Railway.

## Menjalankan backend

```bash
cd C:\xampp\htdocs\ARENASPORTS_WEB
php artisan migrate
php -S 0.0.0.0:8000 -t public resources\dev-server.php
```

Health check: `GET /api/health`.

> **Penting (Flutter Web/Chrome):** jangan pakai `php artisan serve` bila
> ingin menguji aplikasi di browser. Server bawaan itu tidak mengirim header
> `Access-Control-Allow-Origin` untuk file gambar statis, sehingga renderer
> CanvasKit tidak dapat meng-cat gambar lintas-asal dan seluruh gambar di
> aplikasi tidak tampil di Chrome/Edge. `resources/dev-server.php` men-stream
> file statis dengan header CORS (gambar tetap tampil di Android/iOS yang
> tidak membutuhkan CORS). API (`/api/*`) tetap berjalan seperti biasa.

Catatan konfigurasi backend di `.env`:

- `MIDTRANS_SERVER_KEY` / `MIDTRANS_CLIENT_KEY` wajib diisi agar pembayaran
  Midtrans aktif. Tanpa itu booking **Cash** tetap dapat dibuat (status
  `Menunggu` sampai dikonfirmasi Admin Venue).
- `FONNTE_TOKEN` wajib diisi agar OTP WhatsApp terkirim.
- `FIREBASE_API_KEY` dipakai untuk verifikasi ID token login Google.

### Deploy backend ke Railway (wajib untuk mobile)

Backend produksi harus menjalankan migrasi dan menyajikan folder storage.
Kedua hal ini sudah disiapkan di repo web:

- `Dockerfile` menjalankan `php artisan migrate --force` (termasuk tabel
  `api_tokens` yang dibutuhkan login/token mobile) dan `php artisan storage:link`
  setiap container start.
- `docker/nginx.conf` menyajikan `/storage/*` langsung dari
  `/var/www/html/storage/app/public`, sehingga foto unggahan tetap tampil
  meskipun symlink belum dibuat.

Agar foto yang diunggah pengguna **tidak hilang setiap redeploy**, pasang
Railway Volume dan mount ke `/var/www/html/storage/app/public` melalui menu
Railway → service backend → **Volumes**.

Setelah deploy, cek:

```bash
curl https://arenasports.up.railway.app/api/health
curl -I https://arenasports.up.railway.app/storage/venues/<nama-file>.jpg
```

Foto profil dan foto venue berasal dari endpoint `/storage/...`; jika URL ini
404, foto tidak akan muncul di aplikasi meskipun API lain berjalan. Foto lama
yang sudah terlanjur hilang karena redeploy perlu diunggah ulang setelah
backend diperbaiki.

## Struktur penting

- `lib/services/api_client.dart` — klien HTTP Bearer token + envelope
  `{success, message, data, errors}`.
- `lib/services/api_service.dart` — seluruh endpoint API role user.
- `lib/services/session_service.dart` — token & data user di `SharedPreferences`.
- `lib/services/auth_api.dart` — login/register/Google/OTP/ubah password.
- `lib/services/match_api.dart` — open match & chat.
- `lib/widgets/user_avatar.dart` — avatar profil (foto/ inisial) yang tahan
  terhadap URL kosong atau foto gagal dimuat.
- `lib/models/` — `FieldModel`, `CourtModel`, `BookingModel`, `MatchModel`,
  `NotificationModel`.

## Pengujian

```bash
flutter analyze
flutter test
```
