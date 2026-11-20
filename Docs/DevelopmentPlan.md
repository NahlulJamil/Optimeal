# 1. DEVELOPMENT PLAN

**Versi:** 1.7

**Mengacu pada:** PRD Optimeal v1.7

Pengembangan dilakukan oleh tiga developer dengan pembagian tanggung jawab berdasarkan modul.

## Prinsip Pengembangan

1. **Nol biaya, nol kartu:** seluruh layanan wajib free tier tanpa billing account. Dilarang mengaktifkan Blaze, Cloud Storage, Cloud Functions, atau layanan berbayar lain.
2. **Contract-first:** model data dan kontrak endpoint backend ditetapkan sebelum UI dikerjakan, agar ketiga developer dapat bekerja paralel.
3. **Mock-first:** setiap developer memakai data dummy (fixture JSON) sampai backend/AI siap, sehingga tidak ada yang menunggu.
4. **Proxy terpusat:** seluruh panggilan Gemini melalui Cloudflare Workers; tidak ada API key di aplikasi client.
5. **Offline-aware:** setiap fitur harus didefinisikan perilakunya saat online dan offline sejak awal, bukan ditambahkan di akhir.
6. **Satu sumber data:** Pantry adalah sumber data tunggal untuk Recipe Finder dan Smart Notification.
7. **AI mengikuti dokumen:** seluruh keluaran AI (kode maupun desain) wajib mengikuti PRD dan Development Plan ini, serta desain resmi di Figma. Ketentuan lengkap ada pada **PRD Bagian 13**.
8. **Design-driven:** implementasi UI wajib mengikuti file Figma "Balomba" (page *HiFi Optimeal*) — layout, komponen, spacing, warna, tipografi, dan teks. Tidak ada desain baru tanpa persetujuan tim.

9. **Branch per fitur:** setiap fitur dikerjakan di branch baru yang dibuat dari `main` terbaru (pull dahulu), di-push, lalu di-merge ke `main` dan `main` di-push. Ketentuan lengkap ada pada **PRD Bagian 13.7**.

---

## Developer 1 — Core Application, Backend & Integrasi

Tanggung jawab:

- Setup project Flutter dan struktur folder/arsitektur.
- Setup Firebase project pada **plan Spark** (Authentication + Cloud Firestore). **Tidak mengaktifkan Blaze.**
- Menulis **Firestore Security Rules**.
- Membuat dan men-deploy **Cloudflare Worker** sebagai proxy Gemini:
  - endpoint `POST /analyze-food`
  - endpoint `POST /analyze-barcode`
  - endpoint `POST /generate-recipes`
  - menyimpan API key sebagai secret
  - memvalidasi Firebase ID token
- Menetapkan kontrak data bersama (model `FoodItem`, `Recipe`, `Notification`, `FavoriteRecipe`).
- Implementasi authentication dan manajemen sesi.
- Home / Dashboard (termasuk banner pengingat dan indikator mode offline).
- Profile & Settings.
- Layer offline: cache lokal Firestore, snapshot Pantry, deteksi konektivitas, status sinkronisasi.
- **Penyimpanan foto lokal**: direktori file, kompresi thumbnail, pemetaan `foodId → path`, pembersihan saat logout.
- Navigasi, komponen UI bersama, tema (termasuk **Dark Mode**), lokalisasi **English/Indonesia**, dan bundling asset ilustrasi resep.
- Integrasi modul dan pengujian aplikasi secara keseluruhan.

Catatan: kepemilikan Worker, Security Rules, dan asset ilustrasi **wajib** ada di satu orang agar tidak menjadi pekerjaan yang tidak bertuan.

---

## Developer 2 — Food Scanner, Pantry & Smart Notification

Tanggung jawab:

