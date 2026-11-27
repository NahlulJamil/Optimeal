# KONTRAK DATA & API — OPTIMEAL

**Versi:** 1.1

**Mengacu pada:** PRD Optimeal v1.14 dan DevelopmentPlan v1.11

**Pemilik:** Developer 1 (Core Application, Backend & Integrasi)

**Berlaku untuk:** Developer 1, Developer 2, Developer 3, kode Cloudflare Worker, dan fixture mock.

> **Posisi dokumen ini:** penjabaran teknis dari PRD Bagian 6 (Data Requirements) dan kontrak Cloudflare Worker pada DevelopmentPlan. Dokumen ini **tidak menambah aturan produk**. Jika ada pertentangan, PRD dan DevelopmentPlan yang menang, dan kontrak ini wajib diperbaiki (lihat Bagian 7).

---

## 1. KONVENSI

| Hal | Aturan |
|---|---|
| Penamaan field | `camelCase` di JSON, Dart, dan dokumen Firestore. |
| Penamaan enum value | `snake_case`, huruf kecil semua. |
| Tipe ID | `String`. Tidak ada ID numerik. |
| Waktu di database | Firestore `Timestamp`. |
| Waktu di JSON API | ISO-8601 UTC dengan akhiran `Z`, contoh `2026-05-18T00:00:00.000Z`. |
| Waktu di UI | Di-format di client dengan `intl`. **Jangan menyimpan string tanggal hasil format.** |
| Format tanggal English | `MMM d, yyyy` → `May 18, 2026` |
| Format tanggal Indonesia | `d MMM yyyy` → `18 Mei 2026` |
| Field opsional | Boleh `null`. Field yang tidak ada dianggap `null`. |
| Boolean | Awalan `has`/`is` (mis. `hasPhoto`). |
| Satuan | String bebas: `g`, `kg`, `pcs`, `bunch`, `ml`, `L`, dll. |
| Angka hari | Integer ≥ 1. Tidak boleh 0 atau negatif. |

**Aturan penting tanggal:** contoh di Figma `May 18, 2026` adalah **format tampilan**, bukan format penyimpanan. Database dan API selalu memakai ISO-8601/Timestamp agar bisa dihitung, diurutkan, dan dikonversi ke bahasa apa pun.

---

## 2. ENUM

### 2.1 `StorageLocation`

| Nilai data | Label UI | Keterangan |
|---|---|---|
| `room_temperature` | **Pantry** | Penyimpanan suhu ruang. |
| `fridge` | **Fridge** | Kulkas. |
| `freezer` | **Freezer** | Freezer. |

- Label UI **tidak** diterjemahkan antar bahasa; tetap `Pantry` / `Fridge` / `Freezer`.
- Catatan: Home di Figma masih menulis *Room* / *Chiller*; Figma perlu dirapikan agar sama dengan tabel ini.

### 2.2 `ThemeMode`

`light` · `dark` — default `light`.

### 2.3 `Language`

`en` · `id` — default `en`.

### 2.4 `NotificationStatus`

`scheduled` · `delivered` · `read` · `cancelled`.

---

## 3. MODEL

### 3.1 `FoodItem`

Path: `users/{uid}/pantry/{foodId}`

| Field | Tipe | Nullable | Sumber | Keterangan |
|---|---|---|---|---|
| `foodId` | String | ❌ | Sistem | ID dokumen. |
| `userId` | String | ❌ | Sistem | Sama dengan `uid`. |
| `name` | String | ❌ | AI / pengguna | Bisa dikoreksi. |
| `category` | String | ❌ | AI / pengguna | Mis. `Fruit`, `Vegetable`. |
| `quantity` | Number | ✅ | Pengguna | Boleh kosong. |
| `unit` | String | ✅ | Pengguna | Wajib diisi bila `quantity` diisi. |
| `storageLocation` | `StorageLocation` | ❌ | Pengguna | `room_temperature` / `fridge` / `freezer`. |
| `purchaseDate` | Timestamp | ❌ | Pengguna | Default hari ini, pukul 00:00 lokal. |
| `shelfLifeDays` | Integer | ❌ | AI / pengguna | ≥ 1. Bisa di-override manual. |
| `estimatedEndDate` | Timestamp | ❌ | Sistem | `purchaseDate + shelfLifeDays`. Dihitung ulang setiap kali salah satu berubah. |
| `visualCondition` | String | ✅ | AI | Boleh kosong untuk hasil barcode. |
| `aiNote` | String | ✅ | AI | Opsional. |
| `hasPhoto` | Boolean | ❌ | Sistem | Default `false`. |
| `createdAt` | Timestamp | ❌ | Sistem | — |
| `updatedAt` | Timestamp | ❌ | Sistem | — |

