# Konteks proyek: Hold the Keep

Dokumen ini ringkasan keadaan proyek supaya sesi kerja berikutnya (manusia atau AI) bisa langsung
melanjutkan tanpa membaca ulang seluruh riwayat. **Perbarui bagian "Status" dan "Riwayat" setiap
selesai satu paket pekerjaan.** README.md = panduan pemain/pengembang singkat; file ini = konteks.

## 1. Ringkasan
- Game 2D top-down **village defense + light management** bertema medieval. Solo dev, semi-lightweight.
- **Native desktop, bukan web** (keputusan eksplisit pemilik). Godot 4 + GDScript, renderer GL Compatibility.
- Versi: dibuat dan dites di **Godot 4.3**, juga lolos di **4.7-stable**. Minimum 4.3 (memakai `TileMapLayer`).
- Resolusi dasar 480x270 (stretch `viewport`, scale `integer`), jendela default 1440x810, pixel art.
- Tujuan pemain: bertahan 15 hari, di malam ke-15 kalahkan Raja Lawan. Keep hancur = kalah.
- Loop: siang (kumpul, bangun, atur villager) -> malam (gelombang musuh) -> fajar (event acak, autosave).

## 2. Status fitur (semua ada dan teruji headless)
| Area | Isi |
|---|---|
| Dunia | peta 64x64 prosedural (seed 1337): rumput, kolam (collision), pohon, batu |
| Pemain | gerak 8 arah, lari (Shift), serang radial, panen, HP 100 + regen, respawn di keep |
| Bangunan | keep, rumah, tembok, menara, gudang, ladang; data di `data/buildings.json`; bongkar refund 50% |
| Musuh | bandit, serigala, prajurit, Raja Lawan; flow field; menyerang bangunan/pemain/prajurit |
| Villager | job penebang/penambang/petani/prajurit, kuota diatur pemain, A*, setor ke gudang/keep |
| Ekonomi | kayu, batu, makanan; kapasitas rumah; upkeep 2 makanan/penduduk/hari |
| Event acak | 6 jenis di `data/events.json`, awal hari mulai hari 2 (60%) |
| Save/load | 1 slot `user://save.json`, autosave tiap fajar, F5/F9 |
| HUD | panel atas, vitals, kuota job (klik), bar bangunan (klik), bar boss, bantuan (H) |
| Animasi | 22 frame x 3 arah per karakter; serang/panen jatuh di frame benturan |
| Efek | partikel, busur tebasan, guncangan layar (bisa dimatikan) |
| Audio | SFX prosedural (12 suara); **belum ada musik** |
| Teknologi | 17 teknologi, 3 era, panel Y, bijih besi, Tempa, tembok batu; efek berupa data (`Tech.stat`) |
| Rilis | export preset Windows+Linux, `tools/build.sh|ps1` (template export belum pernah dipasang di sini) |

## 3. Struktur
```
project.godot          autoload, display, rendering, debug log
scenes/main.tscn       satu node dengan script main.gd (semua dirakit lewat kode)
scripts/main.gd        merakit dunia, pemain, flow, nav, village, event, spawner, build, HUD, menu, keep
scripts/autoload/      InputSetup, Events (signal bus), DataDB (JSON), Settings, Inventory, Tech,
                       GameClock, SaveSystem, Audio
scripts/world/         world_map.gd (tileset dari tiles.svg, noise, pohon/batu, occupied dict)
scripts/systems/       flow_field (Dijkstra musuh), nav_grid (AStarGrid2D villager), build_system,
                       village (kapasitas, spawn, kuota, upkeep), wave_spawner, event_manager
scripts/entities/      player, enemy, villager, building, resource_tree, rock, iron_ore, arrow, corpse,
                       fx_layer, sprite_anim
scripts/ui/            hud.gd, tech_panel.gd, pause_menu.gd, pixel_font.gd
data/                  buildings.json, enemies.json, waves.json, events.json, techs.json
assets/sprites/        40 SVG pixel-art (dibuat oleh tools/gen_assets.py)
assets/fonts/          Silkscreen (OFL) + lisensinya
tools/                 gen_assets.py (generator SVG), build.sh, build.ps1
tests/                 skrip tes headless dan screenshot (lihat tests/README.md)
```
Grup node yang dipakai lintas skrip: `main`, `hud`, `village`, `buildings`, `depots`, `farms`,
`harvestable`, `enemies`, `villagers`, `defenders`.

## 4. Konvensi arsitektur
- **Signal bus**: sistem berkomunikasi lewat `Events` (resource_changed, building_*, village_changed,
  fx_burst, screen_shake, game_over, game_won, ...). Hindari `get_node` panjang antar sistem.
