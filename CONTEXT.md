# Konteks proyek: Hold the Keep

Dokumen ini ringkasan keadaan proyek supaya sesi kerja berikutnya (manusia atau AI) bisa langsung
melanjutkan tanpa membaca ulang seluruh riwayat. **Perbarui bagian "Status" dan "Riwayat" setiap
selesai satu paket pekerjaan.** README.md = panduan pemain/pengembang singkat; file ini = konteks.

## 1. Ringkasan

**Current source of truth:** default branch `main` at `6cde7b9`; Phase 02 local logistics, Outpost garrisons and physical shipments merged by PRs #31–#33; save schema v13. Mainline workflow [#41323473817](https://github.com/shimleabyte/hold-the-keep/actions/runs/41323473817) passed 50/50 jobs. Branch `feat/phase-02-depot-cost-sources` implements a shared explicit Keep/Storage/Outpost cost source for construction, research and repair; its PR/CI are pending. See `ROADMAP_NEXT_LEVEL.md` and `docs/plans/` for current phase status.
- Game 2D top-down **village defense + light management** bertema medieval. Solo dev, semi-lightweight.
- **Native desktop, bukan web** (keputusan eksplisit pemilik). Godot 4 + GDScript, renderer GL Compatibility.
- Versi: dibuat dan dites di **Godot 4.3**, juga lolos di **4.7-stable**. Minimum 4.3 (memakai `TileMapLayer`).
- Jendela default 1280×720, minimum 960×540. Viewport logis mengikuti setengah ukuran client window (minimum 480×270), pixel art integer-scale tepat 2×.
- Tujuan pemain: bertahan 15 hari, di malam ke-15 kalahkan Raja Lawan. Keep hancur = kalah.
- Loop: siang (kumpul, bangun, atur villager) -> malam (gelombang musuh) -> fajar (event acak, autosave).

## 2. Status fitur
Ringkasan implementasi aktual pada `main` setelah PR #33 (save schema v13; status per 1 November 2026). Implementasi direct depot-funded costs masih berada pada branch yang disebutkan di atas, belum merged.

