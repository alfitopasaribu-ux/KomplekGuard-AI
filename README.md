# KomplekGuard AI

- `frontend/`: aplikasi Flutter.
- `backend/`: API Node.js/Express dan database Prisma.
- `app/` dan `components/`: halaman dan komponen web Next.js.

## Pratinjau dashboard warga

Jalankan dari folder root `C:\komplekguard-ai`:

```sh
npm install
npm run dev
```

Buka <http://localhost:3000/preview-v2>. Jika PowerShell memblokir `npm.ps1`, gunakan `npm.cmd install` dan `npm.cmd run dev`.

Pratinjau menggunakan data contoh. Tombol laporan, peta, profil, dan asisten menampilkan pemberitahuan; belum terhubung ke API.

Komponen utamanya berada di `components/komplekguard/ResidentDashboard.jsx`, dengan CSS di `resident-dashboard.css` pada folder yang sama.

Halaman profil web lama masih membutuhkan modul `lib/auth`, `lib/prisma`, dan dependensi `next-auth` sebelum build seluruh aplikasi dapat berhasil. Ini terpisah dari pratinjau `/preview-v2`.

Konfigurasi `vercel.json` saat ini menerbitkan backend Express. Menjalankan pratinjau lokal tidak mengubah konfigurasi deployment tersebut.
