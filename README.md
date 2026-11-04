# Hold the Keep

> Status proyek: [CONTEXT.md](CONTEXT.md). Design bible: [docs/WORLD_AND_GAMEPLAY_BIBLE.md](docs/WORLD_AND_GAMEPLAY_BIBLE.md). Roadmap: [ROADMAP_NEXT_LEVEL.md](ROADMAP_NEXT_LEVEL.md). Implementation plans: [Phase 02](docs/plans/phase-02-plan.md), [Phase 04](docs/plans/phase-04-plan.md), [Phase 05](docs/plans/phase-05-plan.md), [Phase 06](docs/plans/phase-06-plan.md), [Phase 08](docs/plans/phase-08-plan.md), [Phase 09](docs/plans/phase-09-plan.md), [Phase 10](docs/plans/phase-10-plan.md). Test guide: [tests/README.md](tests/README.md).

Game 2D top-down village defense bertema medieval. Native desktop, Godot 4.7 (GDScript).

## Menjalankan
1. Buka Godot 4.7 -> Import -> pilih `project.godot`.
   Tunggu import aset selesai (pertama kali saja)
2. Tekan F5

## Kontrol
- WASD / Panah / stick kiri: gerak
- Tahan Shift / bumper kiri (gamepad): lari
- Y / chip `Y` di HUD: panel teknologi
- TAB atau tombol `MAP`: peta strategis (fog-of-war, biome, klaim, resource, Keep, dan musuh yang sedang teramati; Menara Pengawas memberi penglihatan lokal 128px)
- Tombol `JOBS`: buka/tutup kuota penebang, penambang, petani, Builder, Hunter, Scout, Healer, Blacksmith dan prajurit; Esc menutup panel
- `B` / `Shift+B`: tambah/kurangi kuota Builder
- `J` / `Shift+J`: tambah/kurangi kuota Hunter; penugasan hanya berhasil jika ada slot di Pondok Pemburu
- `U` / `Shift+U`: tambah/kurangi kuota Scout; penugasan hanya berhasil jika ada slot di Pondok Pengintai
- `N` / `QUEUE`: buka/tutup antrean konstruksi; tampilkan progres, biaya proyek, dahulukan/tunda, dan batalkan blueprint
- E / Spasi / tombol A (gamepad): tebang pohon, tambang batu
- 1-9 / 0 atau klik slot di bar bawah: pilih hingga 10 bangunan pertama (termasuk Pos Terdepan, Kamp Penebang, dan Kuari)
- Klik kiri: pasang (tahan untuk melukis tembok)
- Pos Terdepan memperluas wilayah; bangunan lain hanya dapat dipasang di area yang sudah diklaim
- Klik kanan: batal / bongkar bangunan (refund 50%)
- Esc: batal mode bangun
- F / klik kiri (di luar mode bangun) / tombol X: serang sekitar pemain
- Q / tombol B: Dash — burst cepat dengan jendela kebal singkat
- C / tombol Y: Cleave — tebasan depan yang melukai dan membuat musuh limbung (level 2)
- V / bumper kanan: Rally — memperkuat serangan pemain dan prajurit sekitar (level 3)
- Kalahkan musuh untuk mendapat XP; level up memulihkan sebagian HP dan membuka skill
- T / M / K / B / J / U / I / R: tambah penebang / penambang / petani / Builder / Hunter / Scout / Healer / prajurit (Shift = kurangi). Blacksmith dikelola lewat baris kuota di panel JOBS. Alt + tombol job mengubah prioritas; atau klik tombol + / - di panel job.
- G: kirim seluruh prajurit untuk menyerbu benteng lawan yang sudah ditemukan; tekan lagi untuk menarik mereka kembali ke Keep
- P / Esc (saat tidak membangun): menu jeda (simpan, muat, resolusi jendela, layar penuh, VSync, volume)
- Menu jeda > Atur kontrol: rebind gerak, interaksi, serang, dan lari; gamepad tetap didukung
- F5: simpan | F9: muat | H: bantuan kontrol | F3: tampilkan FPS
- R: mulai ulang setelah game over | L: muat save terakhir dari layar game over

