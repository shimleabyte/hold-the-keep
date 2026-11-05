# Hold the Keep

Game strategi pertahanan desa 2D top-down bertema medieval, dibuat dengan **Godot 4.7**.

Bangun desa, kelola penduduk dan sumber daya pada siang hari. Persiapkan pertahanan, lalu hadapi serangan musuh saat malam. Di mode Frontier, jelajahi wilayah yang lebih luas dan taklukkan benteng lawan.

## Mode permainan

- **Classic** — Peta 64×64 dengan kampanye bertahan selama 15 hari.
- **Frontier** — Peta 128×128, lima biome, empat stronghold, dan kampanye Conquest 20 hari.
- **Frontier Expedition** — Peta 192×192. Mulai dari heartland, lalu buka empat wilayah luar melalui eksplorasi.

## Fitur utama

- Siklus siang dan malam dengan gelombang serangan musuh.
- Bangun dan tingkatkan desa, pertahanan, serta fasilitas produksi.
- Atur pekerjaan penduduk: penebang, penambang, petani, Builder, Hunter, Scout, Healer, Blacksmith, dan prajurit.
- Kumpulkan kayu, batu, makanan, dan besi.
- Lawan musuh secara langsung dan buka kemampuan pemain.
- Jelajahi peta dengan fog of war, klaim wilayah, dan hadapi stronghold lawan.
- Riset teknologi, simpan progres, dan lanjutkan kampanye.

## Menjalankan game

1. Install **Godot 4.7**.
2. Buka Godot dan import file `project.godot`.
3. Tunggu proses import aset selesai.
4. Tekan **F5** untuk menjalankan game.

## Kontrol dasar

| Aksi | Kontrol |
|---|---|
| Bergerak | WASD / tombol panah / left stick |
| Berinteraksi dan mengumpulkan resource | E / Spasi |
| Menyerang | F / klik kiri |
| Berlari | Shift / bumper kiri |
| Dash | Q |
| Cleave | C |
| Rally | V |
| Peta strategis | TAB |
| Objektif | O |
| Teknologi | Y |
| Pilih bangunan | 1–9 / 0 atau hotbar |
| Simpan / muat | F5 / F9 |
| Menu jeda | P |

Panel **JOBS** digunakan untuk mengatur pekerjaan penduduk. Tekan **H** atau **F1** untuk bantuan kontrol. Kontrol keyboard dapat diubah melalui menu jeda, dan gamepad juga didukung.

## Android ARMv7 (debug build)

Preset **Android ARMv7 Debug** menghasilkan APK 32-bit `armeabi-v7a` untuk pengujian perangkat, bukan release store. Gunakan Godot 4.7, JDK 17, dan Android SDK; jalankan `bash tools/export_android_armv7.sh` dari root repo. APK hasil ekspor berada di `build/android/HoldTheKeep-armv7-debug.apk`. Kontrol landscape menyediakan joystick kiri, Attack/Interact/Dash/Cleave/Rally di kanan, serta tombol jeda. Export CI memverifikasi ABI; instalasi, safe area, lifecycle, dan sesi bermain tetap perlu diuji pada perangkat fisik.

## Teknologi

- Godot 4.7
- GDScript
- Renderer GL Compatibility
- Pixel-art assets berbasis SVG

## Kredit

Font HUD menggunakan **Silkscreen**. Lisensinya tersedia di `assets/fonts/OFL-Silkscreen.txt`.
