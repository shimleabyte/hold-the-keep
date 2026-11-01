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
- Y atau tombol `Y` di HUD: panel teknologi
- TAB atau tombol `MAP`: peta strategis (fog-of-war, biome, klaim, resource, Keep, pasukan yang sedang teramati)
- Tombol `JOBS`: buka/tutup kuota penebang, penambang, petani, dan prajurit; Esc menutup panel
- E / Spasi / tombol A (gamepad): tebang pohon, tambang batu
- 1-6 atau klik slot di bar bawah: pilih bangunan (termasuk Pos Terdepan)
- Klik kiri: pasang (tahan untuk melukis tembok)
- Pos Terdepan memperluas wilayah; bangunan lain hanya dapat dipasang di area yang sudah diklaim
- Klik kanan: batal / bongkar bangunan (refund 50%)
- Esc: batal mode bangun
- F / klik kiri (di luar mode bangun) / tombol X: serang sekitar pemain
- Q / tombol B: Dash — burst cepat dengan jendela kebal singkat
- C / tombol Y: Cleave — tebasan depan yang melukai dan membuat musuh limbung (level 2)
- V / bumper kanan: Rally — memperkuat serangan pemain dan prajurit sekitar (level 3)
- Kalahkan musuh untuk mendapat XP; level up memulihkan sebagian HP dan membuka skill
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
- Kampanye dibagi menjadi tiga bab: Hari 1–5 **Perbatasan**, Hari 6–10 **Pawai Hitam**, Hari 11–15 **Pengepungan Akhir**. Bab II menambah tekanan pemanah; Bab III memperbesar peluang pemanah dan penghancur lapis baja.
- Bandit muncul sejak awal, serigala hari 2, prajurit hari 4, pemanah hari 6, dan penghancur lapis baja hari 9.
- Serigala menerjang setelah jeda serangan; pemanah menjaga jarak dan menembakkan proyektil; penghancur lebih tahan tetapi menghantam bangunan lebih keras.
- Raja Lawan memiliki 1400 HP, armor, damage pengepungan, dan tidak mundur saat fajar.

### Combat dan progression
Pemain memperoleh XP saat musuh mati. Level 1 membuka Dash (Q), level 2 membuka Cleave (C), dan level 3 membuka Rally (V). Dash memberi perpindahan cepat serta invulnerability singkat; Cleave menyerang area depan dan memberi stagger; Rally memperkuat damage pemain dan prajurit dalam radius selama delapan detik. Level up memulihkan sebagian HP. Progress level/XP tersimpan.

Musuh memiliki pola yang berbeda, bukan hanya statistik: bandit menyerbu garis pertahanan, serigala menerjang, pemanah menjaga jarak dan menembakkan proyektil, sedangkan penghancur berzirah bergerak lambat tetapi memberi damage pengepungan tinggi pada bangunan.

### Desa dan ekonomi
- Penduduk awal: 2. Keep memberi kapasitas 2; setiap rumah menambah 2 kapasitas.
- Penduduk baru membutuhkan 8 makanan dan hanya muncul pada siang hari ketika kapasitas cukup.
- Atur penebang, penambang, petani, dan prajurit melalui T/M/K/R atau tombol kuota di HUD.
- Setiap penduduk mengonsumsi 2 makanan per hari. Kekurangan makanan membuat satu penduduk pergi.
- Bangunan: rumah, tembok, menara, gudang, ladang, tembok batu, tempa, dan Pos Terdepan.
- Teknologi 17-node dalam 3 era memperkuat ekonomi, pertahanan, dan pasukan.

### Simpanan dan pengaturan
- Autosave setiap fajar; simpan manual dengan F5 dan muat dengan F9.
- Save versi 6 menyimpan semua status versi sebelumnya plus level dan XP tempur pemain; save versi 1–5 dimigrasikan ke level awal.
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

## Peta dan wilayah
Peta strategis dibuka dengan TAB atau tombol MAP di HUD. Peta menampilkan hanya area yang sudah ditemukan; lokasi musuh bergerak hanya muncul saat berada dalam jangkauan pengamatan unit atau bangunan, bukan sekadar karena pernah dijelajahi. Warna terrain membedakan Hearthland, Greenwood (hutan lebih rapat), Highlands (batu lebih banyak), dan Fenlands (rawa). Klaim pemain dan musuh diberi tint berbeda, sedangkan Keep, Outpost, resource, villager, dan pemain punya marker masing-masing.

## Wilayah dan kampanye
Keep mengklaim area awal dalam radius 10 tile. Pos Terdepan (hotkey 6) memperluas klaim dalam radius 9 tile dan hanya boleh dibangun di frontier sendiri. Benteng lawan ditempatkan pada lokasi yang dapat dicapai di peta yang sama, mengklaim radius 9 tile, dan dijaga oleh prajurit yang berpatroli serta menerima penguatan berkala. Garis emas menunjukkan wilayah pemain; garis merah menunjukkan wilayah lawan.

Fog of war menutup peta yang belum dijelajahi. Player, Keep, Pos Terdepan, dan villager membuka area; wilayah yang sudah ditemukan tetap terlihat setelah disimpan dan dimuat. Setelah benteng lawan ditemukan, tekan G untuk mengirim semua villager dengan job prajurit. Prajurit menyerang penjaga dahulu, lalu menghancurkan benteng (900 HP). Tekan G lagi untuk menarik pasukan kembali ke Keep. Benteng hancur = kemenangan kampanye; kemenangan bertahan hari ke-15 melawan Raja Lawan tetap menjadi jalur kemenangan lain.

## HUD
HUD permanen diringkas menjadi resource, jam, populasi, tombol MAP/JOBS/riset, vitals pemain dan Keep, indikator bab, serta bar bangunan. Kuota job berada di drawer JOBS dan tertutup secara default. XP dan Q/C/V tampil sebagai bar kompak di atas hotbar; detail bantuan tetap tersedia lewat H. Health bar Raja Lawan atau Benteng Lawan muncul saat relevan.

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
