# PRODUCT REQUIREMENTS DOCUMENT (PRD)

# OPTIMEAL — SMART FOOD MANAGEMENT

**Versi:** 1.8

**Platform:** Mobile Application (Android)

**Tim Pengembangan:** 3 Developers

**Framework:** Flutter

**Terakhir diperbarui:** 20 November 2026

> **Catatan revisi:** Versi 1.2 menetapkan arsitektur **nol biaya tanpa billing account**. Versi 1.3 menambahkan **aturan penggunaan AI** pada **Bagian 13**. Versi 1.4 menyelaraskan PRD dengan desain **Figma "Balomba"** sebagai acuan visual dan fungsional (Scan Barcode, Dark Mode, Language, Edit food details, menu Profile lengkap, UI berbahasa Inggris). Versi 1.5 menambahkan **aturan alur kerja Git untuk AI** (branch per fitur, merge ke `main`, commit & push) pada **Bagian 13.7**. Versi 1.6 menambahkan pustaka **mobile_scanner** untuk mode Barcode (disetujui Developer 2). Versi 1.7 menambahkan pustaka **camera** agar mode Scan Food memotret langsung di dalam aplikasi. Versi 1.8 menetapkan **verifikasi akun melalui link email Firebase** (bukan OTP) pada Bagian 3.1. Daftar perubahan dan keputusan desain dapat dilihat pada **Bagian 12**.

---

# 1. PRODUCT OVERVIEW

## 1.1 Deskripsi Produk

Optimeal merupakan aplikasi Smart Food Management berbasis Artificial Intelligence (AI) yang dirancang untuk membantu pengguna mengelola persediaan bahan makanan secara lebih praktis dan efisien. Aplikasi ini memungkinkan pengguna memindai bahan makanan, menyimpan hasil pemindaian ke dalam inventaris digital (Pantry), memperoleh rekomendasi resep berdasarkan bahan makanan yang tersedia, serta menerima notifikasi mengenai bahan makanan yang mendekati estimasi akhir masa simpannya.

Optimeal dikembangkan untuk membantu mengurangi potensi food waste dengan mendorong pengguna memanfaatkan bahan makanan yang dimiliki sebelum mengalami kerusakan.

## 1.2 Latar Belakang Masalah

Pengelolaan persediaan bahan makanan sering kali masih dilakukan secara manual. Pengguna dapat mengalami kesulitan dalam memantau jumlah bahan makanan, mengingat masa simpan, dan menentukan bahan yang perlu diolah terlebih dahulu. Akibatnya, bahan makanan berisiko terlupakan, mengalami kerusakan, dan akhirnya terbuang.

Selain itu, pengguna terkadang kesulitan menentukan menu masakan berdasarkan bahan yang tersedia. Kondisi ini dapat menjadi tantangan bagi mahasiswa yang tinggal di kos, rumah tangga, maupun pelaku UMKM kuliner.

Optimeal hadir sebagai solusi digital yang mengintegrasikan teknologi AI untuk membantu pengelolaan persediaan dan pemanfaatan bahan makanan.

## 1.3 Tujuan Produk

1. Mempermudah pengguna dalam mengidentifikasi dan mencatat bahan makanan.
2. Membantu pengguna memantau persediaan bahan makanan melalui inventaris digital.
3. Memberikan rekomendasi resep berdasarkan bahan makanan yang tersedia.
4. Mengingatkan pengguna mengenai bahan makanan yang mendekati estimasi akhir masa simpan.
5. Mendorong pemanfaatan bahan makanan secara optimal untuk mengurangi potensi food waste.
6. Menyediakan akses cepat ke resep favorit, termasuk saat pengguna sedang offline.

## 1.4 Target Pengguna

- Mahasiswa atau anak kos yang memiliki keterbatasan waktu dan peralatan memasak.
- Ibu rumah tangga yang mengelola persediaan bahan makanan sehari-hari.
- Pelaku UMKM kuliner yang mengelola bahan baku untuk kebutuhan usaha.

---

# 2. PRODUCT SCOPE

## 2.1 Fitur Utama

Optimeal memiliki empat fitur utama:

1. **Food Scanner:** Memindai dan mengenali bahan makanan menggunakan AI, dengan dua mode: **Scan Food** (kamera/galeri) dan **Barcode** (barcode kemasan produk).
2. **Pantry / Inventory:** Menyimpan dan mengelola data persediaan bahan makanan.
3. **Recipe Finder:** Memberikan rekomendasi resep berdasarkan bahan makanan yang tersedia.
4. **Smart Notification:** Memberikan pengingat mengenai bahan makanan yang mendekati estimasi akhir masa simpan.

## 2.2 Fitur Pendukung

- Registrasi dan login pengguna.
- Home / Dashboard.
- Profile dan pengaturan akun dengan menu: **Profile Details**, **Password**, **Notifications**, **Dark Mode**, **Support**, **About**, dan **Language**.
- **Dark Mode:** mengubah tema aplikasi antara terang dan gelap.
- **Language:** memilih bahasa antarmuka (default **English**, tersedia **Indonesia**).
- **Resep Favorit:** Menyimpan resep pilihan pengguna agar dapat dibuka kembali, termasuk dalam kondisi offline.
- Logout.

## 2.3 Batasan Produk

1. Aplikasi dikembangkan menggunakan Flutter dan ditujukan untuk perangkat mobile Android.
2. Identifikasi bahan makanan dilakukan berdasarkan gambar yang diambil menggunakan kamera/galeri pengguna (satu bahan makanan per proses pemindaian).
3. Estimasi masa simpan merupakan perkiraan berdasarkan jenis makanan, karakteristik visual yang terdeteksi AI, jenis/lokasi penyimpanan, dan informasi pendukung. Estimasi ini **bukan jaminan** bahwa makanan masih aman dikonsumsi.
4. Rekomendasi resep didasarkan pada bahan makanan yang tersedia di Pantry dan filter yang dipilih pengguna.
5. Informasi peralatan memasak ditampilkan pada detail resep untuk membantu pengguna mempertimbangkan kesesuaian resep dengan peralatan yang dimiliki.
6. Aplikasi membutuhkan koneksi internet untuk proses yang melibatkan layanan AI (pemindaian dan pembuatan rekomendasi resep) serta untuk penulisan/sinkronisasi data ke backend.
7. Setelah bahan makanan tersimpan di Pantry, pengguna dapat mengubah **seluruh detail bahan** melalui halaman **Edit food details** — nama, kategori, lokasi penyimpanan, jumlah/kuantitas, tanggal pembelian, dan estimasi masa simpan. **Foto bahan tidak dapat diganti** tanpa menghapus bahan lalu memindai/menambahkan ulang.
8. Smart Notification diimplementasikan sebagai **notifikasi lokal terjadwal pada perangkat**, tanpa push notification dari server.
9. Backend menggunakan **Firebase plan Spark (no-cost, tanpa billing account dan tanpa kartu)** dengan komponen Firebase Authentication dan Cloud Firestore saja.
10. **Cloud Storage dan Cloud Functions tidak digunakan.** Foto bahan makanan disimpan **hanya di penyimpanan lokal perangkat** dan tidak diunggah ke server.
11. Panggilan ke layanan AI dilakukan melalui **proxy serverless Cloudflare Workers free plan (tanpa kartu)**. API key AI disimpan sebagai secret di sisi proxy dan tidak pernah ada di aplikasi client.
12. Seluruh layanan yang digunakan wajib berada pada free tier yang **tidak memerlukan billing account**. Tidak ada layanan yang berpotensi menagih pengembang.
13. Resep favorit disimpan sebagai salinan lengkap (snapshot) agar dapat dibaca saat offline.
14. Gambar resep menggunakan ilustrasi statis yang dibundel di dalam aplikasi, bukan gambar yang dihasilkan AI dan bukan URL dari internet.
15. Food Scanner memiliki dua mode: **Scan Food** (kamera/galeri) dan **Barcode** (barcode kemasan produk). Keduanya memerlukan koneksi internet.
16. Bahasa antarmuka bawaan adalah **English**, dengan opsi **Indonesia** pada menu Language.
17. **Desain UI mengikuti file Figma "Balomba"** (page *HiFi Optimeal*) sebagai acuan visual tunggal, sesuai Bagian 13.2 butir 2.

## 2.4 Mode Operasi (Online & Offline)

Optimeal mendukung dua mode operasi. Perilaku tiap fitur dibedakan secara eksplisit agar tidak menimbulkan kebingungan pengguna.

| Kemampuan | Online | Offline |
|---|---|---|
| Registrasi / Login | ✅ | ❌ (kecuali sesi masih aktif, pengguna langsung masuk) |
| Melihat daftar & detail Pantry (termasuk foto lokal) | ✅ | ✅ (data dari cache lokal) |
| Mencari & memfilter di Pantry | ✅ | ✅ (berbasis cache lokal) |
| Food Scanner — Scan Food (kamera/galeri + identifikasi AI) | ✅ | ❌ |
| Food Scanner — Barcode (pemindaian barcode kemasan) | ✅ | ❌ |
| Menambah bahan makanan secara manual | ✅ | ❌ |
| Mengubah detail bahan makanan (nama, kategori, lokasi, jumlah, tanggal, estimasi) | ✅ | ❌ |
| Mengubah Dark Mode & Language | ✅ | ✅ (tersimpan lokal) |
| Menghapus bahan makanan | ✅ | ❌ |
| Generate rekomendasi resep | ✅ | ❌ |
| Melihat resep favorit | ✅ | ✅ (snapshot lokal) |
| Menambah / menghapus favorit | ✅ | ❌ |
| Menerima notifikasi masa simpan | ✅ | ✅ (notifikasi lokal terjadwal) |
| Mengubah profil & preferensi notifikasi | ✅ | ❌ |

Ketentuan tambahan:

- Saat offline, aplikasi menampilkan indikator/banner **"Mode Offline"** serta keterangan waktu sinkronisasi terakhir.
- Tombol yang tidak tersedia saat offline ditampilkan dalam kondisi nonaktif disertai keterangan singkat, bukan disembunyikan.
- **Alasan pembatasan:** mencegah data tidak konsisten (mis. bahan tersimpan lokal namun gagal sinkron ke server) dan menjaga agar aplikasi tetap dapat diandalkan saat demo dengan koneksi tidak stabil.

---

# 3. FUNCTIONAL REQUIREMENTS

## 3.1 Authentication

**Deskripsi:**

Fitur autentikasi digunakan untuk mengelola akses pengguna ke aplikasi Optimeal.

**Kebutuhan fungsional:**

