# Cloudflare Worker — Optimeal AI Proxy

Proxy tunggal untuk semua panggilan Gemini. API key **hanya** hidup di sini,
tidak pernah masuk ke aplikasi Flutter.

**Deployed:** https://optimeal-ai.nahluljamil-a.workers.dev

Model Gemini saat ini `gemini-3.8-flash` (diatur lewat `vars.GEMINI_MODEL`).
Kalau Google mengganti nama model, cukup ubah nilai itu lalu deploy ulang —
tidak perlu menyentuh kode.

## Endpoint

| Method | Path | Auth |
|---|---|---|
| POST | `/analyze-food` | `Authorization: Bearer <Firebase ID Token>` |
| POST | `/analyze-barcode` | sama |
| POST | `/generate-recipes` | sama |

Kontrak request/response ada di `Docs/Contracts.md`.

## Setup lokal

```powershell
cd worker
npm install
copy .dev.vars.example .dev.vars
# isi GEMINI_API_KEY di .dev.vars
npx wrangler dev
```

`.dev.vars` sudah masuk `.gitignore`. Jangan pernah commit isinya.

## Deploy

```powershell
npx wrangler login
npx wrangler secret put GEMINI_API_KEY
npx wrangler deploy
```

`FIREBASE_PROJECT_ID` dan `GEMINI_MODEL` bukan rahasia, jadi disimpan di
`wrangler.jsonc` bagian `vars`.

## Tes cepat

```powershell
# tanpa token -> 401
curl.exe -s -X POST http://127.0.0.1:8787/analyze-food -H "Content-Type: application/json" -d "{}"

# barcode tidak valid -> 400
curl.exe -s -X POST http://127.0.0.1:8787/analyze-barcode -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d '{\"barcode\":\"abc\"}'

# ingredients kosong -> 422
curl.exe -s -X POST http://127.0.0.1:8787/generate-recipes -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d '{\"ingredients\":[]}'
```

## Catatan implementasi

- **`/analyze-barcode`** memakai Open Food Facts (gratis, tanpa key) untuk
  lookup produk, lalu Gemini hanya mengklasifikasikan kategori dan estimasi
  masa simpan. Kalau produk tidak ada → `404 NOT_FOUND`; kalau Open Food
  Facts tidak bisa dihubungi → `500 AI_FAILURE` (client boleh retry).
  `brand`/`packageSize` bernilai `null` bila kosong (Contracts §4.3).
  Nama produk diambil dari katalog (`product_name`, lalu `product_name_id`,
  `product_name_en`, `generic_name`, …) sesuai yang tertulis di kemasan.
  Bila Gemini gagal (kuota/timeout), Worker tetap mengembalikan nama, merek,
  ukuran, dan kategori tebakan dari katalog dengan `shelfLifeDays: null`;
  aplikasi lalu memakai katalog cadangan masa simpan (Contracts §6.2).
  Kategori memakai daftar kategori aplikasi (`Vegetables` … `Others`).
- Aplikasi juga membaca **QR code** kemasan (GS1 Digital Link,
  `…/01/<GTIN>`) dan mengirim GTIN-nya ke endpoint ini.
- **`/generate-recipes`**: `recipeId` selalu dibuat Worker (`r_<uuid>`),
  bukan oleh AI, supaya unik antar-generate dan aman sebagai ID dokumen
  Firestore. Resep yang field wajibnya tidak lengkap dibuang; input dibatasi
  60 bahan (nama ≤ 80 karakter). `excludeRecipeIds` tetap diterima sesuai
  kontrak, tetapi tidak dipakai lagi karena ID kini selalu baru.
- **`/analyze-food`** memakai Gemini vision dengan `responseSchema`, jadi
  output selalu JSON sesuai kontrak.
- Rate limit per pengguna (10/jam, 30/hari) belum diterapkan di Worker; untuk
  saat ini dicek di client sesuai `Contracts.md`. Kalau kuota Gemini habis,
  Worker mengembalikan `429 RATE_LIMITED`.
- Timeout Gemini 55 detik → `504 TIMEOUT`.
