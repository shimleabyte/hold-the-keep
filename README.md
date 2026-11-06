# Hold the Keep

Game strategi RTS 2D top-down bertema medieval, dibuat dengan **Godot 4.7**. Proyek ini sedang memindahkan fondasi village-defense menjadi permainan komando kerajaan: kelola ekonomi, bangun pemukiman, jelajahi wilayah, kendalikan pasukan, dan taklukkan rival.

Model RTS masih dalam tahap migrasi. Fondasi kamera strategi, seleksi unit, perintah gerak, serang, dan interaksi objektif sudah tersedia di branch pengembangan; produksi militer dan AI ekonomi lawan belum selesai.

## Mode permainan

- **Classic** — Peta 64×64 dengan kampanye bertahan selama 15 hari.
- **Frontier** — Peta 128×128, lima biome, empat stronghold, dan kampanye Conquest 20 hari.
- **Frontier Expedition** — Peta 192×192. Mulai dari heartland, lalu buka empat wilayah luar melalui eksplorasi.

## Arah pengembangan

Game sedang bertransisi ke model RTS top-down: kamera strategi, seleksi unit, perintah gerak langsung, ekonomi, ekspansi, riset, dan penaklukan. Status migrasi dan tahapan desain dicatat di [docs/RTS_PIVOT.md](docs/RTS_PIVOT.md). Fondasi seleksi/perintah pertama belum berarti seluruh sistem RTS sudah selesai.

## Fitur utama

- Kamera strategi terpisah dari unit, dengan pan, edge-scroll, drag, dan zoom.
- Seleksi villager dengan klik tunggal atau drag-box, lalu berikan perintah gerak langsung.
- Prajurit dapat menerima perintah serang terhadap musuh, kamp, objective dan stronghold.
- Interaksi objective Frontier menggunakan unit terpilih; konvoi bergerak di rute dan dapat diserang.
- Ekonomi berbasis kayu, batu, makanan, besi, pekerjaan penduduk, konstruksi, dan supply network.
- Bangunan, teknologi, fog of war, klaim wilayah, faksi, dan kampanye multi-stronghold tetap tersedia sebagai fondasi ekspansi.

## Menjalankan game

1. Install **Godot 4.7**.
2. Buka Godot dan import file `project.godot`.
3. Tunggu proses import aset selesai.
4. Tekan **F5** untuk menjalankan game.

## Kontrol dasar

| Aksi | Kontrol |
|---|---|
| Geser kamera | WASD / tombol panah |
| Geser kamera di tepi layar | Arahkan kursor ke tepi |
| Geser kamera manual | Klik tengah + drag |
| Zoom | Roda mouse |
| Pilih unit | Klik kiri |
| Pilih banyak unit | Drag klik kiri |
| Tambah/lepaskan dari seleksi | Shift + klik kiri |
| Perintah gerak unit | Klik kanan tanah |
| Perintah serang prajurit | Klik kanan musuh / target kampanye |
| Interaksi objektif Frontier | Klik kanan titik objektif dengan unit terpilih |
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
