# Hold the Keep

Game strategi pertahanan desa 2D top-down bertema medieval, dibuat dengan **Godot 4.7**.

Bangun desa, kelola penduduk dan sumber daya pada siang hari. Persiapkan pertahanan, lalu hadapi serangan musuh saat malam. Di mode Frontier, jelajahi wilayah yang lebih luas dan taklukkan benteng lawan.

## Mode permainan

- **Classic** — Peta 128×128 untuk membangun permukiman, memperluas wilayah dan menghadapi peradaban rival selama 15 hari.
- **Frontier** — Peta 192×192, lima biome, empat stronghold, dan kampanye Conquest 20 hari.
- **Frontier Expedition** — Peta 256×256 dengan heartland 160×160. Mulai dari pusat, lalu buka empat wilayah luar melalui eksplorasi.

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
| Pilih prajurit | Klik kiri pada prajurit sendiri |
| Pilih beberapa prajurit | Drag klik kiri; Shift untuk tambah/lepas |
| Perintah gerak pasukan | Klik kanan tanah setelah memilih prajurit |
| Perintah serang pasukan | Klik kanan musuh / stronghold setelah memilih prajurit |
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

## Build desktop

Target rilis saat ini adalah desktop **Windows x86_64** dan **Linux x86_64** menggunakan Godot **4.7**. Pasang export templates Godot 4.7 yang cocok dengan editor/CLI sebelum menjalankan export.

Linux (menghasilkan kedua artefak Windows dan Linux):

```bash
GODOT=/path/to/godot tools/build.sh
```

Windows PowerShell:

```powershell
$env:GODOT = "C:\path\to\godot.exe"
.\tools\build.ps1
```

Artefak hasil build berada di `build/windows/HoldTheKeep.exe` dan `build/linux/HoldTheKeep.x86_64`. Build script menolak versi engine selain Godot 4.7 dan memeriksa bahwa kedua file hasil export benar-benar dibuat.

## Desktop QA target

- Resolusi windowed: 1280×720 dan 1920×1080.
- Resolusi high-density: 2560×1440.
- Mode windowed/fullscreen, keyboard/mouse, gamepad, save/load, dan sesi gameplay berkelanjutan.
- Ukur frame time ketika bangunan ditempatkan, selesai dibangun, dihancurkan, dan ketika gelombang malam aktif. Hasil headless CI bukan pengganti pengukuran pada PC desktop target.

## Teknologi

- Godot 4.7
- GDScript
- Renderer GL Compatibility
- Pixel-art assets berbasis SVG

## Kredit

Font HUD menggunakan **Silkscreen**. Lisensinya tersedia di `assets/fonts/OFL-Silkscreen.txt`.
