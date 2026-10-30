# Hold the Keep

> Konteks lengkap proyek (arsitektur, status, keputusan, rencana): [CONTEXT.md](CONTEXT.md). Skrip tes: [tests/README.md](tests/README.md).

Game 2D top-down village defense bertema medieval. Native desktop, Godot 4.3+ (GDScript).

## Menjalankan
1. Buka Godot 4.3+ (dites juga di 4.7) -> Import -> pilih `project.godot`.
   Tunggu import aset selesai (pertama kali saja)
2. Tekan F5

## Kontrol
- WASD / Panah / stick kiri: gerak
- Tahan Shift / bumper kiri (gamepad): lari
- Y atau tombol RISET di HUD: panel teknologi
- E / Spasi / tombol A (gamepad): tebang pohon, tambang batu
- 1-5 atau klik slot di bar bawah: pilih bangunan (rumah, tembok, menara, gudang, ladang)
- Klik kiri: pasang (tahan untuk melukis tembok)
- Klik kanan: batal / bongkar bangunan (refund 50%)
- Esc: batal mode bangun
- F / klik kiri (di luar mode bangun) / tombol X: serang sekitar pemain
- T / M / K / R: tambah penebang / penambang / petani (kebun) / prajurit (Shift = kurangi); atau klik tombol + / - di panel job
- P / Esc (saat tidak membangun): menu jeda (simpan, muat, layar penuh, vsync, volume)
- F5: simpan | F9: muat | H: bantuan kontrol | F3: tampilkan FPS
- R: mulai ulang setelah game over | L: muat save terakhir dari layar game over

## Status: Minggu 1
- Peta 64x64 prosedural (rumput, kolam dengan collision, pohon)
- Pemain 8 arah, kamera smoothing + limit peta, Y-sort
- Pohon: 3 pukulan, bonus kayu, tumbuh lagi 45 detik
- Inventori (autoload), HUD (kayu, hari, FPS), siklus siang-malam dasar
- Semua visual placeholder prosedural, belum ada aset

## Status
Minggu 1-2: peta, pemain, kamera, sumber daya (kayu, batu), sistem bangunan data-driven.

Minggu 4-5 (bagian 1): pertahanan
- Keep di tengah peta (500 HP). Hancur = game over, R untuk mulai ulang
- Gelombang musuh tiap malam (data/waves.json): bandit, serigala, prajurit
- Pathfinding flow-field: satu field untuk semua musuh; tembok boleh ditembus
  dengan biaya tinggi, jadi musuh memilih memutar atau menghancurkan tembok
- Menara menembak anak panah (jangkauan 96px, 7 damage, 0.9 detik)
- Pemain: 100 HP, serangan area, regen setelah 4 detik tanpa terkena, respawn di keep
- Siang 180 detik per hari, malam sekitar 54 detik; musuh mundur saat fajar

Minggu 6-7 (bagian 1): villager dan ekonomi
- Penduduk awal 2. Kapasitas: keep +2, tiap rumah +2. Penduduk baru muncul tiap 12 detik
  siang hari jika ada kapasitas dan makanan cukup (8 makanan + cadangan upkeep)
- Job: penebang, penambang, petani, prajurit. Kuota diatur dengan T/M/K/R atau tombol + / - di HUD
- Villager mengumpulkan sampai 6 unit, lalu menyetor ke gudang atau keep terdekat (A*)
- Ladang: maksimal 2 petani, 3 makanan per 12 detik per petani
- Upkeep: 2 makanan per penduduk per hari. Kurang makanan = satu penduduk pergi
- Malam: non-prajurit lari ke keep dan bersembunyi; prajurit menyerbu musuh
- Rumah menambah kapasitas, gudang jadi tempat setor

Minggu 8 (bagian 1): event, boss, kemenangan
- Tujuan: bertahan sampai hari 15, lalu kalahkan Raja Lawan (600 HP, 25 damage) di malam terakhir
- Raja tidak mundur saat fajar; permainan berakhir (menang) hanya jika dia tumbang
- Event acak tiap awal hari mulai hari 2 (60% peluang), dari data/events.json:
  pedagang, panen, tambang baru, pengungsi, paceklik, wabah. Tidak ada event di hari terakhir
- Balancing awal: keep 1000 HP, menara 12 damage, gelombang 6 + 2 per hari.
  Simulasi malam terakhir: 4 prajurit + 2 menara kalah; 8 prajurit + 4 menara menang tipis.
  Tembok sebaiknya dipasang dalam jangkauan menara (cincin jauh justru menahan musuh di luar jangkauan)

Minggu 9-10 (bagian 1): rilis
- Save/load: satu slot di user://save.json. Autosave tiap fajar, manual dengan F5, muat dengan F9.
  Tersimpan: inventori, jam/hari, bangunan + HP, penduduk (job, HP, bawaan), musuh, pemain, kuota job.
  Tidak tersimpan: status pohon/batu (tumbuh lagi saat dimuat)