- **Data-driven**: stat bangunan/musuh/gelombang/event di JSON; `DataDB` memuatnya. JSON harus ikut
  export (`include_filter="*.json"` sudah di preset).
- **Semua visual dari SVG** + `_draw()`; sprite karakter = sheet 22 frame x 3 baris (depan, belakang,
  samping menghadap kanan, kiri = flip). `SpriteAnim` memilih frame; klip: idle, walk, run, attack,
  work, hurt, death. Titik tumpu = tengah-bawah kanvas, Y-sort di `world.entities`.
- **Occupancy**: `world.occupied` (Vector2i -> Node) berisi pohon, batu, bangunan; dipakai build_system,
  flow field, nav grid. Flow field: bangunan dilewati dengan biaya (musuh menghancurkannya), pohon/batu/air tidak.
- **Grid**: tile 16 px, peta 64x64, tepi peta = air.
- Tidak ada `class_name`; skrip lintas-file dirujuk lewat `preload` agar tidak bergantung cache kelas.
- Nama dan teks UI memakai bahasa Indonesia; font hanya huruf kapital (Silkscreen).

## 4b. Sistem teknologi (autoload `Tech`)
- `data/techs.json`: id, nama, era, biaya, waktu (detik game), prasyarat, `building` (bangunan yang harus ada),
  deskripsi, `effects`. Efek: `mult` {kunci: pengali}, `add` {kunci: tambahan}, `era`, `unlock_building`, `flags`.
- Sistem lain bertanya `Tech.stat(kunci, dasar)` = dasar x produk pengali + jumlah tambahan. Kunci yang dipakai:
  villager.gather_speed, villager.carry, farm.yield, farm.workers, house.capacity, <bangunan>.hp (wall, stone_wall,
  tower, keep), tower.damage, tower.range, soldier.hp, soldier.damage, player.damage.
- Satu riset pada satu waktu, bahan dibayar di awal, `Tech._process` menghitung progres (berhenti saat pause).
  Bangunan dan villager yang sudah ada memperbarui stat lewat `Events.tech_researched` (HP diskalakan proporsional).
- Bangunan `"locked": true` di buildings.json (tembok batu, tempa) muncul di bar setelah dibuka; selalu di ujung
  kanan agar nomor hotkey lama tidak bergeser. `Tech.available_buildings()` = urutan bar dan hotkey.
- Bijih besi (`iron_ore.gd`, 8 urat, RNG terpisah): grup `ore_locked` sampai flag `iron_mining`, lalu `harvestable`.
- Status riset ikut save (`"tech"`); save lama tanpa kunci ini dibaca sebagai kosong.
- UI: `tech_panel.gd` (Y, pause), tombol RISET + bar progres + chip besi di HUD, bar bangunan dinamis.

## 5. Angka balancing saat ini
- Hari 180 detik; malam 0.6-0.9 (54 detik). Gelombang = 6 + 3/hari (maks 120); hari 15 = 48 musuh. Serigala dari hari 2, prajurit dari hari 4.
- Keep 1000 HP, menara 12 damage / 0.9 dtk / jangkauan 96, prajurit 60 HP 8 damage, pemain 100 HP 9 damage.
- Raja Lawan 1400 HP, 30 damage. Awal: 25 kayu, 12 makanan, 2 penduduk.
- Simulasi malam terakhir (tanpa pemain, tanpa tembok), tangga kesulitan terhadap teknologi:
  tanpa teknologi 6+3 kalah, 8+4 menang tipis; teknologi era Kayu+Batu: 4+2 kalah, 6+3 menang;
  semua teknologi: 4+2 menang. Hasil bervariasi antar-run. **Belum pernah dimainkan manusia**; hari 2-14 hanya
  disimulasikan sebagian.

## 6. Cara memverifikasi
- Jalankan: `godot --headless --path . --import` sekali, lalu `godot --headless --fixed-fps 60 --path . --script tests/<x>.gd`.
- Render nyata lewat Xvfb + OpenGL software untuk screenshot (lihat tests/README.md).
- Semua suite terakhir lolos di 4.3 dan (yang relevan) di 4.7. Perf: ~2 ms/frame untuk 150 musuh +
  42 villager + 300 partikel (headless, tanpa render).
- Setelah mengubah `tools/gen_assets.py`: `python3 tools/gen_assets.py`, lalu import ulang.

## 7. Keputusan penting dan alasannya
- Godot 4 dipilih dibanding framework kode-saja demi kecepatan menyelesaikan game.
- Aset sementara berupa SVG hasil generator (permintaan pemilik), bisa diganti PNG/Aseprite kelak
  dengan nama sama; konvensi titik tumpu harus dijaga.
- Damage serangan jatuh di frame benturan (bukan saat input) supaya animasi terasa nyata; hurt tidak
  membatalkan serangan musuh yang sedang berjalan (agar balancing tidak berubah).