## Tampilan dan resolusi
Jendela default 1280×720 dengan minimum 960×540. Menu jeda menyediakan preset 16:9, 16:10, dan 4:3; resolusi jendela tersimpan, sedangkan fullscreen tetap terpisah. Viewport logis mengikuti setengah ukuran jendela pada skala pixel tepat 2×: 640×360 pada 1280×720, 800×450 pada 1600×900, dan 960×540 pada 1920×1080; minimum viewport 480×270. Resolusi lebih tinggi memperlihatkan lebih banyak dunia tanpa mengubah zoom kamera, ukuran tile, kecepatan gerak, jangkauan serangan atau aturan gameplay. HUD tetap pada ukuran logis yang sama di pita atas/bawah sehingga area tengah permainan bertambah. HUD, hotbar, peta, panel teknologi dan menu jeda mengikuti perubahan resolusi/fullscreen.

## Sistem permainan

**Mode:** Classic mempertahankan dunia 64×64 dan kampanye 15 hari. Frontier memakai dunia 128×128, lima biome, empat stronghold, 11 objective regional, dan kampanye Conquest 20 hari/4 act. **Frontier Expedition** kini tersedia di `main` sebagai pilihan opsional 192×192: mulai dari heartland 128×128, lalu buka empat outer marches satu per satu dengan mencapai crossing survey di tiap region. Stronghold, objective sites dan faction camps menunggu di outer marches; fog-of-war permanen mengungkap dunia secara bertahap. Progres gate memakai discovery objective yang sudah ada. Mainline save schema saat ini v17 setelah integrasi Hunter, Scout, Healer, dan Blacksmith; save v1–v16 tetap didukung melalui migrasi. PR #63 historically passed its 88/88 multi-version/export pipeline; current development CI targets Godot 4.7 only and release exports are deferred. Status fitur dan backlog terbaru tercatat di roadmap.

### Siklus pertahanan
- Bertahan selama 15 hari; pada malam terakhir, kalahkan Raja Lawan.
- Keep memiliki 1000 HP. Jika hancur, permainan berakhir.
- Satu siklus siang-malam berlangsung 180 detik; fase serangan malam berlangsung sekitar 54 detik.
- Gelombang dimulai dari 6 musuh dan bertambah 3 per hari, hingga batas 120. Peringatan senja muncul 9 detik sebelum fase serangan malam.
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
- Atur penebang, penambang, petani, Hunter, dan prajurit melalui T/M/K/B/J/U/I/R, termasuk Healer melalui I. Tombol kuota di HUD tetap tersedia.
- Setiap penduduk mengonsumsi 2 makanan per hari. Kekurangan makanan membuat satu penduduk pergi. Setelah riset Lumbung, petani memprioritaskan depot pangan khusus berkapasitas 240; Classic memakai cadangan lumbung untuk upkeep setelah Inventory pusat habis.
- Bangunan: rumah, tembok, Menara Pengawas (turret + vision 128px), Lumbung (240 pangan), gudang, ladang, tembok batu, tempa, Pos Terdepan, Kamp Penebang, Kuari, Pondok Pemburu, Pondok Pengintai, jalan, dan jembatan.
- Kamp Penebang menyediakan dua workplace woodcutter dengan radius kerja 18 tile; Kuari menyediakan dua workplace miner dengan radius 16 tile. Pondok Pemburu (3×2, biaya 26 kayu + 8 batu) menyediakan dua slot Hunter dengan radius 18 tile. Tiap hewan memberi 5 pangan setelah tiga serangan; node pulih setelah 105 detik. Pondok Pengintai (3×2, biaya 24 kayu + 10 batu) menyediakan dua slot Scout dengan radius kerja 22 tile; Scout menjelajahi sektor terjangkau dengan penglihatan lokal 144px dan kembali ke Post saat tidak ada area baru yang dapat dijangkau. Balai Perawatan (3×2, biaya 34 kayu + 24 batu) menyediakan dua slot Healer dengan radius 16 tile; Healer memprioritaskan prajurit terluka dan memulihkan 10 HP setiap 3,2 detik. Tempa memiliki dua slot Blacksmith dengan radius 18 tile; Blacksmith membuat senjata (3 besi + 1 kayu, +20% damage) dan zirah (4 besi + 2 kayu, +20% HP maksimum) untuk prajurit secara individual setelah riset Iron Weapons/Iron Armor. Jika belum ada fasilitas khusus, pekerja tetap memakai radius depot seperti pada Classic lama. Jika semua slot fasilitas penuh, pekerja tambahan tidak mengambil alih area kerja fasilitas tersebut.
- Pada Frontier, Gudang menampung 180 unit, Outpost 120 unit, dan Lumbung 240 unit pangan (hanya menerima food). Petani memprioritaskan Lumbung untuk setor pangan; tiap 3 detik depot terhubung mengirim maksimal 6 unit ke Keep secara otomatis. Lumbung bisa menjadi asal/tujuan pengiriman pangan, tetapi tidak bisa menjadi sumber biaya konstruksi atau riset. Depot yang terputus menyimpan stok sampai jalurnya tersambung. Buka `JOBS → POS` untuk melihat saldo, memilih **satu sumber biaya** (Keep/Gudang/Outpost), dan membuat perintah angkut manual. Konstruksi, riset, dan perbaikan mendebit depot yang dipilih saja; saldo beberapa depot tidak digabung. Depot remote harus tetap terhubung ke Keep. Depot yang terputus di wilayah enemy/contested mendapat peringatan 30 detik sebelum saboteur pertama tiba pada detik ke-60; maksimal dua gelombang per isolasi. Saboteur menyerang depot dan mencuri satu resource setiap dua hit dengan urutan food, iron, wood, stone. Hubungkan jalan kembali atau amankan wilayah untuk menghentikan raid; Outpost guards dan prajurit dapat melawan saboteur. Carrier shipment terlihat berjalan di peta; cargo dicadangkan saat order dibuat, status order terlihat di panel, dan order aktif bisa dibatalkan untuk mengembalikan cargo. Pengiriman menuju Keep memasukkan stok ke inventori pusat.
- Teknologi 21-node dalam 3 era memperkuat ekonomi, pertahanan, eksplorasi, dan pengepungan.