| Area | Kondisi saat ini |
|---|---|
| Dunia | Classic 64×64 / 15 hari tetap tersedia; Frontier 128×128 / 20 hari / 4 act dengan lima biome deterministik, 32 urat besi, dan starting Keep claim radius 15 |
| Wilayah | Regional ownership neutral/player/enemy/contested; roads/bridges walkable; supply graph dari Keep; depot terputus tidak menerima deposit |
| Logistik | **Parsial:** Storage 180 dan Outpost 120 unit memiliki local stockpile; worker deposits, bounded automatic Keep transfers, player-directed physical shipments, cargo escrow dan route recovery tersedia. Explicit cost source untuk build/research/repair sedang diimplementasikan di branch; raid vulnerability/attrition masih deferred |
| Kampanye | Classic satu stronghold; Frontier empat stronghold berurutan, garrison/reinforcement lokal, 11 objective regional, fog dan save/reload |
| Pemain | Gerak 8 arah, lari, serang, panen, HP/regen, respawn di Keep; XP dan Dash/Cleave/Rally |
| Bangunan | Keep, rumah, tembok, menara, gudang, ladang, tembok batu, tempa, Outpost, Lumber Camp, Quarry, road dan bridge; construction queue belum ada |
| Villager | Penebang, penambang, petani, soldier dan Builder; Hunter, Scout, Healer, Blacksmith belum tersedia |
| Faksi/musuh | Empat faction registry dan enam archetype definitions; War Shaman support berjalan; perilaku khusus seluruh archetype, camps, patrol, raids dan counterattacks belum lengkap |
| Ekonomi | Kayu, batu, makanan, iron; kapasitas rumah dan upkeep; local depot economy dan trade belum tersedia |
| Teknologi | 20 teknologi, tiga era, panel Y, Cartography dan Siegecraft |
| Save/load | v13 pada `main`; state world/campaign/objective/site/job/building/resource/faction/local depot inventory, shipment ledger dan escrow cargo; Classic v1–v13 dan Frontier v7–v13 migration matrix dijaga. Branch biaya menambahkan preferensi sumber secara optional tanpa bump versi; belum merged |
| Kontrol | Rebind gerak, interaksi, serang, lari; shortcut UI/job/build belum dapat di-rebind |
| Tampilan | Adaptive logical viewport = setengah ukuran client window, minimum 480×270, pixel scale tepat 2×; physical-display/fullscreen review belum dilakukan |
| HUD | Top bar, vitals, stage, combat strip, JOBS drawer, strategic map, hotbar, objective tracker, tech panel, pause menu |
| Audio | 12 procedural SFX; musik belum ada |
| Rilis | CI menghasilkan Windows/Linux export dengan Godot 4.3 templates; Linux headless smoke dan PE format diperiksa. Native Windows runtime dan clean-machine acceptance belum dilakukan |
| CI | Mainline workflow #41323473817: 50/50 jobs sukses setelah PR #33. Branch cost-source menargetkan 52 jobs setelah penambahan 1 assertion suite per engine; belum selesai |

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
- Latest mainline workflow #41314731305 completed with 46/46 successful jobs, including Godot 4.3/4.7 import/parse, assertion regressions, performance diagnostic, and Windows/Linux export checks. This is CI evidence, not a substitute for human campaign playtesting or physical-display review.
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
- Belum ada bukti screenshot dan playtest pada monitor fisik pemilik; render CI/software tidak menggantikan pemeriksaan display dan fullscreen.
- Belum ada full human playthrough Classic hari 1–15 dan Frontier act 1–4/day 20 yang terdokumentasi.
- Belum ada target-hardware benchmark yang mencatat CPU, GPU, OS, resolusi, workload, dan frame-time percentiles.
- Windows export telah dibuat dan diperiksa format PE di CI, tetapi belum dijalankan pada native Windows atau clean Windows machine.
- Local stockpile Storage/Outpost, Frontier worker deposits, dan atomic bounded automatic transfer to Keep sudah tersedia di `main` melalui PR #31; physical carrier/player-directed shipment dan local-stock spending masih belum tersedia.
- Outpost guard/garrison dan local visibility belum tersedia.
- Hunter, Scout, Healer, dan Blacksmith belum tersedia.
- Construction queue serta staged completion dengan Builder belum tersedia.
- Phase 06 baru memiliki faction/archetype foundation; perilaku counterable semua archetype, camps, patrol, raids, counterattacks, dan persistence belum lengkap.
- Phase 08 art/audio identity belum dikirim sebagai satu implementation slice; unit/faction/building visuals masih membutuhkan art pass khusus dan musik belum ada.
- Hotkey UI/job/build belum dapat di-rebind; tooltip bangunan/job dan Windows .ico juga belum tersedia.
- Steam integration opsional dan bukan blocker gameplay.
- Save v12 dan compatibility coverage tersedia di `main` melalui PR #31, tetapi acceptance upgrade pada mesin bersih tetap belum diverifikasi.

## 9. Rencana berikut (belum dikerjakan)
Urutan backlog berdasarkan dependency:
1. Phase 02: selesaikan player-directed shipments/carrier visuals, inspect/withdraw local stock, Outpost garrison dan local visibility. Supply attrition menunggu sampai transfer behavior dan local defense tervalidasi.
2. Phase 04: implementasikan Hunter, Scout, Healer dan Blacksmith dengan workplace, radius, biaya/hasil, UI kuota, pathfinding dan save/load.
3. Phase 05: construction queue dan staged building completion dengan Builder; lanjutkan bangunan sesuai dependency produksi dan strategi.
4. Phase 06: distinct/counterable policy keenam archetype, faction camps, bounded patrols, reinforcement budget, raids/counterattacks dan persistence.
5. Phase 08: biome/faction/unit/building art pass, strategic-map readability, combat/environmental audio dan musik.
6. Phase 07/09/10 acceptance: human campaign playtest, difficulty review, target-hardware profile, native Windows smoke, clean-machine migration, physical-resolution screenshots dan fullscreen test.
7. Polish sekunder: rebind shortcut UI/job/build, tooltip, Windows .ico; Steam tetap opsional.

Dokumen kanonik setiap fase berada di ROADMAP_NEXT_LEVEL.md dan docs/plans/. Automated CI, headless simulation, rendered screenshot, dan human playtest harus dilaporkan sebagai bukti yang berbeda.