**Contoh JSON (wire format):**

```json
{
  "foodId": "f_9x2Kp",
  "userId": "uid_123",
  "name": "Strawberries",
  "category": "Fruit",
  "quantity": 1,
  "unit": "punnet",
  "storageLocation": "fridge",
  "purchaseDate": "2026-11-07T00:00:00.000Z",
  "shelfLifeDays": 4,
  "estimatedEndDate": "2026-11-11T00:00:00.000Z",
  "visualCondition": "Starting to soften, color is still red.",
  "aiNote": "Slight moisture in the container, no visible mold.",
  "hasPhoto": true,
  "createdAt": "2026-11-07T03:12:44.000Z",
  "updatedAt": "2026-11-07T03:12:44.000Z"
}
```

**Aturan turunan:**

- `quantity` tanpa `unit` dianggap tidak valid → tampilkan `—` di UI, jangan menebak satuan.
- Mengubah `storageLocation` memilih ulang `shelfLifeDays` default, kecuali pengguna sudah mengisi manual.
- `estimatedEndDate` **tidak pernah** dikirim dari client; selalu dihitung sistem.

### 3.2 `Recipe`

Path: `users/{uid}/recipes/{recipeId}`

| Field | Tipe | Nullable | Keterangan |
|---|---|---|---|
| `recipeId` | String | ❌ | ID unik. |
| `name` | String | ❌ | — |
| `description` | String | ❌ | — |
| `illustrationKey` | String | ❌ | Kunci ikon cadangan, bukan URL. Foto resep tidak disimpan di model ini (PRD 6.3). |
| `cuisine` | String | ❌ | Mis. `Western`, `Indonesian`. |
| `cookingTechnique` | String | ❌ | Mis. `Saute`, `Steam`. |
| `cookingTimeMinutes` | Integer | ❌ | ≥ 1. |
| `ingredientsAvailable` | List\<String\> | ❌ | Bahan yang ada di Pantry. |
| `ingredientsMissing` | List\<String\> | ❌ | Bahan tambahan. |
| `equipment` | List\<String\> | ❌ | Peralatan. |
| `steps` | List\<String\> | ❌ | Urut langkah memasak. |
| `generatedAt` | Timestamp | ❌ | — |
| `lastAccessedAt` | Timestamp | ❌ | Untuk kebijakan cache. |

**Contoh JSON:**

```json
{
  "recipeId": "r_001",
  "name": "Spinach Pasta",
  "description": "Creamy pasta with fresh spinach and garlic.",
  "illustrationKey": "recipe_western_pasta",
  "cuisine": "Western",
  "cookingTechnique": "Saute",
  "cookingTimeMinutes": 15,
  "ingredientsAvailable": ["150 g pasta", "100 g fresh spinach"],
  "ingredientsMissing": ["100 ml cooking cream", "30 g Parmesan"],
  "equipment": ["Cooking pot", "Frying pan", "Strainer"],
  "steps": ["Boil the pasta until al dente.", "Saute garlic and onion.", "Add spinach and cream.", "Combine and serve."],
  "generatedAt": "2026-11-19T04:00:00.000Z",
  "lastAccessedAt": "2026-11-19T04:00:00.000Z"
}
```

### 3.3 `FavoriteRecipe`

Path: `users/{uid}/favorites/{recipeId}`

| Field | Tipe | Nullable | Keterangan |
|---|---|---|---|
| `favoriteId` | String | ❌ | Sama dengan `recipeId`. |
| `userId` | String | ❌ | — |
| `recipeSnapshot` | Map\<Recipe\> | ❌ | Salinan lengkap untuk mode offline. |
| `savedAt` | Timestamp | ❌ | — |

### 3.4 `NotificationRecord`

Path: `users/{uid}/notifications/{notificationId}`