### Simpanan dan pengaturan
- Autosave setiap fajar; simpan manual dengan F5 dan muat dengan F9.
- Save versi 17 menyimpan world/campaign state, objektif regional, occupation Hunter/Scout/Healer/Blacksmith, equipment senjata dan zirah individual prajurit, depletion/regrowth satwa liar, stok depot, sumber biaya aktif, penugasan penjaga, order angkut dan cargo yang masih dalam perjalanan; save versi 1–16 tetap diterima.
- Penulisan save memakai file sementara dan salinan pemulihan; loader mencoba salinan tersebut bila file utama rusak.
- Pengaturan layar penuh, VSync, volume, dan guncangan layar tersimpan di `user://settings.cfg`.

## Membuat build rilis
1. Di Godot: Editor > Manage Export Templates > Download and Install (versi 4.7)
2. Jalankan `tools/build.sh` (Linux/macOS) atau `tools/build.ps1` (Windows).
   Atur lokasi Godot lewat variabel `GODOT`
3. Hasil: `build/windows/HoldTheKeep.exe` dan `build/linux/HoldTheKeep.x86_64` (PCK tertanam)

## Teknologi
Pohon riset 21 teknologi dalam 3 era (data/techs.json), dibuka dengan Y. `field_medicine` (Era II) unlocks the two-slot Infirmary; Healer is assigned with I and heals wounded friendly soldiers for 10 HP every 3.2 seconds within 16 tiles. Blacksmith uses the existing Forge and researched `iron_weapons`/`iron_armor` technologies to craft permanent individual soldier upgrades. Hunter, Scout, Healer and Blacksmith are merged into `main` through PRs #64, #65, #67 and #68. Manual rendered gameplay, equipment visibility, economic pacing and combat-balance acceptance remain open:
- **Era Kayu** (awal): perkakas, bajak, palisade, rumah panjang, panah berbulu, dan **Ilmu Batu** (naik era)
- **Era Batu**: perkakas batu, lumbung, menara batu, zirah kulit, latihan prajurit, dan **Tambang Besi** (naik era)
- **Era Besi**: perkakas, senjata, zirah, menara, dan benteng besi (sebagian butuh bangunan Tempa)
Satu riset berjalan pada satu waktu; bahan dibayar di awal dari sumber biaya aktif di `JOBS → POS` (Classic tetap memakai inventori pusat Keep). Ilmu Batu membuka Tembok Batu, Tambang Besi
membuka Tempa dan membuat bijih besi (urat oranye, jauh dari keep) bisa ditambang. Penambang villager
memilih besi bila stoknya kurang dari separuh batu. Game di-pause saat panel terbuka.
Efek berupa data (pengali, penambah, buka bangunan, bendera) lewat `Tech.stat(kunci, dasar)`.