- Pengguna dapat melakukan registrasi menggunakan informasi akun yang diperlukan.
- Pengguna dapat login menggunakan akun yang telah terdaftar.
- Sistem melakukan validasi terhadap informasi login.
- Sistem menampilkan pesan kesalahan apabila autentikasi gagal.
- Registrasi mengirim **link verifikasi email** (Firebase Authentication). Pengguna harus memverifikasi email sebelum masuk ke halaman utama; layar verifikasi menyediakan **Resend email** dan pemeriksaan status.
- Pengguna dapat melakukan logout.
- Sesi pengguna dapat dipertahankan agar tidak perlu login kembali setiap membuka aplikasi.
- Registrasi dan login memerlukan koneksi internet. Apabila sesi masih aktif, pengguna dapat membuka aplikasi dalam mode offline (read-only).

**Output:**

Pengguna berhasil masuk ke halaman utama aplikasi.

## 3.2 Home / Dashboard

**Deskripsi:**

Halaman utama menjadi pusat navigasi untuk mengakses fitur-fitur Optimeal.

**Kebutuhan fungsional:**

- Menampilkan sapaan **"Welcome back"** diikuti nama dapur pengguna (mis. "Sarah's Kitchen") pada header.
- Menampilkan ikon notifikasi pada header.
- Menampilkan **kartu ringkasan** berisi jumlah bahan per lokasi penyimpanan: **Pantry**, **Fridge**, dan **Freezer**.
- Menampilkan **banner peringatan** berisi jumlah bahan yang mendekati batas estimasi masa simpan beserta ajakan memakai resep.
- Menampilkan bagian **Pantry** berisi maksimal **3 bahan** dengan sisa hari paling sedikit, diurutkan dari yang paling mendekati akhir masa simpan, serta tautan **"View All"** menuju Pantry.
- Menampilkan bagian **AI Recipe Recommendations** berisi maksimal **1 kartu resep** (ilustrasi, nama, deskripsi singkat, tag bahan, waktu masak) serta tautan **"View All"** menuju Recipe Finder.
- Menyediakan akses fitur melalui **bottom navigation**: Home, Pantry, Add (scan/tambah), Recipes, dan Profile.
- Menampilkan indikator "Mode Offline" apabila perangkat tidak terhubung ke internet.
- Menampilkan state loading, empty, dan error pada setiap bagian.

**Output:**

Pengguna dapat melihat ringkasan persediaan, pengingat, rekomendasi resep, dan mengakses fitur utama.

## 3.3 Food Scanner

**Deskripsi:**

Food Scanner digunakan untuk mengenali bahan makanan melalui gambar menggunakan teknologi AI.

**Kebutuhan fungsional:**

- Pengguna dapat membuka kamera melalui aplikasi.
- Layar Scanner memiliki pengalih mode **Scan Food** dan **Barcode**.
- Pengguna dapat mengambil gambar bahan makanan.
- Pengguna dapat mengulang pengambilan gambar apabila hasilnya kurang sesuai.
- Pengguna dapat mengambil gambar melalui galeri.
- Sistem mengompresi gambar sebelum dikirim ke layanan AI.
- Sistem mengirimkan gambar untuk diproses oleh layanan AI **melalui proxy Cloudflare Workers**.
- Sistem mengidentifikasi jenis bahan makanan berdasarkan gambar.
- Sistem menampilkan hasil identifikasi.
- Pengguna dapat mengonfirmasi atau mengoreksi nama dan kategori bahan makanan.
- Pengguna dapat melengkapi informasi bahan makanan sebelum menyimpannya.
- Sistem menyimpan **foto bahan makanan di penyimpanan lokal perangkat** (tidak diunggah ke server) dan mengaitkannya dengan data bahan.
- Proses pemindaian **tidak tersedia saat offline**.

**Mode pemindaian (sesuai desain Figma):**

| Elemen | Scan Food | Barcode |
|---|---|---|
| Sumber input | Kamera atau galeri. | Kamera (barcode kemasan produk). |
| Aksi di layar | Tombol shutter, thumbnail galeri, ganti kamera, tombol kembali dan tutup. | Sama, dengan bingkai pemindai barcode. |
| Data yang dikirim | Gambar terkompresi. | Nilai barcode. |
| Endpoint proxy | `POST /analyze-food` | `POST /analyze-barcode` |
| Ketersediaan | Online saja. | Online saja. |
| Hasil | Nama, kategori, kondisi visual, catatan AI, estimasi masa simpan per lokasi. | Nama produk, kategori, estimasi masa simpan per lokasi. Kondisi visual dan catatan AI boleh kosong. |

- Apabila barcode tidak dikenali atau produk tidak ditemukan, sistem menampilkan pesan dan menawarkan pengisian manual atau pemindaian ulang.
- Kedua mode menggunakan alur konfirmasi dan form yang sama setelah hasil identifikasi ditampilkan.

**Keluaran AI dari proses identifikasi:**

| Keluaran | Keterangan |
|---|---|
| Nama bahan makanan | Hasil identifikasi utama; dapat dikoreksi pengguna. |
| Kategori bahan makanan | Mis. sayur, buah, daging, bumbu, karbohidrat. |
| Kondisi visual | Ringkasan bentuk, warna, dan karakteristik yang terdeteksi (mis. "kulit masih mengkilap, warna merah merata"). |
| Catatan AI | Catatan opsional terkait kondisi bahan (mis. "warnanya sudah menguning, sebaiknya segera dikonsumsi"). Ditampilkan apa adanya sebagai peringatan, bukan vonis keamanan pangan. |
| Estimasi masa simpan per lokasi | Perkiraan jumlah hari untuk tiga lokasi penyimpanan: **`room_temperature` (suhu ruang, label UI "Pantry")**, **`fridge` (kulkas)**, dan **`freezer`**. |
| Tingkat keyakinan | Nilai keyakinan identifikasi; jika rendah, sistem menyarankan pengguna mengoreksi nama bahan. |

**Informasi bahan makanan yang dilengkapi pengguna:**

| Informasi | Wajib | Sumber | Keterangan |
|---|---|---|---|
| Nama bahan makanan | ✅ | AI, dapat dikoreksi | — |
| Kategori bahan makanan | ✅ | AI, dapat dikoreksi | — |
| Jumlah / kuantitas + satuan | ❌ (opsional) | Pengguna | Mis. 2 ikat, 500 gram, 3 buah. |
| Lokasi penyimpanan | ✅ | Pengguna | Nilai data: `room_temperature` / `fridge` / `freezer`. Label UI: **Pantry** / **Fridge** / **Freezer**. |
| Tanggal pembelian | ✅ | Pengguna | Default: hari ini. |
| Estimasi masa simpan (hari) | — | Sistem (dapat diubah pengguna) | Ditampilkan otomatis berdasarkan lokasi penyimpanan yang dipilih; dapat diubah pada form hasil scan dan Edit food details. |
| Tanggal estimasi akhir masa simpan | — | Sistem | Dihitung otomatis: tanggal pembelian + estimasi masa simpan. |
| Catatan AI | — | AI | Opsional, ditampilkan sebagai informasi. |
| Foto bahan | — | Pengguna | Disimpan lokal di perangkat. |

**Aturan estimasi masa simpan:**

1. AI mengembalikan estimasi masa simpan untuk tiga lokasi penyimpanan sekaligus.
2. Sistem memilih nilai yang sesuai dengan lokasi penyimpanan yang dipilih pengguna.
3. Apabila AI tidak memberikan nilai yang valid, sistem menggunakan data cadangan dari katalog internal berdasarkan kategori bahan dan lokasi penyimpanan.
4. Estimasi masa simpan bersifat perkiraan, bukan jaminan keamanan pangan.
5. **Jumlah/kuantitas bahan tidak mempengaruhi estimasi masa simpan.** Kuantitas hanya digunakan sebagai informasi bagi pengguna dan sebagai konteks porsi pada saat AI menyusun resep.
6. Pengguna dapat **menimpa estimasi masa simpan** secara manual (mis. mengikuti tanggal kedaluwarsa pada kemasan). Nilai manual disimpan apa adanya dan dipakai untuk menghitung `estimatedEndDate`.

**Aturan field yang dapat diubah:**

- **Sebelum disimpan** (pada form hasil scan / *Add Food*): seluruh field dapat diubah pengguna.
- **Setelah tersimpan** di Pantry: seluruh detail dapat diubah melalui halaman **Edit food details** (lihat 3.4), kecuali foto.

**Output:**

Hasil identifikasi bahan makanan ditampilkan dan dapat disimpan ke Pantry.

## 3.4 Pantry / Inventory

**Deskripsi:**

Pantry merupakan fitur inventaris digital untuk menyimpan dan mengelola persediaan bahan makanan pengguna.

**Kebutuhan fungsional:**

- Pengguna dapat melihat daftar bahan makanan yang tersimpan.
- Pengguna dapat melihat detail informasi setiap bahan makanan, termasuk foto bahan bila tersedia.
- Pengguna dapat menambahkan bahan makanan secara manual (form *Add Food*) atau melalui hasil Food Scanner.
- Pengguna dapat membuka halaman **Edit food details** untuk mengubah **nama, kategori, lokasi penyimpanan, jumlah/kuantitas, tanggal pembelian, dan estimasi masa simpan**.
- Perubahan **tanggal pembelian** atau **estimasi masa simpan** akan menghitung ulang tanggal estimasi akhir masa simpan (`estimatedEndDate`).
- Perubahan **lokasi penyimpanan** akan memilih ulang estimasi masa simpan bawaan untuk lokasi tersebut (lihat 3.3), kecuali pengguna mengisi estimasi secara manual.
- Perubahan **jumlah/kuantitas** **tidak** mengubah estimasi masa simpan.
- Pengguna dapat menghapus bahan makanan.
- Pengguna dapat mencari bahan makanan berdasarkan nama.
- Pengguna dapat mengelompokkan atau memfilter bahan berdasarkan kategori.
- Sistem menampilkan informasi estimasi masa simpan.
- Sistem membantu mengurutkan bahan berdasarkan estimasi masa simpan yang paling mendekati kedaluwarsa.
- Saat offline: pengguna hanya dapat melihat daftar dan detail bahan (read-only). Penambahan, perubahan, dan penghapusan tidak tersedia.

**Batasan perubahan data:**