- Implementasi akses kamera dan galeri.
- Implementasi layar **Scanner** dengan dua mode: **Scan Food** dan **Barcode** (foto diambil di dalam aplikasi dengan `camera`, barcode dibaca dengan `mobile_scanner`).
- Kompresi gambar sebelum dikirim ke proxy AI.
- Integrasi endpoint `analyze-food` dan `analyze-barcode`.
- Halaman hasil scan (nama, kategori, kondisi visual, catatan AI, estimasi masa simpan per lokasi).
- Form informasi bahan makanan (jumlah opsional, lokasi penyimpanan, tanggal pembelian).
- Perhitungan `estimatedEndDate` dan pemilihan `shelfLifeDays` sesuai lokasi penyimpanan.
- Penyimpanan foto bahan ke penyimpanan lokal setelah berhasil disimpan.
- Pantry / Inventory: daftar, detail, tambah manual, hapus, dan **Edit food details** (nama, kategori, lokasi penyimpanan, jumlah, tanggal pembelian, estimasi masa simpan).
- Pencarian, filter kategori, dan pengurutan berdasarkan masa simpan terdekat.
- Smart Notification: penjadwalan notifikasi lokal (H-ambang dan H-0), aturan penggabungan (maks 3 individual + 1 ringkasan), pembatalan, penjadwalan ulang, dan deep link ke detail bahan.
- Validasi hasil AI di sisi client dan penanganan error/timeout.
- Penonaktifan fitur tulis saat offline.

---

## Developer 3 — Recipe Finder & Resep Favorit

Tanggung jawab:

- Halaman Recipe Finder.
- Integrasi data bahan makanan dari Pantry.
- Filter lokasi penyimpanan bahan (`room_temperature`/`fridge`/`freezer`, label UI Pantry/Fridge/Freezer), filter cuisine, dan pemilihan bahan tertentu.
- Integrasi endpoint `generate-recipes`.
- Halaman daftar rekomendasi dan detail resep (bahan, peralatan, teknik memasak, langkah).
- Pemilihan ilustrasi lokal berdasarkan cuisine/kategori.
- Penanganan cache resep (10 resep/pengguna, TTL 7 hari) dan pesan saat kuota generate tercapai.
- Fitur Resep Favorit: tambah/hapus, tab Favorit pada halaman Recipe Finder, akses offline dari snapshot lokal.
- Aksi **hapus resep** pada halaman detail (dengan dialog konfirmasi), termasuk pembersihan cache dan favorit terkait.
- Empty state dan error state untuk seluruh halaman resep.

---

## Tahapan Pengembangan

**Tahap 0 — Kontrak & Fondasi (blocking)**

- Menyepakati model data final (`FoodItem`, `Recipe`, `Notification`, `FavoriteRecipe`).
- Menyepakati kontrak endpoint Cloudflare Worker (input/output/error).
- Menyiapkan fixture JSON untuk mock data.
- Menetapkan struktur folder dan aturan penamaan.
- Menyepakati daftar asset ilustrasi resep yang akan dibundel.

**Tahap 1 — Project Setup**

- Menyiapkan repository GitHub (aplikasi + kode Worker).
- Membuat struktur project Flutter dan arsitektur.
- Menyiapkan Firebase project **plan Spark** (Auth + Firestore) dan Security Rules.
- Menyiapkan akun Cloudflare, deploy Worker, simpan secret API key.
- Memastikan **tidak ada layanan yang meminta billing account**.
- Menyiapkan fixture data demo.

**Tahap 2 — UI Implementation**

- Mengimplementasikan desain Hi-Fi dari **Figma "Balomba"** — file `pOXPl58allJ59pllX36p8O`, page **HiFi Optimeal** (`293:2`).
- Wajib mengikuti desain apa adanya: layout, komponen, spacing, warna, tipografi, dan teks (bahasa Inggris).
- Membuat komponen UI yang dapat digunakan ulang.
- Mengimplementasikan navigasi antarhalaman dan deep link notifikasi.
- Implementasi state loading, empty, error, dan offline pada seluruh layar.

**Tahap 3 — Feature Development**

