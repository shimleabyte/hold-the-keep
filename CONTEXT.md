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

## 2. Status fitur (implementasi aktif; status verifikasi per suite dicatat di bagian 6)
| Area | Isi |
|---|---|
| Dunia | peta 64x64 prosedural (seed 1337): Hearthland, Greenwood, Highlands, Fenlands; enam atlas terrain termasuk air; resource generation tetap deterministik |
| Wilayah | klaim pemain dari Keep/Outpost, klaim musuh dari benteng, ownership check, frontier expansion |
| Kampanye | tiga bab (hari 1–5, 6–10, 11–15), bobot musuh berubah per bab, benteng lawan 900 HP, garrison, fog permanen, ekspedisi (G), conquest victory |
| Pemain | gerak 8 arah, lari (Shift), serang radial, panen, HP 100 + regen, respawn di keep |
| Bangunan | keep, rumah, tembok, menara, gudang, ladang; data di `data/buildings.json`; bongkar refund 50% |
| Musuh | bandit, serigala pouncer, soldier melee, archer ranged, brute siege, Raja Lawan; flow field; role-specific AI dan structure damage |
| Villager | job penebang/penambang/petani/prajurit, kuota diatur pemain, A*, setor ke gudang/keep |
| Ekonomi | kayu, batu, makanan; kapasitas rumah; upkeep 2 makanan/penduduk/hari |
| Event acak | 6 jenis di `data/events.json`, awal hari mulai hari 2 (60%) |
| Save/load | versi 6, autosave tiap fajar, F5/F9, file sementara + rollback backup, resource/fog/stronghold/garrison/ekspedisi/recall/combat progression tersimpan |
| Kontrol | rebind keyboard untuk gerak, interaksi, serang, lari; gamepad default tetap ada |
| Tampilan | windowed 1280×720 default, minimum 960×540 (enforced through `Window.min_size`), preset 16:9/16:10/4:3, integer-scaled viewport dengan aspect expand |
| HUD | top bar ringkas, vitals, indikator bab, combat strip kompak, drawer JOBS, peta strategis TAB/MAP, hotbar bangunan, bar boss, bantuan (H) |
| Animasi | 22 frame x 3 arah per karakter; serang/panen jatuh di frame benturan |
| Efek | partikel, busur tebasan, guncangan layar (bisa dimatikan) |
| Audio | SFX prosedural (12 suara); **belum ada musik** |
| Teknologi | 17 teknologi, 3 era, panel Y, bijih besi, Tempa, tembok batu; efek berupa data (`Tech.stat`) |
| Rilis | export preset Windows+Linux, `tools/build.sh|ps1` (template export belum pernah dipasang di sini) |

## 3. Struktur
```
project.godot          autoload, display, rendering, debug log
scenes/main.tscn       satu node dengan script main.gd (semua dirakit lewat kode)
scripts/main.gd        merakit dunia, pemain, flow, nav, village, event, spawner, build, territory, fog, enemy keep, HUD, menu
scripts/autoload/      InputSetup, Events (signal bus), DataDB (JSON), Settings, Inventory, Tech,
                       GameClock, SaveSystem, Audio
scripts/world/         world_map.gd (tileset biome dari tiles.svg, noise, pohon/batu, occupied dict)
scripts/systems/       flow_field (Dijkstra musuh), nav_grid (AStarGrid2D villager), build_system, territory,
                       fog_of_war (peta permanen), village/expedition, wave_spawner, event_manager
scripts/entities/      player, enemy, enemy_keep (stronghold/garrison source), villager (expedition/recall), building, resource_tree, rock, iron_ore, arrow, corpse,
                       fx_layer, sprite_anim
scripts/ui/            hud.gd (layout viewport-aware), world_map_panel.gd, tech_panel.gd, pause_menu.gd (window-size presets), pixel_font.gd
data/                  buildings.json, enemies.json, waves.json, events.json, techs.json
assets/sprites/        40 SVG pixel-art (dibuat oleh tools/gen_assets.py)
assets/fonts/          Silkscreen (OFL) + lisensinya
tools/                 gen_assets.py (generator SVG), build.sh, build.ps1
tests/                 skrip tes headless dan screenshot (lihat tests/README.md)
```
Grup node yang dipakai lintas skrip: `main`, `hud`, `player`, `village`, `buildings`, `depots`, `farms`,
`harvestable`, `resource_nodes`, `enemies`, `ranged_enemies`, `enemy_projectiles`, `enemy_garrison`, `enemy_strongholds`, `villagers`, `defenders`, `fog_of_war`.