| Aksi | Sebelum tersimpan (form scan / tambah manual) | Setelah tersimpan (Edit food details) |
|---|---|---|
| Ubah nama / kategori | ✅ | ✅ |
| Ubah jumlah / kuantitas | ✅ | ✅ |
| Ubah lokasi penyimpanan | ✅ | ✅ |
| Ubah tanggal pembelian | ✅ | ✅ |
| Ubah estimasi masa simpan | ✅ | ✅ |
| Mengganti foto | ✅ | ❌ (hapus lalu tambah ulang) |
| Melihat estimasi masa simpan | ✅ | ✅ |
| Hapus bahan | — | ✅ |

**Prinsip perubahan data:**

- **Data teks boleh diedit** agar pengguna dapat memperbaiki hasil identifikasi AI tanpa harus menghapus bahan.
- **Foto tetap tidak dapat diganti** pada bahan yang sudah tersimpan; untuk mengganti foto, pengguna menghapus bahan lalu memindai/menambahkan ulang.
- Setiap perubahan wajib memicu perhitungan ulang `estimatedEndDate` dan penjadwalan ulang notifikasi (lihat 3.6).

**Catatan:** formulir Edit food details menampilkan pilihan foto bahan di bagian atas (dengan aksi hapus) serta field Food Name, Category, Location, Qty / Size, Purchase Date, dan Shelf Life Estimate, sesuai desain Figma.

**Output:**

Pengguna memiliki inventaris digital yang dapat diperbarui dan digunakan sebagai sumber data rekomendasi resep.

## 3.5 Recipe Finder

**Deskripsi:**

Recipe Finder digunakan untuk memberikan rekomendasi masakan berdasarkan bahan makanan yang tersedia di Pantry.

**Kebutuhan fungsional:**

- Pengguna dapat membuka halaman Recipe Finder.
- Sistem mengambil data bahan makanan dari Pantry.
- Pengguna dapat memfilter **bahan** yang akan dipertimbangkan berdasarkan lokasi penyimpanan: **Pantry** (`room_temperature`), **Fridge**, atau **Freezer**.
- Pengguna dapat memfilter resep berdasarkan **cuisine** (gaya memasak per negara/daerah, mis. Indonesia, Italia, Cina, Jepang, Korea, Western).
- Pengguna dapat memilih bahan makanan tertentu sebagai dasar pencarian resep.
- Pengguna dapat meminta sistem menghasilkan rekomendasi resep.
- Sistem memproses data bahan makanan menggunakan layanan AI **melalui proxy Cloudflare Workers**.
- Sistem menampilkan daftar rekomendasi resep.
- Pengguna dapat memilih salah satu resep untuk melihat detailnya.
- Pengguna dapat menambahkan resep ke favorit dari daftar maupun dari halaman detail.
- Pengguna dapat **menghapus resep** melalui ikon delete pada halaman detail resep. Resep yang dihapus juga dihapus dari cache rekomendasi dan dari daftar favorit pengguna.
- Generate resep **tidak tersedia saat offline**. Resep yang sudah difavoritkan tetap dapat dibuka (lihat 3.8).

**Cara kerja filter lokasi penyimpanan:**

Filter ini menentukan **bahan mana** yang ikut dikirim ke AI, bukan atribut resep.

> Contoh: pengguna memilih **Fridge**. Sistem hanya mengirim bahan yang tersimpan di fridge (mis. bawang, tomat, wortel). Bahan yang tersimpan di Pantry (`room_temperature`) atau Freezer **tidak** dipertimbangkan dalam pencarian resep.

**Cara kerja filter cuisine:**

- Cuisine merepresentasikan asal/gaya masakan suatu daerah atau negara (mis. Indonesia, Italia, Jepang).
- Teknik memasak (goreng, kukus, rebus, tumis) **bukan** cuisine, melainkan informasi terpisah yang ditampilkan pada detail resep.
- Cuisine bersifat opsional sebagai filter. Apabila tidak dipilih, sistem memberi rekomendasi lintas cuisine.

**Informasi pada detail resep:**

- Nama resep.
- Ilustrasi masakan (asset lokal bawaan aplikasi, lihat 6.3).
- Deskripsi singkat.
- Cooking time (estimasi).
- Cuisine (gaya memasak per negara/daerah).
- Teknik memasak (mis. tumis, kukus, goreng).
- Daftar bahan yang dibutuhkan.
- Bahan yang tersedia di Pantry.
- Bahan tambahan yang perlu disiapkan.
- Peralatan memasak yang dibutuhkan.
- Langkah-langkah memasak.
- Tombol tambah/hapus favorit.
- Navigasi tab **Ingredients / Equipment / Instructions** pada halaman detail resep.
- Tombol kembali dan ikon delete pada header halaman detail.

**Batasan & caching rekomendasi:**

- Hasil generate disimpan sebagai cache agar tidak perlu memanggil ulang AI untuk kombinasi yang sama.
- Cache maksimal **10 resep per pengguna**; jika melebihi, resep yang paling lama tidak diakses dihapus.
- Cache resep yang tidak diakses selama **7 hari** dihapus otomatis.
- Permintaan generate dibatasi maksimal **10 permintaan per jam** dan **30 permintaan per hari** per pengguna. Batas ini melindungi kuota free tier AI yang dipakai bersama.
- Apabila batas tercapai, sistem menampilkan pesan informatif dan menawarkan resep dari cache.

**Output:**

Pengguna memperoleh rekomendasi masakan yang dapat dibuat berdasarkan persediaan bahan makanan.

## 3.6 Smart Notification

**Deskripsi:**

Smart Notification digunakan untuk memberikan pengingat kepada pengguna mengenai bahan makanan yang mendekati estimasi akhir masa simpannya.

**Kebutuhan fungsional:**

- Sistem memantau estimasi masa simpan seluruh bahan makanan di Pantry.
- Sistem mengidentifikasi bahan makanan yang mendekati estimasi akhir masa simpan berdasarkan selisih antara tanggal hari ini dan tanggal estimasi akhir masa simpan.
- Sistem mengirimkan notifikasi lokal kepada pengguna.
- Notifikasi menampilkan informasi nama bahan makanan dan pengingat untuk segera mengolah atau memeriksa kondisinya.
- Pengguna dapat membuka detail bahan makanan melalui notifikasi (deep link ke halaman detail Pantry).
- Pengguna dapat mengatur preferensi notifikasi: aktif/nonaktif dan ambang pengingat (default **1 hari** sebelum estimasi akhir masa simpan; pilihan 1–3 hari).
- Notifikasi dijadwalkan ulang setiap kali data Pantry berubah, aplikasi dibuka, atau preferensi diubah.
- Notifikasi tetap muncul saat offline karena dijadwalkan secara lokal pada perangkat.
- Sistem juga menampilkan banner pengingat di halaman Home sebagai pelengkap.

**Aturan pengiriman:**

1. Notifikasi dijadwalkan pada H-{ambang} dan pada H-0 (hari estimasi akhir masa simpan).
2. Satu bahan makanan menghasilkan maksimal dua notifikasi (H-ambang dan H-0).
3. Bahan yang sudah dihapus dari Pantry membatalkan notifikasi terjadwalnya.
4. Bahan yang tanggal pembeliannya diubah akan menjadwalkan ulang notifikasinya.
5. **Penggabungan notifikasi:** apabila terdapat lebih dari 3 bahan yang jatuh pada tanggal pengingat yang sama, sistem menampilkan maksimal **3 notifikasi individual** (diurutkan dari sisa hari paling sedikit) ditambah **1 notifikasi ringkasan** (mis. "5 bahan lain juga mendekati batas estimasi masa simpan"). Tujuannya mencegah spam notifikasi.
6. **Aturan copywriting:** notifikasi menggunakan kata **"mendekati batas estimasi masa simpan"** atau **"tinggal ±N hari"**, bukan pernyataan pasti "basi". Untuk antarmuka English (default), gunakan **"approaching shelf-life estimate"** atau **"±N days left"**, bukan "spoiled"/"rotten". Hal ini konsisten dengan sifat estimasi pada 2.3 butir 3.
7. Notifikasi tidak boleh dikirim untuk bahan yang sudah dihapus atau sudah melewati H-0 lebih dari 1 hari.

**Contoh isi notifikasi:**

> Contoh di bawah memakai bahasa Indonesia. Versi English memakai padanan yang sama (mis. "Your spinach has ±2 days left. Cook it soon."), tanpa kata "spoiled".

| Waktu | Judul | Isi |
|---|---|---|
| H-2 | Bahan mendekati batas | "Bayam kamu tinggal ±2 hari lagi. Yuk segera diolah." |
| H-1 | Bahan mendekati batas | "Tomat kamu tinggal ±1 hari lagi. Segera olah atau periksa kondisinya." |
| H-0 | Hari terakhir estimasi | "Hari ini batas estimasi masa simpan Bayam. Periksa kondisinya." |
| Ringkasan | Beberapa bahan mendekati batas | "5 bahan lain juga mendekati batas estimasi masa simpan. Cek Pantry." |

**Output:**

Pengguna memperoleh pengingat agar dapat memprioritaskan bahan makanan yang perlu segera digunakan.

## 3.7 Profile & Settings

**Deskripsi:**

Profile digunakan untuk mengelola informasi dan preferensi akun pengguna.

**Kebutuhan fungsional:**

- Pengguna dapat melihat informasi profil: foto, nama, dan email.
- Halaman Profile menampilkan daftar menu berikut:
  - **Profile Details** — melihat dan mengubah nama/informasi profil.
  - **Password** — mengubah kata sandi akun.
  - **Notifications** — mengatur notifikasi (aktif/nonaktif dan ambang hari).
  - **Dark Mode** — mengaktifkan/menonaktifkan tema gelap.
  - **Support** — halaman bantuan/kontak dukungan.
  - **About** — informasi aplikasi dan versi.
  - **Language** — memilih bahasa antarmuka.
- Pengguna dapat melakukan logout melalui tombol **Logout** di bagian bawah halaman.
- Perubahan profil, kata sandi, dan preferensi notifikasi memerlukan koneksi internet.
- Perubahan **Dark Mode** dan **Language** disimpan lokal dan dapat dilakukan saat offline.

**Catatan penempatan Resep Favorit:** akses Resep Favorit ditempatkan di halaman **Recipe Finder**, bukan di Profile. Alasannya dijelaskan pada Bagian 12.

## 3.8 Resep Favorit

**Deskripsi:**

Fitur pendukung yang memungkinkan pengguna menyimpan resep pilihan dan membukanya kembali kapan saja, termasuk saat offline.

**Kebutuhan fungsional:**

