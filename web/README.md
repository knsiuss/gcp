# Arcade Labs — Web Portal

Dashboard statis (Vite + React + TypeScript) untuk repo solver GCP Arcade labs.

Fitur:
- **Katalog 37+ lab** — semua script solver di-embed, bisa dicari, difilter kategori, dan dilihat per file.
- **Connect Google Skills profile** — tempel public profile URL Cloud Skills Boost, portal otomatis ambil badge kamu dan menandai lab yang sudah diambil.
- **Kelompokan Sudah / Belum diambil** — filter sidebar + check di tiap lab.
- **Quota Arcade 2026** — tracker target badge/bulan + estimasi Arcade Points (season 1 Jan – 31 Des 2026), target bisa diatur.
- **Auto-update dari GitHub** — GitHub Actions rebuild & deploy tiap push, dan refresh data badge tiap 12 jam.

## Struktur

```
web/
  scripts/generate-catalog.mjs   # scan repo → src/generated/catalog.ts
  scripts/fetch-profile.mjs      # fetch badge public profile → public/profile-data.json
  src/generated/catalog.ts       # AUTO-GENERATED
  src/lib/types.ts               # tipe data
  src/lib/catalog.ts             # filter & helper
  src/lib/matching.ts            # mapping badge → lab (alias + fuzzy)
  src/lib/profile.ts             # loader profil (server JSON + proxy browser)
  src/lib/storage.ts             # localStorage
  src/lib/useArcade.ts           # state hook (profil, overrides, target, statistik)
  src/components/                # Sidebar, LabDetail, Dashboard, ProfileCard, QuotaCard, CodeBlock, CopyButton
```

## Setup profile (auto-update badge)

1. Buka `web/public/profile-source.json` dan isi public profile URL / id kamu:
   ```json
   { "profileUrl": "https://www.cloudskillsboost.google/public_profiles/<id-kamu>" }
   ```
2. Commit & push. Workflow `profile-update` (tiap 12 jam + tiap push ke file ini) akan
   fetch badge dan menulis `web/public/profile-data.json` otomatis.
3. Portal membaca `profile-data.json` (same-origin, tanpa CORS). Pastikan profile
   Cloud Skills Boost kamu **public**.

Alternatif cepat tanpa GitHub Actions: tempel URL di kartu "Connect" di dashboard —
portal coba fetch lewat CORS proxy dan simpan di localStorage browser.

## GitHub Actions

- `.github/workflows/deploy.yml` — rebuild & deploy ke GitHub Pages tiap push ke `web/**`.
  Aktifkan di **repo Settings → Pages → Source: GitHub Actions**.
- `.github/workflows/profile-update.yml` — refresh data badge tiap 12 jam.

## Scripts lokal

```bash
npm install
npm run dev            # dev server (auto-generate catalog)
npm run generate       # regenerate katalog dari folder lab
npm run profile:fetch  # fetch badge (baca web/public/profile-source.json)
npm run build          # generate + typecheck + build → dist/
npm run preview        # serve hasil build
```

## Deploy

`npm run build` menghasilkan static site murni di `dist/` (base `./`, jadi bisa di-host
di GitHub Pages sub-path, Cloud Storage, atau hosting statis lain).