## 9b. Tahap lanjutan kampanye wilayah
Pondasi Frontier campaign sekarang sudah tersedia: world 128×128, lima biome, empat stronghold, 11 regional objectives, empat faksi, road-connected supply, dan 20-day/4-act calendar. Karena itu, jangan mengulang roadmap awal berupa peta region transisi atau single-stronghold upgrade.

Batas sistem berikutnya:
- Supply graph menentukan konektivitas; local stockpile dan automatic Keep-bound shipments sekarang memberi saldo depot dan transfer dasar. Ini belum physical carrier simulation/player-directed shipment; attrition tetap ditunda sampai Outpost defense, camps dan raid consequences tersedia.
- Outpost merupakan depot forward, tetapi belum memiliki garrison assignment dan visibility lokal.
- Faction registry sudah menentukan identitas/roster; territorial AI masih harus dibangun dengan batas spawn, radius patrol, cooldown, target selection bounded, path reachability, dan save persistence.
- Construction queue harus menjadi sumber progress pembangunan; jangan langsung menjadikan semua bangunan instant-place jika Builder adalah labor occupation.
- Pertahankan Classic 64×64/15-day dan save compatibility pada setiap fase.

Jangan menambah ukuran map atau streaming runtime sebelum profiling pada hardware nyata menunjukkan kebutuhan.

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