## 4. Konvensi arsitektur
- **Signal bus**: sistem berkomunikasi lewat `Events` (resource_changed, building_*, village_changed,
  fx_burst, screen_shake, game_over, game_won, ...). Hindari `get_node` panjang antar sistem.
- **Data-driven**: stat bangunan/musuh/gelombang/event di JSON; `DataDB` memuatnya. JSON harus ikut
  export (`include_filter="*.json"` sudah di preset).
- **Semua visual dari SVG** + `_draw()`; sprite karakter = sheet 22 frame x 3 baris (depan, belakang,
  samping menghadap kanan, kiri = flip). `SpriteAnim` memilih frame; klip: idle, walk, run, attack,
  work, hurt, death. Titik tumpu = tengah-bawah kanvas, Y-sort di `world.entities`.
- **Territory**: `territory.gd` menghitung klaim Keep/Pos Terdepan dan benteng lawan. Klaim merah memblokir bangunan pemain; Outpost hanya sah jika seluruh footprint di luar klaim musuh dan setidaknya satu tile menyentuh frontier.
- **Fog**: `fog_of_war.gd` menyimpan eksplorasi permanen dari player, Keep, Outpost, dan villager; bit-map eksplorasi tersimpan di save versi 4.
- **Campaign**: `enemy_keep.gd` memiliki 900 HP, garrison dan reinforcement. Villager dengan job soldier dapat menjadi ekspedisi, melawan garrison, lalu menghancurkan stronghold.
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
- Base suite sebelumnya tercatat lolos di Godot 4.3 dan (yang relevan) 4.7; perubahan campaign menambah `tests/campaign_assault.gd`. Tes baru ini belum dijalankan pada sesi implementasi ini karena executable Godot tidak tersedia di environment kerja. Jalankan seluruh suite setelah pull branch.
- Angka perf historis: ~2 ms/frame untuk 150 musuh + 42 villager + 300 partikel (headless, tanpa render); belum mengukur biaya fog/campaign.
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
- Save versi 6 memulihkan HP/timer resource, fog eksplorasi, posisi/HP benteng, timer reinforcement, garrison, status ekspedisi/perjalanan pulang, serta level/XP tempur; save versi 1–5 tetap diterima dengan default untuk field baru.
- Satu arah samping digambar; kiri/kanan identik (cermin). Animasi dari pose prosedural, bukan gambar tangan.
- Tidak ada musik; SFX prosedural sederhana.
- Rebind empat kelompok kontrol inti sudah ada melalui menu jeda; shortcut UI/job/build masih tetap.
- Teks HUD hanya huruf kapital; automated bounds coverage for common non-16:9 logical sizes has been added. Visual rendering still needs manual confirmation in Godot.
- Map overlay is responsive to expanded logical viewport dimensions; the new automated layout test is committed, but actual rendered screenshots still need manual confirmation.

## 9. Rencana berikut (belum dikerjakan)
1. Mainkan dan catat bagian yang janggal; sesuaikan balancing hari 2-14 (teknologi mengubah kurva kekuatan).
2. **Kampanye wilayah**: peta awal kini memiliki empat biome dan tiga bab progression. Tahap lanjut: beberapa map region yang dapat ditransisikan, beberapa stronghold berurutan, AI logistik/serangan musuh lintas wilayah, dan upgrade ekspedisi.
3. Rebind shortcut UI/job/build dan navigasi menu; kontrol gerak/interaksi/serang/lari sudah dapat diubah.
4. Musik (komposisi/aset) dan SFX untuk partikel.
5. Tooltip pada slot bangunan dan ikon job; ikon .ico Windows; integrasi Steam (opsional).

