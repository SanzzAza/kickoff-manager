# Panduan: push ke GitHub & build APK di cloud

Ringkasnya: **upload repo → aktifkan Actions → setiap push, GitHub yang build APK-nya.**
Total sekitar 10 menit, gratis (repo publik) — tanpa perlu install Flutter di komputer.

---

## A. Push pertama (pilih salah satu)

### Cara 1 — lewat web GitHub (paling gampang, tanpa Git)

1. Buka https://github.com/new → isi **Repository name**: `kickoff-manager` → **Private** atau **Public** → **Create repository**
2. Di repo kosong itu klik **uploading an existing file**
3. Ekstrak `kickoff-manager-repo.zip` (ada di workspace) di komputer
4. Drag & drop **semua isi folder** hasil ekstrak ke halaman upload, lalu **Commit changes**
   - Pastikan folder `.github` ikut ter-upload (kalau tidak, workflow build tidak jalan).
   - Kalau browser menyembunyikan folder tersembunyi, pakai Cara 2.

### Cara 2 — lewat Git di komputer

```bash
# dari folder hasil ekstrak zip
git init
git add .
git commit -m "Kickoff Manager v1.0.0"
git branch -M main
git remote add origin https://github.com/USERNAME/kickoff-manager.git
git push -u origin main
```

### Cara 3 — lewat HP (Termux / aplikasi Git)

```bash
pkg install git
git clone https://github.com/USERNAME/kickoff-manager.git
cd kickoff-manager
# copy semua file project ke folder ini, lalu:
git add .
git commit -m "Kickoff Manager v1.0.0"
git push
```

---

## B. Build APK otomatis (GitHub Actions)

Workflow-nya sudah ada di `.github/workflows/build-apk.yml`:

1. Buka repo → tab **Actions**
2. Kalau muncul tombol konfirmasi, klik **I understand my workflows, go ahead and enable them**
3. Pilih **Build APK** di sidebar → tombol **Run workflow** (atau cukup push commit baru)
4. Tunggu ±5–8 menit. Hasilnya:
   - **Artifacts**: `apk-<nomor>` → berisi APK per arsitektur
   - **Releases**: tag `build-<nomor>` dengan APK terlampir → link unduh permanen

Yang dijalankan CI: `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build apk --split-per-abi` → upload artifact + release.

**APK mana yang dipakai?**
| File | Untuk |
|---|---|
| `KickoffManager-<ver>-arm64-v8a.apk` | HP Android modern (2018 ke atas) — **pakai ini** |
| `KickoffManager-<ver>-armeabi-v7a.apk` | HP lama 32-bit |
| `KickoffManager-<ver>-x86_64.apk` | Emulator / BlueStacks |

---

## C. Alur update setelah ini

1. Ubah kode (di HP bisa pakai Termux + editor, atau langsung edit file lewat web GitHub)
2. Naikkan versi di `pubspec.yaml`: `version: 1.0.1+2` (angka setelah `+` harus selalu naik)
3. Commit & push
4. GitHub build otomatis → unduh APK baru dari tab Releases

---

## D. Kalau ingin APK bertanda tangan resmi (bukan debug key)

Debug key dari CI akan mengganti tanda tangan, jadi **APK baru tidak bisa menimpa APK lama**
harus uninstall dulu. Untuk rilis serius, pakai keystore sendiri:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload-keystore.jks > keystore.txt
```

Lalu di repo → **Settings → Secrets and variables → Actions → New repository secret**, tambahkan:

| Nama secret | Isi |
|---|---|
| `KEYSTORE_BASE64` | isi `keystore.txt` |
| `KEYSTORE_PASSWORD` | password keystore |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | password key |

Lalu tambahkan langkah berikut di workflow, **sebelum** `Build split APK`:

```yaml
      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/upload-keystore.jks
          cat > android/key.properties <<EOF
          storePassword=${{ secrets.KEYSTORE_PASSWORD }}
          keyPassword=${{ secrets.KEY_PASSWORD }}
          keyAlias=${{ secrets.KEY_ALIAS }}
          storeFile=upload-keystore.jks
          EOF
```

Dan di `android/app/build.gradle`, ganti bagian signing:

```gradle
def keystorePropertiesFile = rootProject.file("key.properties")
def keystoreProperties = new Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

> Catatan: `android/key.properties` dan `*.jks` sudah masuk `.gitignore`, jadi aman tidak ter-commit.

---

## E. Catatan penting soal publikasi

- Game ini **clean-room reimplementation**: kode, data klub/pemain, teks, dan aset dibuat
  orisinal. Tidak ada file dari APK referensi yang dipaket ulang.
- Nama **"Kickoff Manager"** dan package `com.kickoffmanager.kickoff_manager` sudah dipakai
  di sini. Sebelum rilis publik, ganti ke nama/branding milikmu sendiri — sedikitnya ubah:
  - `android/app/build.gradle` → `applicationId`
  - `android/app/src/main/AndroidManifest.xml` → `android:label`
  - `pubspec.yaml` → `description`
- Kalau repo dibuat **public**, semua orang bisa melihat kodenya (itu tidak apa-apa, dan
  membuat menit Actions gratis). Kalau mau tertutup, pilih **Private** — Actions tetap
  gratis untuk 2.000 menit/bulan.