| Field | Tipe | Nullable | Keterangan |
|---|---|---|---|
| `notificationId` | String | ❌ | ID notifikasi lokal. |
| `userId` | String | ❌ | — |
| `foodId` | String | ❌ | ID bahan, atau `"summary"` untuk notifikasi ringkasan. |
| `title` | String | ❌ | — |
| `body` | String | ❌ | — |
| `scheduledAt` | Timestamp | ❌ | — |
| `status` | `NotificationStatus` | ❌ | — |

### 3.5 `UserProfile`

Path: `users/{uid}`

| Field | Tipe | Nullable | Keterangan |
|---|---|---|---|
| `uid` | String | ❌ | Firebase UID. |
| `name` | String | ❌ | — |
| `email` | String | ❌ | — |
| `photoUrl` | String | ✅ | URL foto profil Firebase (bukan foto bahan). |
| `themeMode` | `ThemeMode` | ❌ | Default `light`. |
| `language` | `Language` | ❌ | Default `en`. |
| `notificationsEnabled` | Boolean | ❌ | Default `true`. |
| `notificationThresholdDays` | Integer | ❌ | 1–3, default `1`. |
| `createdAt` | Timestamp | ❌ | — |
| `updatedAt` | Timestamp | ❌ | — |

### 3.6 `ShelfLifeEstimate`

Dipakai bersama oleh `analyze-food` dan `analyze-barcode`.

```json
{
  "room_temperature": 1,
  "fridge": 4,
  "freezer": 30
}
```

Ketiga key wajib ada dan bernilai integer ≥ 1. Bila AI gagal memberi nilai valid, client memakai `foodCatalog/{category}`.

---

## 4. API

### 4.1 Umum

- **Base URL:** `https://optimeal-ai.<subdomain>.workers.dev`
- **Auth:** `Authorization: Bearer <Firebase ID Token>` pada **setiap** request.
- **Content-Type:** `application/json`
- **Timeout:** 60 detik
- **Retry:** maksimal 2 kali untuk `500` dan `504`. Tidak retry untuk `400`, `401`, `404`, `422`, `429`.
- **Client tidak pernah memanggil Gemini langsung.**