## 9b. Tahap lanjutan kampanye wilayah
Fase pertama conquest sudah tersedia pada peta 64x64: satu benteng lawan ditempatkan di lokasi yang dapat dicapai; klaimnya bertabrakan secara aturan dengan pembangunan pemain; fog of war permanen memperlihatkan wilayah setelah dieksplorasi; G mengirim/menarik pasukan prajurit; garrison bertahan saat fajar dan direinforce; benteng hancur memicu kemenangan.

Tahap berikutnya sebaiknya memperluas skala tanpa merusak loop yang ada: (1) peta/region tambahan dengan streaming atau transisi terkontrol; (2) lebih dari satu stronghold dan jalur conquest berurutan; (3) AI lawan yang membangun, mengumpulkan resource, dan mengirim raid; (4) logistik ekspedisi seperti suplai makanan, rally point, dan biaya korban; (5) tech/upgrade untuk siege equipment dan unit ofensif. Jangan menambah banyak basis sebelum satu campaign slice ini tervalidasi dalam build Godot sungguhan.

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


## 12. Update save system (2026-10-30)
- Save format naik ke versi 2; versi 1 tetap diterima sebagai data lama tanpa status resource.
- Pohon, batu, dan bijih besi menyimpan HP serta sisa waktu tumbuh ulang. Restore dilakukan dengan cell koordinat pada peta yang dihasilkan deterministik.
- Penulisan memakai temporary file, rollback copy, dan validasi struktur dasar sebelum reload.
- Jika save utama tidak dapat diparse atau tidak valid, loader mencoba `user://save.bak`.
- Tes baru: `tests/resource_save_state.gd` memeriksa round-trip status node dan fallback dari save utama yang rusak.


## 13. Update input (2026-10-30)
- `Settings` memuat dan menyimpan keybind utama pada section `[input]` di `user://settings.cfg`.
- Menu jeda memiliki panel "Atur kontrol" untuk gerak, interaksi, serang, dan lari.
- Konflik antar-keybind inti dan tombol reserved untuk menu, riset, bantuan, save/load, job, serta slot bangunan ditolak.
- Binding gamepad dan mouse untuk attack tetap dipertahankan saat keyboard binding diganti.
- Hotkey UI/job/build di luar tujuh aksi inti belum dapat di-rebind.


## 14. Update kampanye wilayah (2026-11-01)
- Benteng lawan 3x3 ditempatkan secara deterministik pada site kosong yang dapat dicapai; memiliki 900 HP, klaim radius 9, sprite dan health bar sendiri.
- Stronghold memunculkan garrison prajurit, menjaga radius lokal, dan merekrut pengganti secara berkala hingga cap 4. Garrison tidak ikut despawn pada fajar.
- Fog of war permanen membuka area dari player, Keep, Outpost, dan villager; peta eksplorasi ikut save versi 4.
- G mengirim semua villager dengan job soldier ke ekspedisi setelah benteng ditemukan; G kedua mengarahkan mereka pulang ke Keep.
- Prajurit ekspedisi memprioritaskan garrison, lalu menyerang stronghold. Benteng hancur membersihkan garrison dan memicu campaign victory.
- Save versi 5 menambahkan stronghold, reinforcement, garrison, ekspedisi/recall, dan fog discovery; save versi 6 menambahkan level/XP pemain. Versi 1–5 tetap diterima dengan default field baru.
- Tes regresi baru: `tests/campaign_assault.gd`.


