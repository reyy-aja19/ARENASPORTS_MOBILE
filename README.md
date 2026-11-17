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

Base URL diatur di `lib/config/api_config.dart`:

| Target | URL default |
| --- | --- |
| Android emulator | `http://10.0.2.2:8000/api` |
| iOS/desktop | `http://127.0.0.1:8000/api` |

Nilai dapat dioverride saat menjalankan aplikasi:

```bash
# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8001

# iOS simulator / desktop
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

`API_BASE_URL` diisi alamat root server Laravel (tanpa `/api`, karena aplikasi
menambahkan `/api` otomatis). Untuk perangkat fisik gunakan IP LAN komputer
server, mis. `http://192.168.1.10:8000`.

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

## Struktur penting

- `lib/services/api_client.dart` — klien HTTP Bearer token + envelope
  `{success, message, data, errors}`.
- `lib/services/api_service.dart` — seluruh endpoint API role user.
- `lib/services/session_service.dart` — token & data user di `SharedPreferences`.
- `lib/services/auth_api.dart` — login/register/Google/OTP/ubah password.
- `lib/services/match_api.dart` — open match & chat.
- `lib/models/` — `FieldModel`, `CourtModel`, `BookingModel`, `MatchModel`,
  `NotificationModel`.

## Pengujian

```bash
flutter analyze
flutter test
```
