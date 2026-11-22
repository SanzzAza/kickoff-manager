# Kickoff Manager — game manajer sepak bola (Flutter + SQLite)

[![Build APK](https://github.com/SanzzAza/kickoff-manager/actions/workflows/build-apk.yml/badge.svg)](https://github.com/SanzzAza/kickoff-manager/actions/workflows/build-apk.yml)
[![Download APK](https://img.shields.io/badge/Download-APK%20terbaru-00C853)](https://github.com/SanzzAza/kickoff-manager/releases/latest)


Game manajer sepak bola offline untuk Android, **dibuat dengan Flutter/Dart + SQLite** —
persis seperti game referensi (`Superkickoff`) yang menjadi acuan alur dan mekaniknya.
Bukan HTML, bukan webview: aplikasi Android native.

**APK siap pasang:** `release/KickoffManager-1.0.0-arm64.apk` (19 MB, min Android 6.0, arm64)

**Build otomatis di cloud:** repo ini sudah dilengkapi GitHub Actions
(`.github/workflows/build-apk.yml`) — setiap push, GitHub yang build APK-nya.
Panduan lengkap: [`docs/PUSH-KE-GITHUB.md`](docs/PUSH-KE-GITHUB.md)

---

## 1. Hasil pembongkaran APK referensi

File `.xapk` dibongkar, lalu ditemukan:

| Temuan | Detail |
|---|---|
| Framework | **Flutter** (Dart) — `lib/arm64-v8a/libapp.so`, `libflutter.so`, `flutter_assets/` |
| Database | **SQLite** — 9 file `.db` (1998 → 2026) berisi 42 tabel, mis. `eq_equipos`, `jug_jugadores`, `tor_partidos`, `tor_torneos`, `jug_contratos`, `jus_stats` |
| Struktur kode | 498 file Dart (nama masih terbaca di binary): `StartScreen/WizardNuevaPartida/*`, `Partida/Plantilla/*`, `Util/Algoritmos/AlgPartido.dart`, `AlgFixture.dart`, `Database/Modelos/*`, dst. |
| Engine | simulasi menit-per-menit (`AlgPartido`), fixture round-robin (`AlgFixture`), taktik & formasi (`AlgFormacionTactica`), penalti, VAR, cedera, kontrak, sponsor, finansial |
| Pihak ketiga | Firebase, AdMob, AppLovin, RevenueCat, AppsFlyer (monetisasi + analytics) |
| Pemilik | **Bleutecmedia** (studio komersial, `app.superkickoff`) |

Detail lengkap: `docs/skema-asli-superkickoff.md` dan `docs/file-dart-asli.txt`.

### Catatan penting soal legal
Game aslinya produk komersial milik Bleutecmedia. Yang saya pakai dari pembongkaran itu
hanya **struktur/arsitektur dan mekanik genre** (pola tabel, alur wizard → musim → simulasi,
model atribut pemain). Semua kode, data klub/pemain, teks, dan aset gambar di repo ini
**dibuat orisinal** — tidak ada file dari APK asli yang dipaket ulang, dan nama pemain nyata
diganti legenda fiktif. Kalau mau dipublikasikan, tetap butuh nama/branding sendiri
(package `com.kickoffmanager.kickoff_manager` sudah dipakai di sini).

---

## 2. Fitur yang sudah jalan

**Alur permainan**
- Wizard karier baru: nama manajer → pilih konfederasi & liga → pilih klub
- 15 liga, 5 konfederasi, ~250 klub, ~6.200 pemain ter-generate
- Kalender double round-robin penuh, klasemen hidup (menang 3, seri 1), forma 5 laga
- Selesai pekan → laga lain auto-simulasi, pemain pulih, gaji & biaya operasional dipotong
- Akhir musim: juara, hadiah, puncak skor, aging pemain, pensiun, isi ulang skuad,
  **promosi/degradasi tidak dipakai** (liga tunggal), **PHK** kalau gagal total,
  dan **lamaran klub lain** kalau finis 4 besar → bisa pindah klub

**Pertandingan**
- Simulasi menit 1–90 dengan momentum, peluang, tembakan on/off target, penyelamatan,
  mistar, pelanggaran, kartu kuning/merah, penalti, cedera, adu penalti
- Feed kejadian Bahasa Indonesia, skor live, statistik (tembakan, on target, penguasaan)
- **Rating pemain 3.0–9.9** per laga + penanda MVP + gol/assist/atajadas

**Taktik & skuad**
- 7 formasi (4-4-2, 4-3-3, 4-2-3-1, 3-5-2, 3-4-3, 4-5-1, 5-3-2) dengan peta lapangan
- Mentalitas, pressing, gaya main, amplitudo, garis pertahanan
- Starting XI otomatis (hormati cedera/skorsing), detail atribut 7 statistik
- Kontrak: perpanjangan, penjualan, skorsing, cedera berpekan-pekan

**Transfer**
- Pasar transfer dengan filter posisi + rating minimum + pencarian nama
- Negosiasi (tawaran di bawah nilai bisa ditolak/penghinaan), budget & gaji, riwayat transfer

**Klub**
- Finansial: tiket (kapasitas × harga × kehadiran), TV, gaji, operasional, sponsor
- Stadion: 4 tribun dengan batas maksimum, ekspansi berbayar
- Latihan: 4 program mingguan, progres atribut pemain muda
- Kotak masuk pesan, klasemen/pencetak gol/jadwal, sejarah musim & trofi

---

## 3. Struktur kode

```
lib/
  main.dart                     # bootstrap + tema
  data/football_data.dart       # liga, klub, nama per negara, posisi, stadion
  models/models.dart            # Player, Team, Stadium, Tactics, MatchResult
  db/db.dart                    # skema SQLite (penamaan meniru DB asli) + World (query)
  engine/
    match_engine.dart           # simulasi menit-per-menit + quickScore (Poisson)
    world_generator.dart        # generator klub/pemain/kontrak, isi ulang skuad
    game_service.dart           # alur: newGame, startSeason, playWeek, playUserMatch,
                                #   endSeason, nextSeason, transfer, latihan, stadion
  ui/
    theme.dart, widgets.dart    # tema hijau-gelap, crest, badge, bar atribut, lapangan
    screens/                    # welcome, new_game, home_shell, club, squad, tactics,
                                #   match_sim, table, market, menu, inbox, club_pages
test/                           # uji logika + widget test (flutter test)
android/                        # konfigurasi Android (minSdk 23, targetSdk 34, arm64)
```

## 4. Build otomatis lewat GitHub (disarankan)

1. Push repo ini ke GitHub (cara paling gampang: upload lewat web — lihat `docs/PUSH-KE-GITHUB.md`)
2. Tab **Actions** → **Build APK** → **Run workflow**
3. Setelah ±5–8 menit, APK muncul di **Artifacts** dan di **Releases** (link unduh tetap)

Untuk merilis versi baru: ubah kode → naikkan `version:` di `pubspec.yaml` → push.
CI otomatis menjalankan analyze → test → build APK → upload.

## 5. Cara build manual di komputer

Toolchain yang dipakai saat dibuat: Flutter 3.24.5 (Dart 3.5.4), JDK 17, Android SDK 34.

```bash
flutter pub get
flutter test                       # uji logika + UI
flutter build apk --release --target-platform android-arm64
# hasil: build/app/outputs/flutter-apk/app-release.apk
```

Build di mesin kecil: `android/gradle.properties` sudah diset hemat memori
(`-Xmx640m`, worker 1, daemon off) dan `lint.checkReleaseBuilds=false`.
APK saat ini ditandatangani dengan **debug key** — untuk rilis produksi ganti
`signingConfigs.release` dengan keystore sendiri.

## 6. Verifikasi yang sudah dilakukan

- `flutter analyze`: 0 error
- Uji headless (sqflite_ffi) satu musim penuh: 34 pekan, klasemen konsisten,
  endSeason → nextSeason tanpa error
- Kalibrasi: rata-rata **2,8 gol/laga**, home win ±47%, tembakan ±12–18, rating XI wajar
- Widget test: wizard, 5 tab utama, taktik, latihan/stadion/finansial/sejarah,
  alur Kick Off → live feed → rating → lanjut