- Pengguna dapat menambahkan resep ke favorit melalui ikon pada kartu resep atau halaman detail resep.
- Pengguna dapat menghapus resep dari favorit.
- Pengguna dapat melihat daftar resep favorit pada tab **Favorit** di halaman Recipe Finder.
- Sistem menyimpan **salinan lengkap (snapshot)** data resep ke penyimpanan lokal perangkat, sehingga resep favorit dapat dibuka tanpa koneksi internet.
- Daftar favorit juga disinkronkan ke backend agar tersedia pada perangkat lain dan tetap ada setelah login ulang.
- Saat offline, daftar dan detail favorit dapat dibuka; penambahan/penghapusan favorit dinonaktifkan.
- Pengguna dapat menghapus favorit dari halaman detail favorit saat online.

**Batasan:**

- Maksimal **50 resep favorit** per pengguna.
- Resep favorit yang tersimpan lokal tetap dapat dibuka meskipun cache rekomendasi (3.5) sudah dihapus.

**Output:**

Pengguna memiliki daftar resep andalan yang dapat diakses cepat dan tetap tersedia saat offline.

## 3.9 Appearance & Language

**Deskripsi:**

Fitur pendukung untuk menyesuaikan tampilan dan bahasa aplikasi. Keduanya diakses dari halaman Profile.

**Kebutuhan fungsional:**

- Pengguna dapat mengaktifkan atau menonaktifkan **Dark Mode** melalui toggle pada halaman Profile.
- Perubahan tema langsung diterapkan ke seluruh aplikasi tanpa perlu restart.
- Pilihan tema disimpan di penyimpanan lokal dan tetap berlaku setelah aplikasi dibuka kembali.
- Pengguna dapat memilih **Language** pada halaman Language: **English** (default) dan **Indonesia**.
- Perubahan bahasa diterapkan ke seluruh teks antarmuka, format tanggal, dan format angka.
- Pilihan bahasa disimpan lokal dan disinkronkan ke profil pengguna saat online.
- Dark Mode dan Language **tetap dapat diubah saat offline**.

**Ketentuan copywriting:**

- Istilah baku tetap dipertahankan maknanya pada kedua bahasa. Untuk notifikasi, versi English tidak boleh memakai kata "spoiled"/"rotten"; gunakan "approaching shelf-life estimate" atau "±N days left", konsisten dengan 3.6.
- Label lokasi penyimpanan tetap **Pantry / Fridge / Freezer** pada kedua bahasa (tidak diterjemahkan).

**Output:**

Pengguna dapat memakai aplikasi dengan tema dan bahasa yang diinginkan.

---

# 4. USER FLOW

## 4.1 Main Application Flow

Alur utama penggunaan Optimeal:

1. Pengguna membuka aplikasi.
2. Sistem menampilkan halaman autentikasi apabila pengguna belum login.
3. Pengguna melakukan registrasi atau login.
4. Sistem memvalidasi informasi akun.
5. Apabila berhasil, sistem menampilkan halaman Home.
6. Pengguna memilih fitur Food Scanner.
7. Pengguna mengambil gambar bahan makanan.
8. Sistem memproses gambar menggunakan AI.
9. Sistem menampilkan hasil identifikasi bahan makanan.
10. Pengguna mengonfirmasi hasil dan melengkapi informasi bahan.
11. Sistem menyimpan data bahan makanan ke Pantry.
12. Pengguna dapat menambahkan bahan lain atau melanjutkan.
13. Pengguna membuka Recipe Finder.
14. Sistem mengambil data bahan makanan dari Pantry.
15. Pengguna memilih kategori, filter, atau bahan tertentu.
16. Pengguna meminta rekomendasi resep.
17. Sistem memproses dan menampilkan rekomendasi resep.
18. Pengguna memilih resep.
19. Sistem menampilkan detail resep.
20. Pengguna dapat menyimpan resep ke favorit.
21. Pengguna menyelesaikan aktivitas dan dapat menutup aplikasi.

## 4.2 Food Scanner Flow

Buka Food Scanner → Ambil Gambar (kamera/galeri) → Kompresi Gambar → Kirim ke Proxy AI → Proses Identifikasi AI → Tampilkan Hasil Scan (nama, kategori, kondisi visual, catatan AI, estimasi masa simpan per lokasi) → Konfirmasi Nama & Kategori → Isi Jumlah (opsional), Lokasi Penyimpanan, Tanggal Pembelian → Sistem Menghitung Estimasi Masa Simpan & Tanggal Akhir → Simpan Foto ke Penyimpanan Lokal → Simpan ke Pantry → Selesai.

Apabila identifikasi tidak sesuai, pengguna dapat mengulang pemindaian atau mengoreksi nama/kategori bahan secara manual sebelum menyimpan.

Apabila offline, halaman Food Scanner menampilkan status bahwa pemindaian memerlukan koneksi internet.

**Barcode Flow:** Buka Scanner → Pilih mode Barcode → Arahkan kamera ke barcode kemasan → Kirim nilai barcode ke Proxy AI → Tampilkan hasil identifikasi produk (nama, kategori, estimasi masa simpan per lokasi) → Konfirmasi & lengkapi form → Simpan ke Pantry.

Apabila barcode tidak dikenali, pengguna dapat mengulang pemindaian, beralih ke mode Scan Food, atau mengisi data secara manual.

## 4.3 Pantry Flow

Buka Pantry → Tampilkan Daftar Bahan (urut berdasarkan masa simpan terdekat) → Cari / Filter Kategori → Pilih Bahan → Tampilkan Detail → Edit food details / Hapus / Kembali.

Saat offline: Buka Pantry → Tampilkan Daftar Bahan dari Cache (termasuk foto lokal) → Pilih Bahan → Tampilkan Detail (read-only).

## 4.4 Recipe Finder Flow

Buka Recipe Finder → Ambil Data Pantry → Pilih Filter Lokasi Penyimpanan Bahan dan/atau Cuisine dan/atau Bahan Tertentu → Generate Recipe → Tampilkan Rekomendasi → Pilih Resep → Tampilkan Detail Resep → (Opsional) Tambah ke Favorit.

## 4.5 Smart Notification Flow

Sistem mengambil tanggal estimasi akhir seluruh bahan di Pantry → Hitung selisih dengan tanggal hari ini → Bahan mendekati batas estimasi → Sistem menjadwalkan notifikasi lokal (dengan penggabungan bila lebih dari 3 bahan) → Notifikasi muncul → Pengguna membuka notifikasi → Sistem menampilkan detail bahan → Pengguna menentukan tindakan selanjutnya.

## 4.6 Resep Favorit Flow

Buka Recipe Finder → Tab Favorit → Tampilkan Daftar Resep Favorit → Pilih Resep → Tampilkan Detail Resep → Hapus dari Favorit / Kembali.

Saat offline: Buka Recipe Finder → Tab Favorit → Tampilkan Daftar dari Snapshot Lokal → Pilih Resep → Tampilkan Detail (read-only).

## 4.7 Offline Flow

Pengguna membuka aplikasi tanpa koneksi → Sesi tersimpan membuat pengguna langsung masuk → Sistem menampilkan banner "Mode Offline" dan waktu sinkronisasi terakhir → Pengguna dapat membuka Pantry (read-only), detail bahan, resep favorit, dan notifikasi lokal → Tombol Scan, Tambah Manual, Generate Resep, Ubah, Hapus, dan Ubah Profil dinonaktifkan → Ketika koneksi kembali, sistem menyinkronkan data dan mengaktifkan kembali seluruh fitur.

---

# 5. TECHNOLOGY STACK

## 5.1 Frontend Development

**Flutter**

Flutter digunakan sebagai framework utama untuk mengembangkan aplikasi mobile Optimeal.

**Dart**

Dart digunakan sebagai bahasa pemrograman untuk membangun antarmuka, logika aplikasi, dan integrasi layanan.

**Fungsi:**

- Mengembangkan seluruh halaman aplikasi.
- Mengimplementasikan navigasi (termasuk deep link dari notifikasi ke detail bahan).
- Mengelola state aplikasi.
- Mengintegrasikan API.
- Mengakses kamera perangkat.
- Menampilkan data dari backend.
- Menyimpan data cache lokal untuk mode offline.

**Rekomendasi pustaka:**

| Kebutuhan | Pustaka |
|---|---|
| State management | Riverpod |
| Navigasi & deep link | go_router |
| Model & serialisasi | freezed, json_serializable |
| Kamera di dalam aplikasi (Scan Food) | camera |
| Galeri | image_picker |
| Pemindai barcode (mode Barcode) | mobile_scanner |
| Kompresi gambar | flutter_image_compress |
| Notifikasi lokal | flutter_local_notifications + timezone |
| Cache lokal (favorit, snapshot Pantry, path foto) | Hive / Isar |
| Penyimpanan file lokal (foto bahan) | path_provider |
| HTTP | http / dio |
| Format tanggal & angka | intl |

## 5.2 Backend & Database

**Firebase plan Spark (no-cost)**

Komponen yang digunakan:

- **Firebase Authentication:** Mengelola registrasi dan login.
- **Cloud Firestore:** Menyimpan data pengguna, Pantry, resep, favorit, dan preferensi.

Komponen yang **tidak** digunakan:

- **Cloud Storage:** tidak digunakan. Foto bahan makanan disimpan lokal di perangkat.
- **Cloud Functions:** tidak digunakan karena mewajibkan upgrade ke plan Blaze (memerlukan billing account/kartu).
- **Firebase Cloud Messaging:** tidak digunakan. Notifikasi diimplementasikan secara lokal di perangkat.

**Ketentuan plan:**

- Plan Spark **tidak memiliki billing account** sehingga secara teknis **tidak dapat menagih**. Apabila kuota gratis habis, layanan berhenti melayani permintaan, bukan menimbulkan tagihan.
- Proyek **tidak boleh di-upgrade ke Blaze** selama masa pengembangan dan lomba.

**Alasan pemilihan:** Firebase Spark menyediakan autentikasi dan database dengan dukungan cache offline tanpa biaya dan tanpa kartu, sehingga aman digunakan untuk proyek lomba yang tidak boleh menimbulkan tagihan.

## 5.3 Artificial Intelligence

**Google Gemini API (free tier)**

Diakses **melalui proxy Cloudflare Workers**, bukan langsung dari aplikasi client.

Penggunaan AI meliputi:

- Identifikasi bahan makanan dari gambar (nama, kategori, kondisi visual, catatan, estimasi masa simpan per lokasi penyimpanan).
- Identifikasi produk kemasan dari barcode (nama, kategori, estimasi masa simpan per lokasi penyimpanan).
- Menghasilkan rekomendasi resep berdasarkan persediaan bahan makanan, filter lokasi penyimpanan, dan cuisine.
- Menghasilkan informasi bahan, peralatan, teknik memasak, dan langkah memasak.

