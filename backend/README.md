# Midtrans Backend (Railway)

Backend ini terhubung ke domain produksi **https://arenasports.up.railway.app** (disamakan dengan domain Flutter di `lib/config/api_config.dart`), jadi Midtrans **tidak perlu berjalan di localhost** lagi.

## Variabel lingkungan (diatur di dashboard Railway)

Masuk ke project Railway → tab **Variables**, lalu isi:

| Variabel | Contoh | Keterangan |
|---|---|---|
| `PORT` | `3000` | Port yang dipakai Railway |
| `APP_BASE_URL` | `https://arenasports.up.railway.app` | Domain backend; dipakai sebagai `finish_url` Midtrans setelah pembayaran |
| `MIDTRANS_IS_PRODUCTION` | `false` | `false` = Sandbox, `true` = Production |
| `MIDTRANS_SERVER_KEY` | `SB-Mid-server-...` | **Server Key** dari Midtrans Dashboard (Settings > Access Keys). Jangan masukkan ke Flutter atau Git. |

Untuk transaksi production nyata, ganti Server Key dengan **Production Server Key** dan atur `MIDTRANS_IS_PRODUCTION=true`.

## Deploy ke Railway

1. Push kode ke GitHub (folder `backend` ikut ter-upload).
2. Di Railway: **New Project** → **Deploy from GitHub repo** → pilih repo ini.
3. Saat Railway deteksi monorepo, atur:
   - **Build Command**: `cd backend && npm install`
   - **Start Command**: `cd backend && npm start`
   - At tambahkan file `railway.toml` di root jika diperlukan.
4. Tambahkan variabel lingkungan di atas pada tab Railway **Variables**.
5. Buka `https://arenasports.up.railway.app/health` — harus menampilkan:

```json
{
  "ok": true,
  "environment": "sandbox",
  "baseUrl": "https://arenasports.up.railway.app",
  "midtransConfigured": true
}
```

## Endpoint yang digunakan aplikasi Flutter

- `POST /api/payments/snap` — membuat Snap transaction, response berisi `orderId`, `token`, dan `redirectUrl`.
- `GET /api/payments/:orderId/status` — memeriksa status pembayaran (digunakan saat mengecek di `PaymentScreen`).
- `GET /health` — cek kesiapan Midtrans.

Flutter sudah mengatur `apiBaseUrl` ke `https://arenasports.up.railway.app/api`, jadi **tidak perlu** `flutter run --dart-define=API_BASE_URL=...` lagi.

Catatan: `.env` berada di `.gitignore` dan **tidak** di-commit; nilai sebenarnya diatur di dashboard Railway.
