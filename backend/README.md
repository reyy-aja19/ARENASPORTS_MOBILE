# Midtrans Sandbox Backend

Backend ini hanya menggunakan environment Sandbox dan menyimpan Server Key di server.

## Menjalankan

1. Jalankan `npm install` di folder `backend`.
2. Salin `.env.example` menjadi `.env`.
3. Ambil **Server Key** dari menu Settings > Access Keys pada dashboard Sandbox, lalu isi `MIDTRANS_SERVER_KEY` di `.env`. Jangan masukkan key tersebut ke Flutter, chat, atau Git.
4. Jalankan `npm start`.
5. Pastikan `http://localhost:3000/health` menampilkan `midtransConfigured: true`.

Untuk HP fisik, HP dan komputer harus berada pada jaringan Wi-Fi yang sama. Jalankan Flutter dengan alamat LAN komputer, misalnya:

```powershell
flutter run --dart-define=MIDTRANS_API_BASE_URL=http://192.168.1.14:3000
```

Alamat LAN komputer dapat berbeda. Izinkan koneksi masuk ke port `3000` pada Windows Firewall jika diminta.

Endpoint yang digunakan aplikasi:

- `POST /api/payments/snap` untuk membuat Snap transaction dan memperoleh redirect URL.
- `GET /api/payments/:orderId/status` untuk memverifikasi status pembayaran melalui Midtrans sebelum booking disimpan.

Jangan gunakan konfigurasi ini untuk transaksi production. Backend ini menerima nominal dari aplikasi dan hanya ditujukan untuk pengujian Sandbox; untuk production, nominal harus dihitung dan diverifikasi oleh backend dari data booking tepercaya.