**Proxy Cloudflare Workers:**

- Berjalan pada **free plan** (tanpa kartu kredit/rekening).
- API key Gemini disimpan sebagai **secret environment variable** di sisi Worker.
- Worker memvalidasi **Firebase ID token** dari aplikasi sebelum meneruskan permintaan ke Gemini, agar endpoint tidak bisa dipakai pihak lain.
- Worker menyembunyikan detail prompt dan model dari client.
- Kode Worker dan konfigurasinya disimpan di repository yang sama atau repository terpisah yang disepakati tim.

**Ketentuan:**

- Hasil AI wajib divalidasi di sisi client (mis. field wajib tidak kosong, durasi hari berupa bilangan positif).
- Hasil AI disajikan sebagai estimasi atau rekomendasi, bukan kepastian kondisi keamanan makanan.
- Jika AI gagal atau timeout, aplikasi menampilkan pesan error dan opsi mencoba lagi; untuk estimasi masa simpan, sistem memakai data katalog cadangan.
- Free tier Gemini memiliki batas laju permintaan; aplikasi menerapkan cache dan rate limit (Bagian 11) untuk menjaga kuota.

## 5.4 API Integration

**Cloudflare Workers (HTTPS endpoint)**

Digunakan untuk menghubungkan aplikasi Flutter dengan layanan AI. Kontrak endpoint dijelaskan pada `DevelopmentPlan.md`.

| Endpoint | Fungsi |
|---|---|
| `POST /analyze-food` | Identifikasi bahan makanan dari gambar. |
| `POST /analyze-barcode` | Identifikasi produk kemasan dari nilai barcode. |
| `POST /generate-recipes` | Menghasilkan rekomendasi resep. |

**REST API / HTTP**

Digunakan untuk komunikasi dengan endpoint proxy di atas dan Firebase SDK.

## 5.5 Local Storage & Offline Support

- **Cloud Firestore offline persistence** diaktifkan untuk cache data yang telah dibaca.
- **Snapshot Pantry** disimpan di penyimpanan lokal agar daftar bahan selalu dapat ditampilkan saat offline.
- **Foto bahan** disimpan sebagai file di direktori aplikasi pada perangkat, dengan pemetaan `foodId → path` di database lokal.
- **Snapshot resep favorit** disimpan lengkap di penyimpanan lokal agar dapat dibuka tanpa koneksi (lihat 3.8).
- **Ilustrasi resep** dibundel sebagai asset aplikasi sehingga tetap tampil saat offline.
- Sinkronisasi dilakukan otomatis saat koneksi kembali tersedia; status sinkronisasi ditampilkan kepada pengguna.

##   Model Biaya & Batasan Free Tier

Seluruh layanan yang dipakai **gratis dan tidak memerlukan kartu kredit/rekening**.

| Layanan | Plan | Batas gratis | Butuh kartu? | Kemungkinan ditagih |
|---|---|---|---|---|
| Firebase Authentication | Spark | Gratis untuk email/password | Tidak | Tidak |
| Cloud Firestore | Spark | 1 GiB data, 50.000 read/hari, 20.000 write/hari | Tidak | Tidak |
| Cloudflare Workers | Free | 100.000 request/hari | Tidak | Tidak |
| Google Gemini API | Free tier | Dibatasi rate limit per model | Tidak | Tidak |

**Catatan penting:**

1. Plan Spark **tidak dapat menagih** karena tidak terhubung ke billing account. Risiko tagihan tidak ada.
2. Free tier Gemini dapat menggunakan data permintaan untuk peningkatan produk Google. Untuk prototipe lomba, hal ini dapat diterima; jangan mengirim data pribadi/sensitif.
3. Rate limit free tier Gemini dapat berubah kapan saja. Mitigasi: cache resep, rate limit per pengguna, dan mock mode untuk pengembangan.
4. Apabila di masa depan dibutuhkan kapasitas lebih, keputusan upgrade harus dibahas terpisah dan tidak termasuk lingkup versi ini.

---

# 6. DATA REQUIREMENTS

## 6.1 User Data

Informasi yang disimpan:

- User ID.
- Nama pengguna.
- Email.
- Password authentication (dikelola oleh Firebase Authentication).
- Preferensi notifikasi (aktif/nonaktif, ambang hari).
- Preferensi tema (`light` / `dark`).
- Preferensi bahasa (`en` / `id`).
- Waktu pembuatan dan pembaruan akun.

## 6.2 Food Inventory Data

| Field | Tipe | Sumber | Keterangan |
|---|---|---|---|
| `foodId` | String | Sistem | ID unik bahan makanan. |
| `userId` | String | Sistem | Pemilik data. |
| `name` | String | AI (dapat dikoreksi) | Nama bahan makanan. |
| `category` | String | AI (dapat dikoreksi) | Kategori bahan. |
| `quantity` | Number? | Pengguna | Jumlah/kuantitas (opsional). Dapat diubah setelah tersimpan. |
| `unit` | String? | Pengguna | Satuan (gram, buah, ikat, dll). |
| `storageLocation` | Enum | Pengguna | `room_temperature` / `fridge` / `freezer`. Label UI: Pantry / Fridge / Freezer. |
| `purchaseDate` | Timestamp | Pengguna | Tanggal pembelian. Dapat diubah setelah tersimpan. |
| `shelfLifeDays` | Number | Sistem / Pengguna | Estimasi masa simpan (hari) sesuai lokasi penyimpanan. Dapat diubah pengguna melalui Edit food details. |
| `estimatedEndDate` | Timestamp | Sistem | `purchaseDate + shelfLifeDays`; dihitung ulang bila `purchaseDate` berubah. |
| `visualCondition` | String | AI | Ringkasan bentuk, warna, karakteristik. |
| `aiNote` | String? | AI | Catatan kondisi opsional (mis. "warnanya sudah menguning"). |
| `hasPhoto` | Boolean | Sistem | Menandai apakah perangkat memiliki foto lokal untuk bahan ini. |
| `createdAt` | Timestamp | Sistem | Waktu dibuat. |
| `updatedAt` | Timestamp | Sistem | Waktu diperbarui. |

**Catatan foto:** tidak ada field URL gambar di Firestore. Foto disimpan sebagai file lokal dan dipetakan di database lokal (`foodPhotos/{foodId}`). Foto **tidak disinkronkan** antarperangkat.

## 6.3 Recipe Data

| Field | Tipe | Keterangan |
|---|---|---|
| `recipeId` | String | ID unik resep. |
| `name` | String | Nama resep. |
| `description` | String | Deskripsi singkat. |
| `illustrationKey` | String | Kunci asset ilustrasi lokal (lihat catatan di bawah). |
| `cuisine` | String | Gaya masakan per negara/daerah (mis. Indonesia, Italia). |
| `cookingTechnique` | String | Teknik memasak (mis. tumis, kukus, goreng). |
| `cookingTimeMinutes` | Number | Estimasi waktu memasak. |
| `ingredientsAvailable` | List | Bahan yang tersedia di Pantry. |
| `ingredientsMissing` | List | Bahan tambahan yang perlu disiapkan. |
| `equipment` | List | Peralatan memasak yang dibutuhkan. |
| `steps` | List | Langkah-langkah memasak. |
| `generatedAt` | Timestamp | Waktu resep dihasilkan. |
| `lastAccessedAt` | Timestamp | Dipakai untuk kebijakan cache (10 resep/pengguna). |

**Catatan ilustrasi resep:** AI berbasis teks tidak menghasilkan gambar. Aplikasi membundel ±15 ilustrasi lokal dan memilih berdasarkan `cuisine`/kategori masakan. Ilustrasi berbentuk asset aplikasi, sehingga **tetap tampil saat offline**. Pengambilan gambar dari internet (termasuk URL stok foto) tidak digunakan karena berisiko lisensi, tautan mati, dan gagal tampil saat offline.

## 6.4 Notification Data

| Field | Tipe | Keterangan |
|---|---|---|
| `notificationId` | String | ID notifikasi lokal. |
| `userId` | String | Pemilik. |
| `foodId` | String | Bahan terkait (atau `summary` untuk notifikasi ringkasan). |
| `title` | String | Judul notifikasi. |
| `body` | String | Isi notifikasi. |
| `scheduledAt` | Timestamp | Waktu penjadwalan. |
| `status` | Enum | `scheduled` / `delivered` / `read` / `cancelled`. |

## 6.5 Favorite Recipe Data

| Field | Tipe | Keterangan |
|---|---|---|
| `favoriteId` | String | Sama dengan `recipeId`. |
| `userId` | String | Pemilik. |
| `recipeSnapshot` | Map | Salinan lengkap data resep (untuk akses offline). |
| `savedAt` | Timestamp | Waktu difavoritkan. |

## 6.6 Struktur Penyimpanan (Firestore)

```
users/{uid}                                  → profil & preferensi
users/{uid}/pantry/{foodId}                  → data bahan makanan
users/{uid}/recipes/{recipeId}               → cache rekomendasi resep
users/{uid}/favorites/{recipeId}             → resep favorit (snapshot)
users/{uid}/notifications/{notificationId}   → catatan notifikasi
foodCatalog/{category}                       → data cadangan estimasi masa simpan
```

**Aturan keamanan:** setiap pengguna hanya dapat membaca dan menulis data di bawah `users/{uid}` miliknya sendiri.