- Authentication (Dev 1).
- Food Scanner dan Pantry (Dev 2).
- Smart Notification lokal (Dev 2).
- Recipe Finder dan Resep Favorit (Dev 3).
- Home, Profile, layer offline, penyimpanan foto lokal (Dev 1).

**Tahap 4 — Integration**

- Mengintegrasikan hasil scan dengan Pantry.
- Mengintegrasikan Pantry dengan Recipe Finder.
- Mengintegrasikan data masa simpan dengan Smart Notification.
- Mengintegrasikan snapshot lokal untuk mode offline dan resep favorit.
- Mengintegrasikan seluruh modul ke aplikasi utama.

**Tahap 5 — Testing & Evaluation**

- Pengujian setiap fitur.
- Pengujian integrasi antarfitur.
- Pengujian validasi data.
- Pengujian performa dan penanganan error.
- **Pengujian offline:** menyalakan mode pesawat, memastikan Pantry & favorit terbuka, tombol tulis nonaktif, dan notifikasi lokal tetap muncul.
- **Pengujian kuota free tier:** memastikan rate limit aplikasi bekerja dan tidak menghabiskan kuota Gemini.
- Pengujian notifikasi pada perangkat fisik (izin notifikasi, exact alarm, setelah reboot).
- Perbaikan bug berdasarkan hasil pengujian.

**Tahap 6 — Demo Readiness**

- Menyiapkan data demo (akun, bahan dengan tanggal dimundurkan agar notifikasi muncul).
- Menyiapkan fallback jika koneksi di lokasi demo buruk (resep favorit & cache sudah terisi).
- Menyiapkan mock mode untuk berjaga-jaga bila kuota Gemini habis.
- Menyiapkan alur demo utama berdurasi ±5 menit.

---

## Kontrak Cloudflare Worker

Base URL contoh: `https://optimeal-ai.<subdomain>.workers.dev`

Header wajib pada setiap request:

```
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json
```

### 1. `POST /analyze-food`

Input:

```
{
  imageBase64: string,
  mimeType: string
}
```

Output sukses:

```
{
  name: string,
  category: string,
  confidence: number,            // 0..1
  visualCondition: string,       // bentuk, warna, karakteristik
  aiNote: string | null,         // mis. "warnanya sudah menguning"
  shelfLifeDays: {
    room_temperature: number,
    fridge: number,
    freezer: number
  }
}
```

Error: `400` input tidak valid, `401` token tidak valid, `429` rate limit/kuota AI, `500` kegagalan layanan AI, `504` timeout.

### 2. `POST /analyze-barcode`

Input:

```
{
  barcode: string
}
```

Output sukses:

```
{
  name: string,
  category: string,
  brand: string | null,
  packageSize: string | null,
  confidence: number,            // 0..1
  shelfLifeDays: {
    room_temperature: number,
    fridge: number,
    freezer: number
  }
}
```

Error: `400` barcode tidak valid, `401` token tidak valid, `404` produk tidak dikenali, `429` rate limit/kuota AI, `500` kegagalan layanan, `504` timeout.

### 3. `POST /generate-recipes`

Input:

```
{
  ingredients: [ { name: string, quantity: number | null, unit: string | null, storageLocation: string } ],
  filters: { cuisine: string | null },
  excludeRecipeIds: [ string ]
}
```

Output sukses:

```
{
  recipes: [
    {
      recipeId: string,
      name: string,
      description: string,
      cuisine: string,
      cookingTechnique: string,
      cookingTimeMinutes: number,
      ingredientsAvailable: [ string ],
      ingredientsMissing: [ string ],
      equipment: [ string ],
      steps: [ string ]
    }
  ]
}
```

Error: sama seperti di atas, ditambah `422` bila daftar bahan kosong.

**Ketentuan Worker:**

- API key Gemini **hanya** ada di secret Worker, tidak pernah dikirim ke client.
- Worker memverifikasi Firebase ID token sebelum memproses permintaan.
- Worker tidak menyimpan gambar maupun hasil analisis.
- Worker mengembalikan pesan error yang aman (tanpa detail internal).
- Kode Worker disimpan di repository dan dapat di-deploy ulang oleh Developer 1.