- Job dipilih dengan kuota (bukan menunjuk villager satu per satu) agar manajemen tetap ringan.
- Teknologi dibuat sebagai jalur penguatan utama, jadi malam terakhir dinaikkan (gelombang +3/hari, raja 1400 HP) setelah
  simulasi menunjukkan 4+2 sudah menang dengan teknologi era 2.
- Efek teknologi berupa data generik (bukan if per teknologi) agar mudah dipakai untuk fitur wilayah/invasi nanti.
- Tombol job T/M/K/R (bukan Z/X/C/V) karena font Silkscreen membuat Z terbaca sebagai angka 2.
- Event sintetis di tes HUD memakai koordinat jendela, bukan viewport (lihat tests/README.md).

## 8. Batasan dan masalah yang diketahui
- Visual belum pernah dilihat di mesin pemilik (semua render lewat software di server).
- Build executable sungguhan belum pernah dibuat (butuh export template Godot; PCK sudah teruji).
- Status pohon/batu tidak ikut disimpan (tumbuh lagi saat load).
- Satu arah samping digambar; kiri/kanan identik (cermin). Animasi dari pose prosedural, bukan gambar tangan.
- Tidak ada musik; SFX prosedural sederhana.
- Rebind kontrol belum ada (aksi didaftarkan di `input_setup.gd`).
- Teks HUD hanya huruf kapital; resolusi non-16:9 belum diuji.

## 9. Rencana berikut (belum dikerjakan)
1. Mainkan dan catat bagian yang janggal; sesuaikan balancing hari 2-14 (teknologi mengubah kurva kekuatan).
2. **Visi pemilik: wilayah membesar + sistem invasi ke wilayah musuh** (belum dimulai; lihat 9b).
3. Rebind kontrol di menu + simpan ke settings.
4. Musik (komposisi/aset) dan SFX untuk partikel.
5. Tooltip pada slot bangunan dan ikon job; ikon .ico Windows; integrasi Steam (opsional).

## 9b. Catatan persiapan untuk wilayah dan invasi (gagasan pemilik, belum dikerjakan)
Yang sudah mendukung: efek teknologi generik (`unlock_building`, `flags`, `mult`/`add`) bisa dipakai untuk teknologi
wilayah/militer; bijih besi sengaja jauh dari keep sehingga memberi alasan untuk memperluas wilayah; `Events` dan
data JSON memudahkan menambah jenis unit/bangunan musuh.
Yang perlu dibangun lebih dulu: (1) abstraksi wilayah/region (kepemilikan tile, batas yang membesar; sekarang satu
peta 64x64 dengan `world.occupied` global), (2) unit ofensif (pasukan serang, bukan hanya penjaga keep),
(3) basis musuh dengan AI/pertahanan sendiri, (4) fog of war/penjelajahan, (5) kondisi menang/kalah baru
(boss malam ke-15 mungkin berubah peran), (6) save yang memuat banyak wilayah.
Disarankan memutuskan dulu: apakah dunia menjadi peta lebih besar yang terbuka bertahap, atau beberapa peta terpisah.

## 10. Riwayat singkat
1. Rencana game + pemilihan stack (Godot 4, native).
2. Minggu 1: peta, pemain, kamera, panen. 3. Sistem bangunan data-driven.
4. Musuh, flow field, menara, game over. 5. Villager, job, ekonomi, ladang, populasi.
6. Event acak, boss, kemenangan, balancing awal. 7. Save/load, menu, pengaturan, SFX, export preset.
8. Aset SVG + verifikasi render (Xvfb). 9. Font pixel + animasi dasar. 10. Kompatibilitas 4.7 diverifikasi.
11. Desain ulang HUD (panel, ikon, klik). 12. Animasi lengkap (22 frame x 3 arah) + hit di frame benturan.
13. Efek partikel, busur tebasan, guncangan layar. 14. Dokumen konteks ini + folder tests/.
15. Pohon teknologi (17 teknologi, 3 era), bijih besi, Tempa, tembok batu, panel Y, balancing diselaraskan.


## 11. Update wilayah (2026-10-30)
- `scripts/systems/territory.gd` membangun klaim radial dari Keep dan Pos Terdepan.
- Pos Terdepan harus menyentuh frontier saat ini; bangunan lain harus seluruh footprint-nya berada di wilayah yang diklaim.
- Klaim dihitung ulang dari bangunan aktif dan dilepas saat outpost dibongkar atau dihancurkan; save tidak perlu menyimpan bitmap klaim.
- Batas klaim digambar sebagai garis tipis di atas peta.
- Tahap ini belum menambah wilayah musuh, basis musuh, pasukan ekspedisi, fog of war, atau invasi. Itu tetap pekerjaan fase kampanye berikutnya.