**Format error (semua endpoint):**

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or expired token"
  }
}
```

| HTTP | `code` | Penyebab |
|---|---|---|
| 400 | `INVALID_INPUT` | Body tidak valid / field wajib kosong. |
| 401 | `UNAUTHORIZED` | Firebase ID token tidak ada atau kedaluwarsa. |
| 404 | `NOT_FOUND` | Produk barcode tidak dikenali. |
| 422 | `EMPTY_INGREDIENTS` | Daftar bahan kosong. |
| 429 | `RATE_LIMITED` | Kuota AI / rate limit pengguna. |
| 500 | `AI_FAILURE` | Layanan AI gagal. |
| 504 | `TIMEOUT` | AI melewati batas waktu. |

Pesan error tidak boleh membocorkan detail internal (prompt, nama model, stack trace).

### 4.2 `POST /analyze-food`

**Input:**

```json
{
  "imageBase64": "string",
  "mimeType": "image/jpeg"
}
```

- Gambar sudah dikompresi client: maksimal 1024 px, ≤ 500 KB.
- `mimeType`: `image/jpeg` atau `image/png`.

**Output 200:**

```json
{
  "name": "Strawberries",
  "category": "Fruit",
  "confidence": 0.93,
  "visualCondition": "Color is still red, skin slightly soft.",
  "aiNote": "Slight moisture in the container.",
  "shelfLifeDays": { "room_temperature": 1, "fridge": 4, "freezer": 30 }
}
```

**Error:** `400`, `401`, `429`, `500`, `504`.

### 4.3 `POST /analyze-barcode`

**Input:**

```json
{ "barcode": "8991234567890" }
```

**Output 200:**

```json
{
  "name": "Greek Yogurt",
  "category": "Dairy",
  "brand": "Example Brand",
  "packageSize": "500 g",
  "confidence": 0.88,
  "shelfLifeDays": { "room_temperature": 1, "fridge": 14, "freezer": 60 }
}
```

**Error:** `400` (barcode tidak valid), `401`, `404` (produk tidak dikenali), `429`, `500`, `504`.

**Catatan implementasi:** strategi lookup (katalog produk vs model) diputuskan Developer 1. Kontrak respons tidak berubah apa pun strateginya.

### 4.4 `POST /generate-recipes`

**Input:**

```json
{
  "ingredients": [
    { "name": "Spinach", "quantity": 200, "unit": "g", "storageLocation": "fridge" }
  ],
  "filters": { "cuisine": "Western" },
  "excludeRecipeIds": ["r_001"]
}
```

- `quantity` dan `unit` boleh `null`.
- `filters.cuisine` boleh `null` (artinya lintas cuisine).
- `storageLocation` memakai nilai enum, **bukan** label UI.

**Output 200:**

```json
{
  "recipes": [
    {
      "recipeId": "r_002",
      "name": "Spinach Omelette",
      "description": "Quick breakfast using pantry staples.",
      "cuisine": "Western",
      "cookingTechnique": "Pan-fry",
      "cookingTimeMinutes": 10,
      "ingredientsAvailable": ["200 g spinach", "2 eggs"],
      "ingredientsMissing": ["Butter"],
      "equipment": ["Frying pan", "Spatula"],
      "steps": ["Beat the eggs.", "Saute spinach.", "Pour eggs and cook.", "Serve."]
    }
  ]
}
```

**Error:** `400`, `401`, `422`, `429`, `500`, `504`.

---

## 5. FIXTURE MOCK

Semua developer memakai fixture yang sama sampai backend siap:

| File | Isi | Dipakai untuk |
|---|---|---|
| `assets/fixtures/food_items.json` | 5 `FoodItem` | Home, Pantry, Detail Food, Edit food details |
| `assets/fixtures/recipes.json` | 3 `Recipe` | Recipe Finder, detail resep |
| `assets/fixtures/user_profile.json` | 1 `UserProfile` | Profile, Dark Mode, Language |
| `assets/fixtures/ai_responses.json` | `analyze-food`, `analyze-barcode`, `generate-recipes` | Mock mode |

Aturan fixture:

- Nilai enum wajib valid (terutama `room_temperature`).
- Tanggal memakai ISO-8601 UTC.
- Jangan menaruh URL gambar internet di fixture.
- Fixture diperbarui bersama; kalau kontrak berubah, fixture ikut berubah di commit yang sama.

---

## 6. ATURAN INTEGRASI

1. **Validasi hasil AI di client:** `name` dan `category` tidak kosong, `confidence` 0–1, semua `shelfLifeDays` integer ≥ 1, `storageLocation` termasuk enum.
2. **Fallback estimasi:** jika `shelfLifeDays` tidak valid, pakai `foodCatalog/{category}`.
3. **Offline:** seluruh operasi tulis, `analyze-food`, `analyze-barcode`, dan `generate-recipes` nonaktif. Baca Pantry dan favorit tetap jalan dari cache.
4. **Foto:** hanya `hasPhoto` yang masuk Firestore. Path file disimpan lokal di `foodPhotos/{foodId}`.
5. **Rate limit aplikasi:** generate resep maksimal 10/jam dan 30/hari per pengguna; dicek di client sebelum memanggil Worker.
6. **Mock mode:** `--dart-define=USE_MOCK=true` membuat layer API membaca fixture, bukan HTTP.

---

## 7. PROSES PERUBAHAN KONTRAK

1. Perubahan field/enum/endpoint **wajib** dibahas dengan Developer 2 dan Developer 3.
2. Jika perubahan menyentuh perilaku produk, perbarui **PRD** dan naikkan versinya lebih dulu.
3. Perbarui `Contracts.md` beserta fixture pada commit yang sama.
4. Naikkan versi dokumen ini dan catat perubahannya di tabel bawah.

| Versi | Tanggal | Perubahan |
|---|---|---|
| 1.0 | 19 Nov 2026 | Versi awal: model `FoodItem`, `Recipe`, `FavoriteRecipe`, `NotificationRecord`, `UserProfile`; endpoint `analyze-food`, `analyze-barcode`, `generate-recipes`; enum `storageLocation` memakai `room_temperature`. |
| 1.1 | 27 Nov 2026 | `illustrationKey` menjadi kunci ikon cadangan karena foto resep kini dari Wikimedia Commons (PRD v1.14). Tidak ada perubahan field atau endpoint. |