## 15. Combat progression and enemy roles (2026-11-01)
- Player gains XP on enemy kills. Level-ups restore 18 HP; level and XP persist in save version 6. Saves v1–v5 load with level 1 / 0 XP defaults.
- Active abilities: Q Dash (level 1, short burst + brief invulnerability + impact stagger), C Cleave (level 2, frontal area strike + stagger), V Rally (level 3, temporary player and nearby soldier damage/attack-rate buff). Each skill has an independent cooldown. HUD shows XP progress, unlock state and cooldown state.
- Friendly soldiers carry a timed Rally buff during ordinary defense and expeditions.
- Enemy roles: bandit melee raider; wolf pouncer with wind-up and lunge; archer keeps preferred distance and fires homing hostile bolts; brute has armor and deals multiplied damage to structures; final king gains armor and siege damage.
- Wave roster adds archers on day 6 and brutes on day 9. New roles reuse existing humanoid sprite sheets with role-specific markers; bespoke enemy art remains a future visual pass.
- Regression coverage: `tests/player_combat.gd` checks XP unlocks, dash movement/invulnerability, directional Cleave, Rally buffs, archer projectile launch, brute armor and save data. The test is committed but unexecuted because Godot is not installed in the current environment.


## 16. Strategic map, campaign acts, and compact HUD (2026-11-01)
- `scripts/ui/world_map_panel.gd` adds a TAB/MAP exploration-aware map with terrain, territory tint, resource/building/unit/player markers, and current camera viewport. Permanently explored fog is used for terrain memory; live enemy markers are restricted to current observation ranges.
- `scripts/world/world_map.gd` defines four named regions: Hearthland, Greenwood, Highlands, and Fenlands. Their ground tiles differ while retaining the same 64x64 grid and water collision. Original tree/rock spawn probabilities and RNG draw order are preserved to keep saved resource cells compatible.
- `data/waves.json` defines three campaign acts: Frontier (days 1–5), Black March (6–10), Last Siege (11–15). `wave_spawner.gd` applies archer pressure in Act II and archer/brute pressure in Act III; stage changes update the HUD banner and progress indicator.
- HUD keeps core status and build hotbar visible. Job quotas move behind JOBS; map is opened by TAB/MAP and closes with its X, backdrop click, TAB, or Escape; job drawer closes with JOBS or Escape. Combat strip and tech button occupy less screen space.
- `tests/map_stages.gd` covers regional labels, map visibility, act boundaries, and act-specific enemy weights. Godot execution remains pending in an environment with the engine installed.


## 17. Responsive resolution and UI visual pass (2026-11-01)
- Project base remains 480×270 with viewport rendering and integer scaling; stretch aspect is `expand` so wider/taller desktop windows reveal more world instead of distorting pixel art. Integer scaling can still leave unused margins where the window dimensions do not align to an integer multiple of the logical viewport.
- Default window is 1280×720; minimum is 960×540. Pause settings expose monitor-filtered 16:9, 16:10, and 4:3 window-size presets, remember the selected windowed size, and keep fullscreen as a separate mode.
- HUD listens to viewport size changes. Resource/time strip spans the top; vitals and job drawer anchor to opposite sides; stage and boss panels center; map centers and scales; combat strip and building hotbar stay above the bottom edge.
- Strategic map scales its tile grid and legend to the available viewport. Technology and pause overlays use full-viewport roots and centered panels.
- Updated panel surfaces, borders, shadows, focus/hover/pressed button states, and resource color hierarchy.
- `tests/responsive_layout.gd` checks viewport settings and panel/hotbar bounds across 480×270, 640×360, 640×400, 683×384, and 960×540 logical viewports. Godot compile/render execution remains pending.

## 18. Character animation and impact feedback pass (2026-11-01)
- `scripts/entities/sprite_anim.gd` adds pixel-snapped secondary motion: desynchronized idle breathing, walk/run lift, directional attack anticipation/lunge, work lean at the strike point, and hurt recoil. Translation is separated from horizontal mirroring so left-facing attacks move in the correct direction.
- `scripts/entities/fx_layer.gd` adds a short high-contrast impact burst and directional streaks for fast particles. Enemy damage now uses the dedicated impact burst instead of the generic spark.
- `tests/animation_motion.gd` asserts the expected motion direction and state-specific behavior. Godot execution and rendered frame comparisons remain pending because the engine is unavailable in the implementation environment.