- Pengaturan di user://settings.cfg: layar penuh, vsync, volume
- SFX prosedural (tanpa file aset), dibuat saat startup; ganti dengan sample asli lewat scripts/autoload/audio.gd
- Log sesi di user://logs/godot.log (5 file terakhir disimpan)
- Export preset Windows dan Linux (export_presets.cfg), file *.json ikut terkemas

## Membuat build rilis
1. Di Godot: Editor > Manage Export Templates > Download and Install (versi 4.3)
2. Jalankan `tools/build.sh` (Linux/macOS) atau `tools/build.ps1` (Windows).
   Atur lokasi Godot lewat variabel `GODOT`
3. Hasil: `build/windows/HoldTheKeep.exe` dan `build/linux/HoldTheKeep.x86_64` (PCK tertanam)

## Teknologi
Pohon riset 17 teknologi dalam 3 era (data/techs.json), dibuka dengan Y:
- **Era Kayu** (awal): perkakas, bajak, palisade, rumah panjang, panah berbulu, dan **Ilmu Batu** (naik era)
- **Era Batu**: perkakas batu, lumbung, menara batu, zirah kulit, latihan prajurit, dan **Tambang Besi** (naik era)
- **Era Besi**: perkakas, senjata, zirah, menara, dan benteng besi (sebagian butuh bangunan Tempa)
Satu riset berjalan pada satu waktu; bahan dibayar di awal. Ilmu Batu membuka Tembok Batu, Tambang Besi
membuka Tempa dan membuat bijih besi (urat oranye, jauh dari keep) bisa ditambang. Penambang villager
memilih besi bila stoknya kurang dari separuh batu. Game di-pause saat panel terbuka.
Efek berupa data (pengali, penambah, buka bangunan, bendera) lewat `Tech.stat(kunci, dasar)`.

## HUD
Panel atas: kayu, batu, makanan, hari + lintasan siang/malam (kuning = siang, biru = malam, oranye = fajar),
jumlah musuh, penduduk. Kiri: bar HP pemain dan keep. Kanan: kuota job (klik + / -; oranye = belum terisi).
Bawah: bar bangunan berikon dan biaya (redup = bahan kurang). Bar Raja Lawan muncul di malam terakhir.

## Aset
Semua visual berupa SVG pixel-art di `assets/sprites/` (28 file: karakter, musuh, pohon, batu,
bangunan, tile, ikon HUD). Karakter dan musuh berupa sprite sheet 4 frame (diam, jalan 1, jalan 2,
aksi) yang dipilih otomatis oleh kode: berjalan, menebang/menambang/bertani, menyerang. Dibuat oleh `tools/gen_assets.py` (tanpa dependensi):
ubah palet/bentuk di skrip itu lalu `python3 tools/gen_assets.py` untuk membuat ulang.
SVG bisa diganti file apa pun dengan nama yang sama (PNG hasil Aseprite juga boleh,
ubah path di skrip yang me-`preload`-nya). Konvensi: titik tumpu di tengah-bawah kanvas.

## Animasi
Karakter dan musuh punya 22 frame x 3 arah pandang (depan, belakang, samping; kiri = flip):
diam (2), jalan (4), lari (4), serang (4), kerja (4), kena pukul (1), mati (3).
- Damage serangan dan panen jatuh di frame benturan, bukan saat tombol ditekan
- Penebang/penambang disinkronkan dengan timer pukulan; petani mengulang gerak menusuk
- Villager yang kabur di malam hari dan prajurit yang mengejar musuh jauh berlari
- Musuh yang tewas meninggalkan mayat yang jatuh lalu memudar
- Dibuat oleh renderer humanoid berbasis pose di `tools/gen_assets.py`; ubah satu pose
  atau tampilan, jalankan ulang skrip, semua frame ikut berubah
- Pemutar animasi: `scripts/entities/sprite_anim.gd`

## Efek visual
- Busur tebasan pemain mengikuti arah hadap (menyapu dari aba-aba sampai pulih)
- Partikel ringan (satu node menggambar semua, maksimal 500): percikan saat musuh kena,
  serpihan kayu dan batu saat panen, debu langkah saat berlari, puing saat bangunan diserang,
  awan puing saat bangunan hancur atau raja tumbang
- Guncangan layar (bangunan hancur, pemain kena, langkah raja, raja tumbang); bisa dimatikan
  di menu jeda ("Guncangan layar") dan tersimpan di settings.cfg
- Efek dipicu lewat `Events.fx_burst(kind, pos, dir, amount)` dan `Events.screen_shake(strength, duration)`;
  jenis partikel ditambah di `KINDS` pada `scripts/entities/fx_layer.gd`

## Kredit
Font HUD: Silkscreen (c) The Silkscreen Project Authors, SIL Open Font License 1.1
(lihat `assets/fonts/OFL-Silkscreen.txt`). Font hanya punya huruf kapital.

Belum ada: musik, rebind kontrol, tech tree, ikon .ico untuk Windows, integrasi Steam.
Visual masih placeholder prosedural.