## Peta dan wilayah
Peta strategis dibuka dengan TAB atau tombol MAP di HUD. Peta menampilkan hanya area yang sudah ditemukan, marker posisi pemain dan batas viewport kamera, serta region dan klaim wilayah. Lokasi musuh bergerak hanya muncul saat berada dalam jangkauan pengamatan unit atau bangunan, bukan sekadar karena pernah dijelajahi. Tutup dengan X, klik area gelap di luar peta, TAB, atau Esc. Warna terrain membedakan Hearthland, Greenwood (lantai hutan), Highlands (dataran berbatu), Fenlands (rawa), dan Ashen March (khusus Frontier). Klaim pemain dan musuh diberi tint berbeda, sedangkan Keep, Outpost, resource, villager, dan pemain punya marker masing-masing.

## Wilayah dan kampanye
Keep mengklaim area awal dalam radius 10 tile. Pos Terdepan (hotkey 6) memperluas klaim dalam radius 9 tile dan hanya boleh dibangun di frontier sendiri. Benteng lawan ditempatkan pada lokasi yang dapat dicapai di peta yang sama, mengklaim radius 9 tile, dan dijaga oleh prajurit yang berpatroli serta menerima penguatan berkala. Garis emas menunjukkan wilayah pemain; garis merah menunjukkan wilayah lawan.

Fog of war menutup peta yang belum dijelajahi. Player, Keep, Pos Terdepan, dan villager membuka area; wilayah yang sudah ditemukan tetap terlihat setelah disimpan dan dimuat. Setelah benteng lawan ditemukan, tekan G untuk mengirim semua villager dengan job prajurit. Prajurit menyerang penjaga dahulu, lalu menghancurkan benteng (900 HP). Tekan G lagi untuk menarik pasukan kembali ke Keep. Classic mempertahankan jalur kemenangan 15 hari melawan Raja Lawan atau menaklukkan Keep lawan. Frontier adalah Conquest 20 hari: empat stronghold dan seluruh objektif regional harus selesai sebelum Raja pada hari ke-20 dikalahkan.

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
- Secondary motion pixel-snapped: napas idle yang tidak serempak, lift langkah, antisipasi/lunge serangan, lean kerja, dan recoil saat terkena pukul
- Dibuat oleh renderer humanoid berbasis pose di `tools/gen_assets.py`; ubah satu pose
  atau tampilan, jalankan ulang skrip, semua frame ikut berubah
- Pemutar animasi: `scripts/entities/sprite_anim.gd`

## Efek visual
- Busur tebasan pemain mengikuti arah hadap (menyapu dari aba-aba sampai pulih)
- Partikel ringan (satu node menggambar semua, maksimal 500): percikan saat musuh kena,
  serpihan kayu dan batu saat panen, debu langkah saat berlari, puing saat bangunan diserang,
  awan puing saat bangunan hancur atau raja tumbang; impact burst berkontras tinggi dan streak pendek untuk partikel cepat
- Guncangan layar (bangunan hancur, pemain kena, langkah raja, raja tumbang); bisa dimatikan
  di menu jeda ("Guncangan layar") dan tersimpan di settings.cfg
- Efek dipicu lewat `Events.fx_burst(kind, pos, dir, amount)` dan `Events.screen_shake(strength, duration)`;
  jenis partikel ditambah di `KINDS` pada `scripts/entities/fx_layer.gd`

## Kredit
Font HUD: Silkscreen (c) The Silkscreen Project Authors, SIL Open Font License 1.1
(lihat `assets/fonts/OFL-Silkscreen.txt`). Font hanya punya huruf kapital.

Belum ada: musik, rebind shortcut UI/job/build, upgrade khusus invasi, ikon .ico untuk Windows, integrasi Steam.
Banyak aset karakter/lingkungan masih dihasilkan secara prosedural dan belum memiliki identitas seni final per faksi/biome. Phase 08 visual/audio identity belum selesai.


## Frontier Conquest
Frontier memakai kampanye 20 hari dalam empat act; Classic tetap 15 hari. Tekan **O** untuk membuka tracker objektif. Tekan **TAB** untuk peta strategis; situs objektif yang sudah ditemukan muncul sebagai marker dengan bentuk/warna sesuai jenis. Marker untuk act terkunci dibuat redup. Gunakan **E** di situs bertanda untuk memulai penyelamatan/pengawalan atau mengaktifkan pertahanan; kamp dan reruntuhan dihancurkan dengan serangan pemain. Cartography memperluas reveal radius Outpost; Siegecraft meningkatkan damage pemain terhadap stronghold, kamp, dan reruntuhan. Kemenangan Conquest mensyaratkan semua objektif regional, empat stronghold, dan Raja pada hari ke-20.