```
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

## 6.7 Struktur Penyimpanan Lokal (Perangkat)

```
foodPhotos/{foodId}        → path file foto bahan makanan
pantrySnapshot             → salinan daftar bahan untuk mode offline
favoriteSnapshots          → salinan lengkap resep favorit
notificationSchedule       → metadata notifikasi yang dijadwalkan
appPreferences             → preferensi tema (light/dark) & bahasa (en/id)
```

Data lokal dihapus saat pengguna logout agar tidak tercampur antar akun pada perangkat yang sama.

---

# 7. NON-FUNCTIONAL REQUIREMENTS

## 7.1 Performance

- Aplikasi dapat berpindah halaman dengan responsif.
- Proses pemuatan data menampilkan indikator loading.
- Gambar dikompresi sebelum dikirim ke layanan AI (target maksimal 1024 px dan ≤500 KB).
- Sistem menangani kegagalan koneksi dan API dengan pesan yang informatif.
- Resep hasil generate di-cache untuk menghindari pemanggilan AI berulang.

## 7.2 Security

- Data akun pengguna harus terlindungi.
- Pengguna hanya dapat mengakses dan mengubah data inventaris miliknya (dijamin melalui Firestore Security Rules berbasis `uid`).
- API key layanan AI tidak disimpan di aplikasi client; seluruh pemanggilan AI melalui proxy Cloudflare Workers.
- Proxy memvalidasi Firebase ID token sebelum meneruskan permintaan ke layanan AI.
- Komunikasi dengan layanan backend menggunakan koneksi HTTPS.
- Foto bahan makanan tidak pernah meninggalkan perangkat.

## 7.3 Usability

- Antarmuka mudah dipahami oleh berbagai kelompok pengguna.
- Navigasi antarfitur konsisten.
- Informasi bahan makanan dan resep ditampilkan dengan jelas.
- Pengguna dapat menyelesaikan aktivitas utama dengan langkah yang sederhana.
- Status online/offline selalu terlihat jelas.
- Tombol yang tidak tersedia saat offline dinonaktifkan disertai keterangan, bukan hilang tanpa penjelasan.
- Hasil AI selalu ditandai sebagai estimasi/rekomendasi.
- Tema terang dan gelap sama-sama memenuhi kontras keterbacaan.
- Teks antarmuka tersedia dalam English dan Indonesia tanpa merusak layout.

## 7.4 Reliability

- Data bahan makanan yang telah disimpan tidak hilang ketika aplikasi ditutup (tersimpan di Firestore dan cache lokal).
- Sistem menangani kondisi API gagal, timeout, atau tidak tersedia.
- Proses penyimpanan dan pembaruan data memberikan umpan balik kepada pengguna.
- Kegagalan sinkronisasi ditampilkan sebagai status, bukan error yang menghentikan aplikasi.
- Notifikasi lokal dijadwalkan ulang ketika data Pantry berubah agar tidak ada pengingat yang salah.

## 7.5 Offline Behavior

- Aplikasi dapat dibuka dan menampilkan Pantry dalam mode read-only saat offline.
- Aplikasi menampilkan waktu sinkronisasi terakhir.
- Fitur yang membutuhkan AI dan penulisan data dinonaktifkan saat offline dengan pesan yang jelas.
- Resep favorit dapat dibuka dari snapshot lokal, termasuk ilustrasinya.
- Foto bahan tetap tampil karena tersimpan lokal.
- Notifikasi masa simpan tetap berjalan karena dijadwalkan secara lokal.
- Setelah koneksi pulih, aplikasi menyinkronkan data dan mengaktifkan kembali seluruh fitur.

---

# 8. ACCEPTANCE CRITERIA

Aplikasi dapat dinyatakan memenuhi kebutuhan dasar apabila:

1. Pengguna dapat melakukan registrasi dan login.
2. Pengguna dapat mengakses halaman utama.
3. Pengguna dapat memindai bahan makanan menggunakan kamera atau galeri (mode **Scan Food**) maupun barcode kemasan (mode **Barcode**).
4. Sistem dapat menampilkan hasil identifikasi bahan makanan (nama, kategori, kondisi visual, catatan AI, estimasi masa simpan per lokasi).
5. Pengguna dapat mengoreksi nama/kategori, mengisi jumlah, lokasi penyimpanan, dan tanggal pembelian, lalu menyimpan bahan ke Pantry.
6. Sistem menghitung tanggal estimasi akhir masa simpan secara otomatis dari tanggal pembelian dan estimasi masa simpan.
7. Pengguna dapat melihat, menambahkan, dan menghapus data bahan makanan.
8. Pengguna dapat mengubah seluruh detail bahan yang sudah tersimpan (nama, kategori, lokasi penyimpanan, jumlah, tanggal pembelian, estimasi masa simpan) melalui halaman Edit food details; foto hanya dapat diganti dengan memindai/menambahkan ulang bahan.
9. Perubahan jumlah tidak mengubah estimasi masa simpan.
10. Pengguna dapat mencari dan memfilter bahan berdasarkan kategori.
11. Pengguna dapat memperoleh rekomendasi resep berdasarkan data Pantry.
12. Filter lokasi penyimpanan hanya mempertimbangkan bahan pada lokasi yang dipilih.
13. Pengguna dapat memfilter rekomendasi berdasarkan cuisine.
14. Pengguna dapat melihat detail resep, termasuk bahan, peralatan, teknik memasak, dan langkah memasak.
15. Pengguna dapat menambahkan dan menghapus resep favorit.
16. Resep favorit dapat dibuka saat offline.
17. Sistem dapat memberikan pengingat lokal mengenai bahan makanan yang mendekati estimasi akhir masa simpannya, dengan maksimal 3 notifikasi individual + 1 notifikasi ringkasan per jadwal.
18. Saat offline, pengguna dapat membuka Pantry (read-only) dan resep favorit, sedangkan fitur scan, tambah manual, generate resep, ubah, dan hapus dinonaktifkan dengan pesan yang jelas.
19. Pengguna dapat mengelola profil dan preferensi aplikasi.
20. Data pengguna dan inventaris tersimpan sesuai akun masing-masing dan tidak dapat diakses pengguna lain.
21. Seluruh layanan yang digunakan berjalan pada free tier tanpa billing account dan tanpa kartu kredit/rekening.
22. Barcode yang tidak dikenali menampilkan pesan dan opsi scan ulang, beralih ke Scan Food, atau isi manual.
23. Dark Mode dapat diaktifkan/dinonaktifkan, langsung berlaku, dan tetap tersimpan setelah aplikasi dibuka kembali.
24. Pengguna dapat mengganti bahasa antarmuka antara English dan Indonesia, dan pilihannya tersimpan.
25. Pengguna dapat menghapus resep; resep yang dihapus hilang dari cache dan daftar favorit.

---

# 9. OUT OF SCOPE

Hal-hal berikut tidak termasuk dalam ruang lingkup pengembangan versi awal (MVP), kecuali nantinya disepakati sebagai pengembangan lanjutan:

- Marketplace atau transaksi jual beli bahan makanan.
- Integrasi dengan layanan pengiriman bahan makanan.
- Pemesanan makanan secara langsung.
- Sistem manajemen kasir dan akuntansi UMKM.
- Pengelolaan multi-cabang usaha.
- Prediksi keamanan makanan secara pasti.
- Integrasi dengan perangkat IoT.
- Sistem rekomendasi resep berdasarkan analisis nutrisi yang mendalam.
- Pemindaian banyak bahan makanan sekaligus dalam satu gambar.
- Pemindaian real-time melalui stream video kamera.
- Pemindaian atau pembuatan resep saat offline.
- Pembuatan gambar masakan menggunakan model image-generation (gambar resep menggunakan ilustrasi statis).
- Sinkronisasi foto bahan antarperangkat (foto hanya tersimpan lokal).
- Chat/interaksi percakapan dengan AI.
- Penggunaan layanan Firebase berbayar (Blaze), Cloud Storage, Cloud Functions, atau FCM.
- Sinkronisasi real-time antarperangkat di luar mekanisme Firestore standar.

---

# 10. SUCCESS METRICS

Keberhasilan pengembangan Optimeal dapat dievaluasi melalui beberapa indikator:

- Pengguna berhasil menyelesaikan proses registrasi dan login.
- Pengguna dapat menyimpan dan mengelola bahan makanan melalui Pantry.
- Fitur pemindaian mampu menghasilkan identifikasi yang dapat dikonfirmasi pengguna.
- Rekomendasi resep dapat dihasilkan berdasarkan bahan yang tersedia dan filter yang dipilih.
- Notifikasi dapat dikirim sesuai estimasi masa simpan yang tercatat.
- Resep favorit dapat dibuka kembali, termasuk saat offline.
- Pengguna dapat menyelesaikan alur utama aplikasi tanpa kendala fungsional yang kritis.
- Pengguna merasa terbantu dalam memantau dan memanfaatkan persediaan bahan makanan.
- Seluruh sistem berjalan tanpa biaya dan tanpa billing account.

---

# 11. BATASAN TEKNIS, KUOTA, DAN CACHING

| Parameter | Nilai | Keterangan |
|---|---|---|
| Ukuran gambar yang dikirim ke AI | 1024 px, ≤500 KB | Setelah kompresi. |
| Ukuran thumbnail foto lokal | 512 px, ±80 KB | Disimpan di perangkat. |
| Batas cache resep | 10 resep/pengguna | Eviction berdasarkan `lastAccessedAt`. |
| TTL cache resep | 7 hari | Dihapus bila tidak diakses. |
| Batas generate resep | 10/jam, 30/hari per pengguna | Melindungi kuota free tier AI. |
| Batas resep favorit | 50/pengguna | Menjaga ukuran penyimpanan lokal. |
| Ambang notifikasi default | 1 hari | Dapat diubah 1–3 hari. |
| Jumlah notifikasi per bahan | 2 | H-ambang dan H-0. |
| Batas notifikasi per jadwal | 3 individual + 1 ringkasan | Mencegah spam. |
| Retry pemanggilan AI | Maksimal 2 kali | Setelah itu tampilkan error. |
| Timeout proxy AI | 60 detik | — |
| Batas request Cloudflare Worker | 100.000/hari (free plan) | Cukup untuk pengembangan & demo. |
| Kapasitas Firestore | 1 GiB, 50.000 read/hari, 20.000 write/hari | Free tier Spark. |

---

# 12. RIWAYAT REVISI & KEPUTUSAN DESAIN

## 12.1 Ringkasan Perubahan

### v1.0 → v1.1

1. **Backend ditetapkan:** Firebase (Auth, Firestore, Storage, Cloud Functions).
2. **Pemanggilan AI melalui Cloud Functions**, API key tidak disimpan di client.
3. **Alur Food Scanner diperjelas:** AI mengembalikan bentuk/warna/karakteristik visual dan estimasi masa simpan per lokasi penyimpanan; pengguna melengkapi jumlah, lokasi penyimpanan, dan tanggal pembelian.
4. **Field editable setelah tersimpan:** hanya `purchaseDate`.
5. **Duplikasi "lokasi penyimpanan" pada daftar informasi bahan dihapus** dan diganti tabel yang jelas.
6. **Filter lokasi penyimpanan pada Recipe Finder diperjelas:** memfilter **bahan** yang dipertimbangkan, bukan atribut resep.
7. **Cuisine didefinisikan sebagai gaya memasak per negara/daerah.** Teknik memasak dipisah menjadi field `cookingTechnique`.
8. **Smart Notification memakai notifikasi lokal terjadwal** (bukan FCM).
9. **Mode offline didefinisikan eksplisit.**
10. **Fitur baru: Resep Favorit**, dengan snapshot lokal untuk akses offline.
11. **Batas cache & kuota AI ditambahkan.**

### v1.1 → v1.2

1. **Arsitektur nol biaya & nol kartu ditetapkan.** Seluruh layanan wajib berada pada free tier tanpa billing account.
2. **Cloud Functions dihapus** karena mewajibkan plan Blaze (butuh kartu). Diganti **proxy Cloudflare Workers free plan**.
3. **Cloud Storage dihapus.** Foto bahan disimpan **lokal di perangkat**; tidak ada `imageUrl` di Firestore.
4. **Firebase dikunci pada plan Spark**; proyek tidak boleh di-upgrade ke Blaze.
5. **Jumlah/kuantitas menjadi editable** setelah tersimpan (bersama tanggal pembelian). Prinsip baru: field identitas dikunci, field state boleh berubah.
6. **Kuantitas ditegaskan tidak mempengaruhi estimasi masa simpan**; fungsinya hanya informasi dan konteks porsi untuk AI.
7. **Rekomendasi gambar ditetapkan:** ilustrasi resep dibundel sebagai asset lokal; tidak memakai URL internet.
8. **Copywriting notifikasi diubah** menjadi "mendekati batas estimasi masa simpan" / "tinggal ±N hari", bukan pernyataan "basi".
9. **Penggabungan notifikasi ditambahkan:** maksimal 3 notifikasi individual + 1 ringkasan.
10. **Bagian 5.6 Model Biaya & Batasan Free Tier** ditambahkan.
11. **Acceptance criteria** ditambah poin nol biaya dan aturan kuantitas.

### v1.2 → v1.3

1. **Bagian 13 — Aturan Penggunaan AI** ditambahkan sebagai bagian wajib yang mengikat seluruh keluaran AI (kode, data, teks, dan desain).
2. **Figma ditetapkan sebagai acuan visual tunggal** untuk pembuatan dan implementasi desain.
3. **Larangan menyimpang** dari PRD dan `DevelopmentPlan.md` ditetapkan secara eksplisit, termasuk prosedur pelaporan bila ditemukan konflik.

### v1.3 → v1.4

1. **Figma "Balomba" (page HiFi Optimeal) ditetapkan sebagai acuan visual dan fungsional.** PRD diselaraskan dengan desain.
2. **Mode Barcode** ditambahkan pada Food Scanner, dengan endpoint baru `POST /analyze-barcode`.
3. **Edit food details:** seluruh detail bahan dapat diubah setelah tersimpan (nama, kategori, lokasi, jumlah, tanggal pembelian, estimasi masa simpan). Foto tetap tidak dapat diganti.
4. **Menu Profile dilengkapi:** Profile Details, Password, Notifications, Dark Mode, Support, About, Language, Logout.
5. **Dark Mode dan Language** ditambahkan; bahasa bawaan **English** dengan opsi **Indonesia**.
6. **Home disesuaikan dengan desain:** sapaan "Welcome back", kartu ringkasan per lokasi, banner bahan mendekati batas, preview Pantry (maks. 3), dan AI Recipe Recommendations.
7. **Detail resep** memakai tab Ingredients / Equipment / Instructions dan memiliki aksi hapus resep.
8. **Bahasa antarmuka** berpindah dari istilah Indonesia baku ke **English** (copy Indonesia tetap tersedia lewat Language).
9. **Acceptance criteria** diperluas untuk barcode, Edit food details, Dark Mode, Language, dan hapus resep.

### v1.4 → v1.5

1. **Bagian 13.7 — Aturan Alur Kerja Git untuk AI** ditambahkan: pekerjaan fitur dikerjakan di branch baru yang dibuat dari `main` terbaru, di-push, lalu di-merge ke `main`, kemudian `main` di-commit dan di-push.
2. **Aturan Utama AI** pada 13.6 diperluas dari tiga menjadi empat (ditambah alur kerja Git).
3. **Verifikasi keluaran AI** (13.5) ditambah pemeriksaan kepatuhan alur Git.

### v1.5 → v1.6

1. **Pustaka `mobile_scanner`** ditambahkan pada Bagian 5.1 untuk membaca barcode kemasan di mode **Barcode** Food Scanner. Pustaka ini gratis (open source), berjalan di perangkat, dan tidak menambah layanan berbayar.

### v1.6 → v1.7

1. **Pustaka `camera`** ditambahkan pada Bagian 5.1. Mode **Scan Food** menampilkan pratinjau kamera dan memotret langsung di layar Scanner, tanpa berpindah ke aplikasi kamera bawaan HP. `image_picker` tetap dipakai untuk memilih foto dari galeri.
2. Aplikasi dikunci pada orientasi **portrait**, sesuai desain Figma.

### v1.7 → v1.8

1. **Verifikasi akun memakai link email Firebase**, bukan kode OTP. Firebase Email/Password tidak menyediakan OTP bawaan, dan pengiriman kode lewat layanan email eksternal akan menambah layanan serta secret baru — bertentangan dengan prinsip nol biaya pada Bagian 5.6.
2. **Layar Verifikasi email** ditambahkan: instruksi, tombol *I've verified my email*, *Resend email* dengan jeda 60 detik, dan *Use a different account*.
3. **Profil `users/{uid}` dibuat saat registrasi** dengan nilai awal sesuai `Contracts.md` §3.5 (`themeMode = light`, `language = en`, `notificationsEnabled = true`, `notificationThresholdDays = 1`).

## 12.2 Keputusan yang Diambil

| Topik | Keputusan | Alasan |
|---|---|---|
| Backend | Firebase Spark (Auth + Firestore) | Gratis, tanpa kartu, dan plan Spark tidak dapat menagih. |
| Proxy AI | Cloudflare Workers free plan | Cloud Functions mewajibkan Blaze (butuh kartu). Workers gratis, tanpa kartu, dan mendukung secret. |
| Penyimpanan foto | Lokal di perangkat | Menghilangkan layanan berbayar/berisiko, mempercepat akses, dan otomatis tersedia saat offline. |
| Gambar resep | Ilustrasi asset lokal | Gratis, konsisten, tidak melanggar lisensi, dan tetap tampil saat offline. |
| Sumber estimasi masa simpan | AI memberi estimasi untuk tiga lokasi penyimpanan; sistem memilih sesuai lokasi yang dipilih pengguna, dengan katalog cadangan | Estimasi bergantung pada lokasi penyimpanan. Katalog cadangan mencegah kegagalan saat AI tidak memberi nilai. |
| Cuisine | Gaya memasak per negara/daerah | Makna standar "cuisine" dan paling andal dihasilkan AI. Teknik memasak menjadi field terpisah. |
| Notifikasi | Lokal terjadwal | Tidak memerlukan server push, tetap berfungsi offline, dan tidak menambah biaya. |
| Penempatan Resep Favorit | Tab pada halaman Recipe Finder | Favorit adalah bagian dari domain resep; mengurangi jumlah tap dan menghindari dua pintu masuk. |
| Field editable | Semua detail teks (`name`, `category`, `storageLocation`, `quantity`, `unit`, `purchaseDate`, `shelfLifeDays`); foto terkunci | Mengikuti desain Edit food details; foto tetap terkunci agar tidak menambah beban penyimpanan dan tetap konsisten dengan arsitektur nol biaya. |
| Batas cache resep | 10 resep/pengguna, TTL 7 hari | Menjaga kuota free tier AI tetap aman. |
| Acuan desain | Figma "Balomba" page HiFi Optimeal | Satu sumber visual agar implementasi UI konsisten (Bagian 13.2). |
| Bahasa UI | English (default) + Indonesia | Mengikuti desain Figma; Indonesia tetap tersedia untuk pengguna lokal. |
| Mode Barcode | Scan barcode kemasan melalui proxy (`/analyze-barcode`) | Mempercepat input produk kemasan dan mengurangi kesalahan identifikasi manual. |
| Kamera Scan Food | `camera` (v1.7) | Foto diambil di dalam aplikasi sesuai desain Scanner di Figma; gratis dan resmi dari tim Flutter. |
| Pustaka barcode | `mobile_scanner` (v1.6) | Membaca barcode di perangkat secara gratis; nilai barcode dikirim ke proxy, bukan gambarnya. |
| Nilai enum lokasi penyimpanan | `room_temperature` / `fridge` / `freezer`; label UI tetap **Pantry** / **Fridge** / **Freezer** | `room_temperature` mewakili penyimpanan suhu ruang secara eksplisit, sementara pengguna tetap melihat istilah "Pantry" yang familiar. |
| Alur kerja Git AI | Satu fitur = satu branch dari `main` terbaru; push branch, merge ke `main`, lalu commit & push `main` | Tiga developer bekerja paralel; branch per fitur mencegah konflik dan menjaga `main` tetap bersih (Bagian 13.7). |
| Verifikasi akun | Link email Firebase (bukan OTP) | Gratis, tanpa layanan email tambahan, dan sudah tersedia di Firebase Authentication. Pengguna wajib verifikasi sebelum masuk. |

## 12.3 Catatan Terbuka

1. **Foto tidak tersinkron antarperangkat.** Pengguna yang login di perangkat lain akan melihat ikon kategori sebagai ganti foto. Konsekuensi ini diterima karena menghindari layanan berbayar.
2. **Free tier Gemini memiliki rate limit yang bisa berubah sewaktu-waktu.** Perlu pengujian beban ringan sebelum hari demo dan penyediaan mock mode.
3. **Cloudflare Workers free plan memiliki batas CPU time.** Untuk kebutuhan proxy I/O-bound hal ini cukup, namun perlu diuji dengan gambar berukuran maksimum.
4. **Batas kuota** (Bagian 11) merupakan nilai awal dan dapat ditinjau setelah pengujian.
5. **Kapasitas Firestore gratis 1 GiB** cukup untuk skala lomba; perlu dipantau bila data demo diperbanyak.
6. **UI Resep Favorit belum ada di Figma.** Desain saat ini hanya menampilkan daftar resep dengan filter dan pencarian, serta detail resep dengan tab Ingredients/Equipment/Instructions. Tab **Favorit** dan tombol favorit pada detail resep belum digambar; perlu ditambahkan ke Figma sebelum implementasi 3.8.
7. **Label lokasi penyimpanan di Figma belum seragam.** Home memakai *Room / Fridge / Chiller*, sedangkan tab Pantry dan form Edit food details memakai *Pantry / Fridge / Freezer*. **Keputusan v1.4:** nilai data `room_temperature` / `fridge` / `freezer`, label UI **Pantry / Fridge / Freezer**. Figma Home masih perlu dirapikan (Room → Pantry, Chiller → Freezer).
8. **Mode Barcode membutuhkan endpoint baru** `POST /analyze-barcode`. Strategi identifikasi produk (lookup katalog vs prompt model) ditentukan Developer 1 pada Tahap 0/1.
9. **Status bar pada desain bergaya iOS**, sedangkan target platform adalah Android. Komponen status bar akan diganti status bar sistem Android saat implementasi.
10. **Aksi hapus resep** menghapus data dari cache dan favorit; perlu dialog konfirmasi agar tidak menghapus favorit pengguna secara tidak sengaja.

---

# 13. ATURAN PENGGUNAAN AI

## 13.1 Tujuan

Bagian ini mengatur cara AI (asisten coding/desain berbasis AI, termasuk MCP dan tool otomatis) digunakan selama pengembangan Optimeal. Tujuannya agar keluaran AI tetap konsisten dengan keputusan produk dan rencana teknis yang telah disepakati tim, serta mencegah AI menambah atau mengubah lingkup secara sepihak.

## 13.2 Aturan Wajib

1. **Wajib mengikuti `DevelopmentPlan.md` dan PRD ini.**
   Setiap keluaran AI — kode, struktur folder, model data, kontrak endpoint, teks UI, copywriting, aset, maupun desain — harus mengikuti ketentuan pada `Docs/PRD.md` dan `Docs/DevelopmentPlan.md`. Apabila keduanya belum mengatur suatu hal, AI wajib bertanya atau mengusulkan, bukan memutuskan sendiri.

2. **Desain Figma adalah acuan visual tunggal.**
   Ketika membuat atau mengimplementasikan desain (UI, komponen, layout, state), hasilnya harus **sama dengan yang ada di Figma** (file desain resmi tim): struktur layout, hierarki, spacing, tipografi, warna, ikon, ilustrasi, dan penamaan komponen. AI dilarang mengganti, menyederhanakan, atau menambah elemen visual atas inisiatif sendiri. Bila komponen atau token yang dibutuhkan tidak tersedia di Figma, AI wajib melaporkannya, bukan mengarang desain baru.

3. **Dilarang keluar dari aturan `DevelopmentPlan.md` dan PRD.**
   AI tidak boleh menambah fitur, mengubah alur pengguna, mengubah skema data atau kontrak endpoint, menambah dependensi/layanan di luar daftar, mengubah batasan kuota/cache, atau mengubah keputusan desain yang sudah ditetapkan. Seluruh pekerjaan harus berada di dalam ruang lingkup Bagian 2 dan Bagian 9.

## 13.3 Turunan Aturan Wajib

Aturan pada 13.2 berlaku konkret pada hal-hal berikut:

**Produk & lingkup**
- Tidak membuat fitur atau halaman yang tidak tercantum pada Bagian 2, 3, dan 4.
- Tidak menghidupkan kembali hal yang sudah dinyatakan *Out of Scope* (Bagian 9).

**Arsitektur & biaya**
- Tidak mengaktifkan Blaze, Cloud Storage, Cloud Functions, FCM, atau layanan berbayar lain.
- Tidak mengubah panggilan AI menjadi langsung dari client; seluruhnya tetap melalui proxy Cloudflare Workers.
- Tidak menyimpan API key di aplikasi client.

**Data & kontrak**
- Tidak menambah, menghapus, atau mengganti nama field pada model `FoodItem`, `Recipe`, `Notification`, dan `FavoriteRecipe` tanpa persetujuan tim.
- Tidak mengubah path/format endpoint `POST /analyze-food` dan `POST /generate-recipes`.
- Tidak mengubah aturan field yang dapat diedit setelah tersimpan tanpa persetujuan: saat ini seluruh detail teks boleh diubah melalui **Edit food details**, sedangkan **foto tetap terkunci**.

**UI & copywriting**
- Tidak mengganti istilah baku: "approaching shelf-life estimate" / "mendekati batas estimasi masa simpan", "Mode Offline", atau label lokasi `Pantry` / `Fridge` / `Freezer`.
- Tidak membuat ilustrasi resep atau gambar makanan melalui model image-generation; aset tetap ilustrasi lokal yang dibundel.

**Perilaku offline**
- Tidak mengaktifkan fitur tulis, scan, atau generate resep saat offline.
- Tidak menyembunyikan tombol yang tidak tersedia; tetap ditampilkan nonaktif dengan keterangan.

## 13.4 Prosedur Bila Ditemukan Ketidaksesuaian

Apabila AI menemukan permintaan, desain Figma, atau kode yang **bertentangan** dengan PRD/`DevelopmentPlan.md`:

1. **Berhenti** dan jangan berimprovisasi atau memilih salah satu versi sendiri.
2. **Laporkan konflik** secara ringkas: bagian mana yang bertentangan, isi PRD/DevelopmentPlan, dan usulan penyelesaian.
3. **Tunggu keputusan tim.** Bila disetujui, perbarui dokumen (PRD/DevelopmentPlan) dan naikkan versinya **sebelum** implementasi dilakukan.
4. Implementasi hanya boleh mengikuti dokumen yang sudah diperbarui.

## 13.5 Verifikasi Keluaran AI

Sebelum hasil AI diterima, lakukan pemeriksaan berikut:

| No | Pemeriksaan | Kriteria lulus |
|---|---|---|
| 1 | Kesesuaian dengan PRD | Tidak ada fitur, field, alur, atau teks di luar PRD. |
| 2 | Kesesuaian dengan `DevelopmentPlan.md` | Struktur, kontrak endpoint, dan pembagian tanggung jawab sesuai rencana. |
| 3 | Kesesuaian dengan Figma | Layout, komponen, warna, tipografi, dan spacing sama dengan file Figma. |
| 4 | Batasan biaya | Tidak ada layanan yang memerlukan billing account atau kartu. |
| 5 | Keamanan | Tidak ada API key, data pengguna lain, atau data sensitif yang bocor. |
| 6 | Perilaku offline | State dan penonaktifan fitur sesuai Bagian 2.4 dan 7.5. |
| 7 | Alur kerja Git | Pekerjaan fitur berada di branch sendiri, sudah di-push, dan di-merge ke `main` sesuai Bagian 13.7. |

Keluaran AI yang tidak lulus pemeriksaan di atas **wajib diperbaiki atau ditolak**, bukan diterima sebagian.

## 13.6 Ringkasan Empat Aturan Utama

1. **Ikuti `DevelopmentPlan.md` dan PRD** — tanpa pengecualian.
2. **Desain harus sama dengan Figma** — jangan menambah, mengurangi, atau menggaya ulang sendiri.
3. **Jangan keluar dari aturan PRD dan `DevelopmentPlan.md`** — bila ragu atau menemukan konflik, berhenti dan tanyakan.
4. **Ikuti alur kerja Git (13.7)** — fitur dikerjakan di branch sendiri dari `main` terbaru, di-push, di-merge ke `main`, lalu `main` di-commit dan di-push.

## 13.7 Aturan Alur Kerja Git untuk AI

Aturan ini berlaku ketika AI (atau developer yang dibantu AI) mengerjakan fitur. Karena pengembangan dilakukan oleh tiga developer secara paralel dengan modul masing-masing (lihat `DevelopmentPlan.md`), setiap fitur dikerjakan terisolasi pada branch tersendiri.

### 13.7.1 Alur Wajib per Fitur

Urutan berikut harus dijalankan **secara berurutan**:

| Langkah | Aksi | Perintah contoh |
|---|---|---|
| 1 | Pindah ke `main` dan tarik perubahan terbaru (**pull main**) sebelum memulai. | `git checkout main` → `git pull origin main` |
| 2 | Buat **branch baru** dari `main` yang sudah terbaru. | `git checkout -b feature/<nama-fitur>` |
| 3 | Kerjakan fitur **hanya di branch tersebut**, dengan commit kecil dan bermakna. | `git add <file>` → `git commit -m "feat: ..."` |
| 4 | **Push** branch fitur ke remote. | `git push -u origin feature/<nama-fitur>` |
| 5 | Setelah fitur selesai dan lulus verifikasi (13.5), **merge ke `main`**. | `git checkout main` → `git pull origin main` → `git merge feature/<nama-fitur>` |
| 6 | Setelah merge, pastikan hasil di `main` **sudah di-commit dan di-push**. | `git push origin main` |

### 13.7.2 Ketentuan

1. **Satu fitur, satu branch.** Branch tidak boleh dipakai ulang untuk fitur lain. Fitur dari developer berbeda tidak boleh dicampur dalam satu branch.
2. **Selalu pull `main` sebelum membuat branch** dan sebelum merge, agar branch berangkat dari kondisi terbaru dan konflik diminimalkan.
3. **Dilarang mengerjakan fitur langsung di `main`.** Commit langsung ke `main` hanya diperbolehkan untuk perubahan dokumen kecil (mis. revisi PRD/DevelopmentPlan) atau hasil merge branch fitur.
4. **Penamaan branch** mengikuti pola `feature/<modul>-<deskripsi-singkat>` dengan huruf kecil dan tanda hubung, selaras dengan pembagian modul pada `DevelopmentPlan.md`. Contoh: `feature/scanner-barcode-mode`, `feature/pantry-edit-food-details`, `feature/recipe-favorites`. Untuk perbaikan bug gunakan `fix/<deskripsi>`.
5. **Penamaan commit** memakai awalan konvensional: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, diikuti deskripsi singkat.
6. **Merge hanya setelah fitur selesai** sesuai *Definition of Done* pada `DevelopmentPlan.md` dan lulus verifikasi 13.5. Fitur yang belum selesai tidak boleh di-merge ke `main`.
7. **`main` harus selalu dapat dijalankan.** Pastikan aplikasi dapat di-build (`flutter analyze` dan `flutter run`) sebelum merge.
8. **Jangan menyertakan rahasia.** API key, `google-services.json` berisi kredensial sensitif, token, atau file `.env` tidak boleh di-commit (selaras dengan 7.2 dan 13.3).
9. **Konflik merge** diselesaikan dengan mempertahankan pekerjaan kedua pihak. Bila konflik menyentuh model data atau kontrak endpoint, **berhenti dan laporkan** sesuai 13.4.
10. **Tidak memakai operasi destruktif** (`git push --force`, `git reset --hard` pada `main`, menghapus branch milik developer lain) tanpa persetujuan eksplisit tim.
11. **Bukan hanya fitur:** apabila AI mengerjakan perubahan lintas fitur, pecah menjadi beberapa branch sesuai fitur, bukan satu branch besar.

### 13.7.3 Ringkasan Alur

```
main (pull terbaru)
  └─ branch baru: feature/<nama-fitur>
        ├─ kerjakan fitur + commit
        └─ push branch
  └─ merge ke main
        └─ commit & push main
```
```
