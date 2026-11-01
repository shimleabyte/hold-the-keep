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
- 1-6 atau klik slot di bar bawah: pilih bangunan (termasuk Pos Terdepan)
- Klik kiri: pasang (tahan untuk melukis tembok)
- Pos Terdepan memperluas wilayah; bangunan lain hanya dapat dipasang di area yang sudah diklaim
- Klik kanan: batal / bongkar bangunan (refund 50%)
- Esc: batal mode bangun
- F / klik kiri (di luar mode bangun) / tombol X: serang sekitar pemain
- T / M / K / R: tambah penebang / penambang / petani (kebun) / prajurit (Shift = kurangi); atau klik tombol + / - di panel job
- G: kirim seluruh prajurit untuk menyerbu benteng lawan yang sudah ditemukan; tekan lagi untuk menarik mereka kembali ke Keep
- P / Esc (saat tidak membangun): menu jeda (simpan, muat, layar penuh, vsync, volume)
- Menu jeda > Atur kontrol: rebind gerak, interaksi, serang, dan lari; gamepad tetap didukung
- F5: simpan | F9: muat | H: bantuan kontrol | F3: tampilkan FPS
- R: mulai ulang setelah game over | L: muat save terakhir dari layar game over

## Sistem permainan

### Siklus pertahanan
- Bertahan selama 15 hari; pada malam terakhir, kalahkan Raja Lawan.
- Keep memiliki 1000 HP. Jika hancur, permainan berakhir.
- Siang berlangsung 180 detik; malam berlangsung sekitar 54 detik.
- Gelombang dimulai dari 6 musuh dan bertambah 3 per hari, hingga batas 120.
- Bandit muncul sejak awal, serigala mulai hari 2, dan prajurit mulai hari 4.
- Raja Lawan memiliki 1400 HP dan tidak mundur saat fajar.

### Desa dan ekonomi
- Penduduk awal: 2. Keep memberi kapasitas 2; setiap rumah menambah 2 kapasitas.
- Penduduk baru membutuhkan 8 makanan dan hanya muncul pada siang hari ketika kapasitas cukup.
- Atur penebang, penambang, petani, dan prajurit melalui T/M/K/R atau tombol kuota di HUD.
- Setiap penduduk mengonsumsi 2 makanan per hari. Kekurangan makanan membuat satu penduduk pergi.
- Bangunan: rumah, tembok, menara, gudang, ladang, tembok batu, tempa, dan Pos Terdepan.
- Teknologi 17-node dalam 3 era memperkuat ekonomi, pertahanan, dan pasukan.

### Simpanan dan pengaturan
- Autosave setiap fajar; simpan manual dengan F5 dan muat dengan F9.
- Save versi 5 menyimpan inventori, jam, bangunan, penduduk, musuh, riset, pemain, status resource node, eksplorasi fog of war, benteng lawan, timer penguatan, serta status ekspedisi dan perjalanan pulang.
- Penulisan save memakai file sementara dan salinan pemulihan; loader mencoba salinan tersebut bila file utama rusak.
- Pengaturan layar penuh, VSync, volume, dan guncangan layar tersimpan di `user://settings.cfg`.

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

## Wilayah dan kampanye
Keep mengklaim area awal dalam radius 10 tile. Pos Terdepan (hotkey 6) memperluas klaim dalam radius 9 tile dan hanya boleh dibangun di frontier sendiri. Benteng lawan ditempatkan pada lokasi yang dapat dicapai di peta yang sama, mengklaim radius 9 tile, dan dijaga oleh prajurit yang berpatroli serta menerima penguatan berkala. Garis emas menunjukkan wilayah pemain; garis merah menunjukkan wilayah lawan.

Fog of war menutup peta yang belum dijelajahi. Player, Keep, Pos Terdepan, dan villager membuka area; wilayah yang sudah ditemukan tetap terlihat setelah disimpan dan dimuat. Setelah benteng lawan ditemukan, tekan G untuk mengirim semua villager dengan job prajurit. Prajurit menyerang penjaga dahulu, lalu menghancurkan benteng (900 HP). Tekan G lagi untuk menarik pasukan kembali ke Keep. Benteng hancur = kemenangan kampanye; kemenangan bertahan hari ke-15 melawan Raja Lawan tetap menjadi jalur kemenangan lain.

## HUD
Panel atas: kayu, batu, makanan, hari + lintasan siang/malam (kuning = siang, biru = malam, oranye = fajar),
jumlah musuh, penduduk. Kiri: bar HP pemain dan keep. Kanan: kuota job (klik + / -; oranye = belum terisi).
Bawah: bar bangunan berikon dan biaya (redup = bahan kurang). Bar Raja Lawan muncul di malam terakhir; bar Benteng Lawan muncul setelah ditemukan.

## Aset
Semua visual berupa SVG pixel-art di `assets/sprites/` (karakter, musuh, pohon, batu,
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

Belum ada: musik, rebind shortcut UI/job/build, multi-basis dan multi-region campaign, upgrade khusus invasi, ikon .ico untuk Windows, integrasi Steam.
Visual masih placeholder prosedural.