## 19. Next-level kingdom expansion roadmap (2026-11-01)
- Product direction: evolve the existing village-defense/action-combat game into a frontier kingdom strategy campaign while preserving the original 15-day experience as Classic Mode.
- Authoritative plan: `ROADMAP_NEXT_LEVEL.md`. It defines the target 128x128 Frontier world, five terrain biomes, a 15-tile starting Keep claim, regional strongholds, four enemy factions, additional jobs/buildings and a 20-day conquest campaign.
- Phase 00 foundation was merged into `main` through PR #7 (merge commit `2d7d45fae39e5a1f1c2db7c703a87066fe2d874a`). It centralizes world dimensions and profiles, migrates spatial systems, adds save format v7 world identity and introduces Godot 4.3/4.7 CI.
- Phase 00 is verified. The CI matrix confirms both engines import the project, compile all GDScript scripts, and pass the assertion-based tests. `tests/world_config.gd` explicitly covers legacy versions v1–v6 in Classic and rejects them for Frontier.
- Phase 01 is implemented on `feat/frontier-world-generation-mainline` (draft PR #10), directly based on the merged `main`. Full CI run `41287974528` passed all 22 jobs: import/parse plus 10 regression scripts on each of Godot 4.3 and 4.7.
- Frontier offers 128x128 tiles, five deterministic warped biomes (Hearthland, Greenwood, Highlands, Fenlands, Ashen March), an Ashen atlas tile, biome-weighted tree/rock placement, patch noise and 32 clustered iron veins. Keep claim radius is 15 tiles; the home clearing is kept free of resource blockers. Classic generation remains a separate path and Classic stays the default profile.
- The new-campaign panel allows explicit Classic/Frontier selection and persists the choice. World profile is applied before scene reload; saves record profile, dimensions, tile size and seed.
- Save validation separates active-world compatibility from structural validity. Incompatible saves cannot load into the current profile, but structurally valid previous-profile saves remain eligible as rollback backups.
- Frontier stronghold placement uses cardinal reachable-cell traversal; the stronghold is placed adjacent to walkable terrain. The strategic map renders Ashen March, profile-aware labels and viewport-aware scaling.
- The Frontier regression covers five biome shares, terrain indices, resource distribution, iron veins, Keep footprint/claim, fog/save index bounds, selector visibility/persistence, stronghold approach, deterministic layout and compact viewport bounds.
- PR #9 (`feat/regional-control-roads`) contains the next territory/roads/supply slice but is still stacked on the superseded pre-mainline Frontier branch. Rebase it onto the verified Phase 01 line before treating it as the Phase 02 continuation. Do not merge PR #10 or PR #9 without explicit approval.

## 20. Regional control and road-connected supply (2026-11-01)
- Phase 02 branch: `feat/regional-control-roads-mainline`, stacked on the verified Phase 01 branch; draft PR #11.
- Regional ownership aggregates buildable land coverage into neutral/player/enemy/contested states. Region control changes are independent of exploration fog.
- Roads and bridges are one-cell infrastructure. They have no physical collision and remain walkable in villager A* and enemy flow-field routing. Bridge construction is restricted to valid water cells.
- `supply_network.gd` flood-fills cardinal road connections from the Keep footprint and exposes connected road/depot state. Keep, Storage and Outposts are depots; workers ignore disconnected depots and retain cargo if a route breaks before deposit.
- Strategic map renders explored road links and colors region labels by ownership state. HUD exposes road and bridge build choices.
- Phase 02 initial slice CI passed on Godot 4.3 and 4.7: run `41289421611` completed successfully with 24/24 jobs, including `regional_control_roads` on both engines.
- `tests/regional_control_roads.gd` covers Classic's regional states, walkable roads, deterministic bridge placement/traversal, Keep-connected roads and depots, isolated Outposts, rerouting and cargo retention after road removal, plus infrastructure save persistence.
- Historical note for the Phase 02 initial-slice merge: deposits originally credited shared inventory. PR #31 merged the local Storage/Outpost stockpiles and v12 persistence into `main`; explicit inter-depot shipment semantics remain open.
- Outpost guards/garrisons and local visibility are also not implemented. Supply attrition and raid vulnerability remain deferred until local logistics exist.
- PR #11 is the clean Phase 02 transplant based on the Phase 01 branch. PR #9 was the old stacked version on the retired pre-mainline Frontier branch and is closed as superseded.


## 21. Multi-stronghold campaign (2026-11-01)

- Phase 03 implementation branch: `feat/multi-stronghold-campaign`, based on the verified Phase 02 branch.
- New Frontier campaigns create four sequential objectives: Greenwood Raiders, Iron Legion, Fen Cult and Ashen Host.
- Each stronghold has its own reinforcement cap and garrison. Conquering one objective does not retreat guards from other strongholds.
- Later objectives remain damage-locked until the active objective is conquered. Soldiers on expedition automatically retarget the next objective.
- Regional conquest grants resources; the campaign only ends after the fourth stronghold falls.
- Save format v8 persists the full objective order, region/faction identity, health, garrison timers and completion state. Existing v1–v7 saves retain their one-stronghold flow; Classic remains one stronghold.
- Regression status: dedicated multi-stronghold test added to CI; Godot 4.3 and 4.7 execution pending.


## 22. Jobs and workplaces — first Phase 04 slice (2026-11-01)

- Branch: `feat/workplaces-and-specialist-jobs`, stacked on the Phase 03 campaign branch.
- Builder is a labor occupation with Keep/Outpost workplace slots and a workplace-bounded repair radius. It consumes repair material and cannot share a repair target with another Builder.
- Woodcutters, miners and farmers are constrained to connected-depot work radii. Resource carriers select a reachable connected depot rather than failing on the nearest but inaccessible depot.
- Job allocation order is configurable; Alt + job key promotes, Alt + Shift + job key demotes. The job panel also supports right-click priority changes.
- Soldier identity is stored in `military_specialization`; labor tasks are stored in `occupation`. The legacy `job` property remains a compatibility alias.
- Save format v9 persists role fields and ordered priority. Hunter, Scout, Healer and Blacksmith remain later Phase 04 increments.


## 23. Phase 06 — Factions and enemy archetypes (2026-11-01)
- Phase 06 faction foundation merged into `main` through PR #21 after Phase 05 PR #19. Godot 4.3/4.7 CI passed (30/30 jobs); manual gameplay review remains.
- `data/factions.json` defines Greenwood Raiders, Iron Legion, Fen Cult and Ashen Host, mapped to their Frontier regions with faction colors, rosters and signature garrisons.
- `data/enemy_archetypes.json` defines Scout, Shieldbearer, Saboteur, War Shaman, Siege Engine and Beast Rider. Archetypes are loaded into `DataDB.enemies` while legacy enemy definitions remain unchanged.
- Stronghold garrisons are selected from faction rosters; regional wave spawns receive faction identity. Enemy units use faction tint.
- War Shaman has bounded ally healing with a cooldown. Target selection and ally support are extracted into `enemy_targeting.gd` and `enemy_support.gd`.
- Save format v12 records Frontier objective/site progress, enemy faction IDs and local Storage/Outpost stockpiles; Classic v1–v11 and Frontier v7–v11 migrate with empty stockpiles.
- `tests/faction_registry.gd` covers faction-region mapping, roster/garrison membership, faction tint, same-faction War Shaman healing and v12 save validation. Godot 4.3/4.7 CI passed 30/30 jobs.
- Remaining Phase 06 work: fully distinct counterable behavior for all six archetypes, deterministic camps, bounded patrols, raids/counterattacks, camp/raid persistence, stress tests and manual gameplay review. Do not mark Phase 06 complete yet.


## 24. Phase 07 — Frontier Conquest objectives (2026-11-01)
- Integration branch: `feat/phase-07-conquest-objectives-mainline`, created from the current `main` after Phase 05 and Phase 06 were merged. This avoids the old Phase 07 branch's diverged Phase 06 ancestry.
- Technology expands from 17 to 20 nodes: Surveying, Regional Cartography and Siegecraft. Cartography increases Outpost reveal radius; Siegecraft increases player damage against active strongholds and regional sites.
- Classic keeps its 15-day / 3-stage schedule and victory rules. Frontier uses 20 days / 4 acts with faction archetypes joining later wave pools.
- Eleven regional objectives cover four biome discoveries plus camp/ruin clearing, rescue, escort and defense. Press O to inspect progress; E interacts with a nearby site.
- Discovered objective sites appear on the strategic map with type-based markers. Future-act sites remain dimmed/locked until the previous act's required objectives and stronghold are complete.
- Escort paths rebuild from the saved world position after load. Save v12 persists objective/site progress, site health/location, escort progress, final-boss state and local Storage/Outpost stockpiles; v1–v11 remain compatible with empty local stockpiles.
- Frontier victory requires all required regional objectives, all four strongholds and the King encounter on day 20. Classic's original 15-day victory path remains intact.
- Mainline implementation merged through PR #28; Godot 4.3/4.7 workflow #288 passed 30/30 jobs. Rendered/manual difficulty review remains.


## 25. Phase 09 — Balance, performance and release hardening (2026-11-01)
- Merged into `main` through PR #29. Mainline Godot 4.3/4.7 workflow #290 passed 30/30 jobs.
- Adds configurable Classic/Frontier profiling for frame timing, static memory, world nodes, projectiles and particles; results are diagnostic and runner-specific.
- Adds bounded Frontier stress coverage for faction rosters, villagers, projectiles and the 500-particle ceiling.
- Adds deterministic campaign-balance, objective reload and save migration/recovery coverage, including Classic v1–v12 and Frontier v7–v12.
- Release scripts verify non-empty Windows/Linux export outputs; CI installs Godot 4.3 export templates, validates the PE format and smoke-tests Linux headlessly.
- Previous stacked workflow #282 and mainline workflow #290 both passed 30/30 jobs. Windows/Linux template-backed export checks also passed in CI.
- Remaining gates: real target-machine performance profile, later-act/day-20 combat outcome cases, full manual campaign playtest, Windows runtime smoke and clean-machine migration.


## 26. Phase 10 — Resolution-matched viewport and HUD safe area (2026-11-01)
- Merged into `main` through PR #30. Mainline Godot 4.3/4.7 workflow #292 passed 30/30 jobs.
- Root Window logical viewport now follows half the actual client-window dimensions, with a 480×270 minimum and exact 2× pixel scaling. Reference mappings: 960×540 → 480×270; 1280×720 → 640×360; 1366×768 → 683×384; 1600×900 → 800×450; 1920×1080 → 960×540.
- Settings checks the native window size and only updates content scaling when dimensions change. The `content_viewport_resized` signal explicitly reflows HUD and centers the technology panel.
- HUD retains logical-pixel dimensions in edge bands; the central playfield grows with the window. Camera zoom, tile size, movement/combat ranges, world dimensions and save schema remain unchanged.
- Both the prior stacked workflow #285 and mainline workflow #292 passed 30/30 jobs, including responsive viewport and map regressions.
- Rendered screenshots and manual play at physical desktop resolutions/fullscreen remain a separate acceptance gate.


## 27. Phase 02.4 — Outpost garrisons and local depot inspection (2026-11-01)
- Merged to `main` via PR #32 at `2f94959b497677eae49d4303f72322650fb591c2`; CI workflow #41318897606 passed 48/48 jobs.
- Outposts now define two guard slots. The HUD exposes `JOBS → POS`, with read-only local stock balances for Storage/Outposts and per-Outpost assign/release controls.
- The nearest reachable unassigned soldier can be assigned. Guards stay attached to their post, ignore enemies outside a 128-pixel radius around it, return after combat, and are excluded from global conquest expeditions. Death, job reassignment, demolition and destruction release slots.
- Save v12 remains unchanged: an optional `guard_outpost` cell reference is written for assigned soldiers. Validation checks that the referenced Outpost exists, the soldier is not simultaneously expeditioning/recalling, and the post capacity is not exceeded. Older v12 files without this optional field remain valid.
- Outpost local vision and observed-only strategic-map enemy markers were already implemented in `main`; the roadmap now reflects that instead of listing them as missing.
- Regression suite: `tests/outpost_garrisons.gd` covers slot limits, death/reassignment, local combat radius, vision, panel presence, demolition release, and save compatibility/round-trip. It runs in the blocking test runner and passed on Godot 4.3 and 4.7.


## 28. Phase 02.3 — Player-directed physical shipments (2026-11-01)
- Merged to `main` via PR #33 at `5d7db56b3a51a25541f541bb46c19b26996d22be`; CI workflow #41323062111 passed 50/50 jobs on Godot 4.3 and 4.7.
- The `JOBS → POS` panel now includes source/destination selectors for Keep, Storage and Outposts, a resource/amount selector, order history/status and cancel controls.
- Creating an order immediately reserves the exact cargo at the source (Keep Inventory or local depot stock) and reserves capacity at remote destinations. Each active order owns its escrowed cargo; it is not counted twice in either inventory.
- Visible courier entities walk along the navigation grid. On route disconnection, an order becomes blocked with its cargo and last carrier position preserved; it resumes when the route returns. Delivery credits local depot stock or Keep Inventory. Keep-bound deliveries support explicit local-stock withdrawals.
- Active orders can be cancelled/refunded. If a depot disappears or cannot accept recovered stock, cargo is returned to Keep Inventory. Direct build/research spending from remote depots remains separate and is not implemented.
- Save schema moves from v12 to v13: pending/history shipment records, reserved cargo and carrier position persist. Save v1–v12 remain compatible and load with an empty shipment ledger. Validator checks unique order IDs, resource kinds, amounts, statuses, cargo escrow, map cells and remote destination capacity reservations.
- New regression: `tests/physical_shipments.gd` covers physical delivery, Keep withdrawal, cancellation/refund, capacity rejection, route interruption, save/load resume and invalid-cargo rejection. It runs in both Godot matrices and passed on Godot 4.3 and 4.7.


## 29. Phase 02.2 — Explicit depot-funded costs (2026-11-01, implementation pending CI)
- Branch: `feat/phase-02-depot-cost-sources`, based on main `6cde7b9020e98f267a0bfbe0499f1d1954e02c5c`.
- A single source selector in `JOBS → POS` controls construction, technology research and building repair. It lists Keep, Storage and Outposts.
- Frontier costs are paid entirely from the selected depot. Remote depots must be connected to the Keep. Partial balances from different depots are never combined; no source switching or implicit transfer occurs during payment. Classic continues using central Keep Inventory.
- Remote multi-resource payment preflights the full cost before debiting and rolls back if a source withdrawal unexpectedly fails.
- Destroying/removing the selected remote depot resets the selected source to Keep. A disconnected depot remains selected but cannot fund costs until its route returns.
- The selected depot cell is an optional field inside save-v13 `supply` state. Older v13 saves without this field remain valid; no save version bump is required.
- `tests/depot_cost_sources.gd` covers source selection, construction, research, no cross-depot pooling, atomic payment failure, disconnection rejection, UI selector presence and save/reload compatibility. It is added to both the blocking runner and Godot 4.3/4.7 CI matrix.
- PR and CI validation have not yet completed. The CI target is 24 assertion suites per engine / 52 total jobs; do not treat the feature as merged until every check passes.