---

## Definisi Selesai (Definition of Done)

Sebuah fitur dianggap selesai apabila:

1. Berjalan dengan data nyata dari backend/proxy (bukan mock).
2. Memiliki state loading, empty, error, dan offline.
3. Memiliki validasi input dan pesan kesalahan yang jelas.
4. Tidak membocorkan API key atau data pengguna lain.
5. Tidak menambah layanan berbayar atau yang memerlukan billing account.
6. Lulus pengujian manual pada perangkat Android fisik.
7. Diuji pada kondisi koneksi lambat dan offline.

---

## Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Kuota free tier Gemini habis saat pengujian bersama | Fitur AI tidak bisa diuji | Cache resep, rate limit per pengguna, API key pengembangan terpisah, mock mode. |
| Cloudflare Workers free plan memiliki batas | Proxy berhenti melayani | Pantau penggunaan, kurangi ukuran gambar, gunakan cache. |
| Worker terlambat selesai | Scanner & Recipe terblokir | Mock-first dengan fixture JSON; Worker diselesaikan di Tahap 1. |
| Koneksi buruk saat demo | Demo gagal | Isi cache & favorit sebelum demo, siapkan mode offline. |
| Notifikasi lokal tidak muncul | Acceptance criteria gagal | Uji pada perangkat fisik, minta izin notifikasi & exact alarm, uji setelah reboot. |
| Estimasi masa simpan AI tidak akurat | Data Pantry menyesatkan | Katalog cadangan + disclaimer bahwa estimasi bukan jaminan. |
| Foto lokal hilang saat aplikasi dihapus | Riwayat foto hilang | Diterima sebagai konsekuensi arsitektur nol biaya; data teks tetap aman di Firestore. |
| Konflik merge antar developer | Pekerjaan terhambat | Struktur feature-first, satu modul satu pemilik, kontrak data disepakati di Tahap 0. |

---

## Matriks Pengujian Offline

| Skenario | Ekspektasi |
|---|---|
| Buka aplikasi tanpa koneksi, sesi masih aktif | Masuk ke Home, banner "Mode Offline" tampil. |
| Buka Pantry saat offline | Daftar & detail tampil dari cache, foto lokal tetap muncul. |
| Tekan tombol Scan saat offline | Tombol nonaktif + pesan bahwa scan butuh internet. |
| Pilih mode Barcode saat offline | Tombol nonaktif + pesan bahwa barcode butuh internet. |
| Buka Edit food details saat offline | Tombol simpan nonaktif + pesan bahwa perubahan data butuh internet. |
| Ubah Dark Mode / Language saat offline | Tetap berfungsi dan tersimpan lokal. |
| Tekan "Tambah Bahan" saat offline | Tombol nonaktif + pesan. |
| Buka tab Favorit saat offline | Daftar favorit & detail resep tampil lengkap dengan ilustrasi lokal. |
| Generate resep saat offline | Tombol nonaktif + pesan. |
| Tunggu jadwal notifikasi saat offline | Notifikasi lokal muncul dan membuka detail bahan. |
| Lebih dari 3 bahan jatuh tempo bersamaan | Muncul maksimal 3 notifikasi + 1 ringkasan. |
| Koneksi kembali | Status sinkronisasi berubah, seluruh tombol aktif kembali. |

---

## Checklist Bebas Biaya

Periksa sebelum demo:

- [ ] Firebase project masih pada plan **Spark**.
- [ ] Tidak ada Cloud Storage bucket yang aktif dipakai aplikasi.
- [ ] Tidak ada Cloud Functions yang ter-deploy.
- [ ] Tidak ada billing account yang terhubung ke project.
- [ ] API key Gemini hanya ada di secret Cloudflare Worker.
- [ ] Penggunaan Gemini masih dalam batas free tier.
- [ ] Tidak ada dependensi ke layanan pihak ketiga berbayar.
