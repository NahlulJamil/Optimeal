# Optimeal — Smart Food Management

Aplikasi mobile Android berbasis **Flutter** dan **Artificial Intelligence (AI)** untuk membantu pengguna mengelola persediaan bahan makanan secara praktis, memantau estimasi masa simpan, serta menghasilkan rekomendasi masakan dari bahan yang tersedia guna mengurangi *food waste*.

---

## Daftar Isi

- [Fitur Utama](#fitur-utama)
- [Arsitektur & Tech Stack (Zero-Cost)](#arsitektur--tech-stack-zero-cost)
- [Mode Operasi (Online & Offline)](#mode-operasi-online--offline)
- [Struktur Direktori](#struktur-direktori)
- [Persiapan & Cara Menjalankan](#persiapan--cara-menjalankan)
  - [1. Aplikasi Flutter](#1-aplikasi-flutter)
  - [2. Proxy AI (Cloudflare Worker)](#2-proxy-ai-cloudflare-worker)
- [Pengujian](#pengujian)
- [Dokumentasi Proyek](#dokumentasi-proyek)

---

## Fitur Utama

1. **Food Scanner (Scan Food & Barcode)**
   - **Scan Food:** Memotret bahan makanan langsung di dalam aplikasi (`camera`) atau memilih foto dari galeri (`image_picker`), mengompresi gambar (≤1024 px, ≤500 KB), lalu mengidentifikasi nama bahan, kategori, kondisi visual (*Condition*), catatan AI, dan estimasi masa simpan untuk tiga lokasi penyimpanan (**Pantry**, **Fridge**, **Freezer**).
   - **Barcode:** Memindai barcode kemasan produk (EAN/UPC maupun QR GS1 Digital Link) menggunakan `mobile_scanner`, mencocokkan data produk melalui katalog **Open Food Facts**, serta menentukan kategori dan estimasi masa simpan menggunakan AI.
2. **Pantry / Inventory**
   - Mengelola daftar persediaan bahan makanan yang diurutkan otomatis berdasarkan sisa estimasi masa simpan terdekat.
   - Mendukung pencarian nama bahan, filter lokasi penyimpanan (**Fridge**, **Pantry**, **Freezer**), filter kategori bahan, indikator status sinkronisasi (*Synced*, *Syncing*, *Offline*, *Could not sync*), tambah bahan manual, serta halaman **Edit food details**.
3. **Recipe Finder & Resep Favorit**
   - Menghasilkan rekomendasi resep masakan berdasarkan bahan yang tersedia di Pantry dengan filter lokasi penyimpanan, *cuisine*, dan pemilihan bahan spesifik.
   - Membuat ilustrasi foto masakan secara otomatis menggunakan **Cloudflare Workers AI** (`@cf/black-forest-labs/flux-1-schnell`) yang disimpan di perangkat lokal.
   - Menampilkan detail resep dalam tab **Ingredients**, **Equipment**, dan **Instructions**.
   - Menyimpan **Resep Favorit** sebagai snapshot lokal lengkap sehingga tetap dapat dibaca tanpa koneksi internet.
4. **Smart Notification**
   - Menjadwalkan pengingat lokal pada perangkat (`flutter_local_notifications`) pada **H-1** dan **H-0** sebelum estimasi akhir masa simpan bahan makanan.
   - Menggabungkan pengingat secara cerdas (maksimal 3 notifikasi individual + 1 notifikasi ringkasan per jadwal) untuk mencegah spam notifikasi, dilengkapi *deep link* menuju detail bahan di Pantry.
5. **Home, Authentication & Profile**
   - **Authentication:** Registrasi dengan persetujuan *Terms & Conditions* dan *Privacy Policy*, verifikasi akun via link email Firebase, login, serta reset kata sandi (*Forgot Password*).
   - **Home / Dashboard:** Ringkasan jumlah bahan per lokasi penyimpanan, banner peringatan bahan mendekati akhir masa simpan (*expiring soon*), bottom sheet pengingat, pratinjau 3 bahan terdekat di Pantry, dan 1 rekomendasi resep AI.
   - **Profile & Settings:** Pengelolaan **Profile Details** (Display Name, Full Name, Telephone), **Change Your Password**, toggle inline **Notifications**, halaman **Support**, **About**, serta **Logout** yang membersihkan data lokal perangkat.

---

## Arsitektur & Tech Stack (Zero-Cost)

Optimeal dirancang dengan prinsip **nol biaya dan tanpa billing account** (seluruh layanan berjalan di *free tier* tanpa kartu kredit):

| Komponen | Teknologi / Layanan | Keterangan |
|---|---|---|
| **Mobile Client** | Flutter (Dart `^3.14.0`), Riverpod | Tema terang (*Light Mode*), antarmuka berbahasa Inggris, tipografi **Inter** & **Lora**. |
| **Authentication** | Firebase Authentication (Spark Plan) | Email/Password, verifikasi email link, dan reset sandi. |
| **Database** | Cloud Firestore (Spark Plan) | Menyimpan profil pengguna, Pantry, cache resep, favorit, dan riwayat notifikasi dengan *offline persistence*. |
| **AI Proxy** | Cloudflare Workers (Free Plan) | Memverifikasi Firebase ID Token (JWKS) dan menyimpan `GEMINI_API_KEY` sebagai *secret* di sisi server. |
| **Vision & Recipe AI** | Google Gemini API (Free Tier) | Model utama `gemini-3.8-flash` dengan dukungan *fallback models* saat sibuk/kuota tercapai. |
| **Recipe Image AI** | Cloudflare Workers AI (Free Plan) | Model `@cf/black-forest-labs/flux-1-schnell` melalui binding `AI` untuk membuat gambar resep. |
| **Product Lookup** | Open Food Facts API | Katalog produk kemasan gratis untuk mode pemindaian Barcode. |
| **Local Storage** | Penyimpanan Perangkat (`path_provider`, `shared_preferences`) | Menyimpan foto bahan makanan, gambar resep, snapshot favorit, dan waktu sinkronisasi terakhir secara lokal. |

---

## Mode Operasi (Online & Offline)

| Kemampuan | Online | Offline |
|---|:---:|:---:|
| Melihat daftar & detail Pantry (termasuk foto lokal) | ✅ | ✅ (dari cache lokal) |
| Mencari & memfilter bahan di Pantry | ✅ | ✅ (berbasis cache lokal) |
| Membuka daftar & detail Resep Favorit | ✅ | ✅ (dari snapshot lokal) |
| Menerima notifikasi pengingat masa simpan | ✅ | ✅ (notifikasi lokal terjadwal) |
| Food Scanner (Scan Food & Barcode) | ✅ | ❌ (tombol nonaktif + pesan offline) |
| Menambah, mengubah, atau menghapus bahan Pantry | ✅ | ❌ (tombol nonaktif + pesan offline) |
| Generate rekomendasi resep & ubah favorit | ✅ | ❌ (tombol nonaktif + pesan offline) |
| Mengubah profil, kata sandi, & preferensi notifikasi | ✅ | ❌ (tombol nonaktif + pesan offline) |

---

## Struktur Direktori

```text
Optimeal/
├── android/                  # Konfigurasi platform Android & MainActivity
├── assets/
│   ├── fixtures/             # Data dummy JSON untuk mode mock & pengujian
│   ├── fonts/                # Font bundel lokal (Inter & Lora)
│   └── images/               # Aset gambar statis aplikasi
├── Docs/
│   ├── PRD.md                # Product Requirements Document
│   ├── DevelopmentPlan.md    # Rencana tahapan & pembagian modul tim
│   └── Contracts.md          # Kontrak skema data Firestore & endpoint Worker
├── lib/
│   ├── core/                 # Konfigurasi, konektivitas/sync, model utama, tema, widget bersama
│   ├── features/
│   │   ├── auth/             # Login, Register, Verify Email, Forgot Password, Legal Sheet
│   │   ├── home/             # Home Dashboard & ringkasan inventaris
│   │   ├── notification/     # Planner notifikasi lokal, service, banner expiring soon
│   │   ├── pantry/           # Daftar Pantry, detail bahan, form Add/Edit Food, penyimpanan foto lokal
│   │   ├── profile/          # Profile Hub, Profile Details, Password, Support, About, Logout
│   │   ├── recipes/          # Recipe Finder, detail resep, favorit, cache & kuota, gambar resep AI
│   │   └── scanner/          # Kamera in-app Scan Food, pemindai Barcode, kompresi gambar, klien AI
│   ├── firebase_options.dart # Konfigurasi Firebase platform
│   └── main.dart             # Entry point aplikasi, AuthGate, dan AppShell (bottom navigation)
├── test/                     # Unit test & widget test per modul fitur
├── worker/                   # Kode sumber Cloudflare Worker (proxy Gemini & Workers AI)
│   ├── src/index.ts          # Handler endpoint AI & verifikasi token Firebase
│   └── wrangler.jsonc        # Konfigurasi deployment Cloudflare Worker
├── firestore.rules           # Aturan keamanan Cloud Firestore berbasis UID pemilik
└── pubspec.yaml              # Dependensi & konfigurasi aset Flutter
```

---

## Persiapan & Cara Menjalankan

### 1. Aplikasi Flutter

Pastikan **Flutter SDK** sudah terpasang dan perangkat/emulator Android telah aktif.

```powershell
# Unduh dependensi
flutter pub get

# Jalankan dalam mode nyata (terhubung ke Firebase & Cloudflare Worker default)
flutter run

# Atau jalankan dengan URL Worker kustom
flutter run --dart-define=AI_PROXY_URL=https://optimeal-ai.optimeal.workers.dev

# Atau jalankan dalam Mode Mock (membaca fixture lokal tanpa kuota AI)
flutter run --dart-define=USE_MOCK=true
```

### 2. Proxy AI (Cloudflare Worker)

Kode proxy berada di folder [`worker/`](worker/README.md).

```powershell
cd worker
npm install

# Menjalankan secara lokal
copy .dev.vars.example .dev.vars
# Isi GEMINI_API_KEY di dalam file .dev.vars
npx wrangler dev

# Pemeriksaan tipe TypeScript
npm run typecheck

# Deploy ke Cloudflare Workers
npx wrangler login
npx wrangler secret put GEMINI_API_KEY
npx wrangler deploy
```

Endpoint yang dilayani oleh Worker (seluruhnya wajib menyertakan header `Authorization: Bearer <Firebase ID Token>`):
- `POST /analyze-food` — Identifikasi bahan makanan dari foto terkompresi.
- `POST /analyze-barcode` — Identifikasi produk kemasan dari kode barcode/GTIN.
- `POST /generate-recipes` — Rekomendasi 3 resep berdasarkan daftar bahan Pantry & filter *cuisine*.
- `POST /generate-recipe-image` — Pembuatan gambar resep menggunakan Cloudflare Workers AI.

---

## Pengujian

Seluruh pengujian widget dan unit otomatis berjalan dalam *mock mode* melalui `test/flutter_test_config.dart`:

```powershell
# Menjalankan seluruh unit & widget test Flutter
flutter test

# Analisis statis kode Dart
flutter analyze
```

---

## Dokumentasi Proyek

- [**PRD.md**](Docs/PRD.md) — Spesifikasi kebutuhan produk, alur pengguna, batasan kuota, dan aturan desain.
- [**DevelopmentPlan.md**](Docs/DevelopmentPlan.md) — Pembagian tanggung jawab 3 developer, tahapan pengembangan, dan matriks pengujian offline.
- [**Contracts.md**](Docs/Contracts.md) — Spesifikasi model data (`FoodItem`, `Recipe`, `FavoriteRecipe`, `NotificationRecord`, `UserProfile`) dan kontrak API Worker.
- [**worker/README.md**](worker/README.md) — Panduan khusus setup, pengujian, dan deployment Cloudflare Worker.
