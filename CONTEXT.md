# Konteks proyek: Hold the Keep

Dokumen ini ringkasan keadaan proyek supaya sesi kerja berikutnya (manusia atau AI) bisa langsung
melanjutkan tanpa membaca ulang seluruh riwayat. **Perbarui bagian "Status" dan "Riwayat" setiap
selesai satu paket pekerjaan.** README.md = panduan pemain/pengembang singkat; file ini = konteks.

## 1. Ringkasan

**Current source of truth:** `main` contains PRs #55–#63 through Frontier Expedition and remains at save schema v13. The active engine target is Godot 4.7 only. Development CI runs 4.7 import/parse, regression suites and Frontier/Expedition performance diagnostics; Windows/Linux exports are deferred until release. Hunter PR #64 passed 45/45 jobs (#620); Scout PR #65 passed 46/46 jobs (#621); Healer PR #67 passed 47/47 jobs on its latest head (#626). Blacksmith PR #68 is being implemented above Healer with save schema v17.

**Active implementation branches:** PR #64 (`feat/hunter-hunting-lodge`) adds Hunter, renewable wildlife and the two-slot Hunting Lodge; CI #620 passed 45/45. PR #65 (`feat/scout-specialist`) adds the two-slot Scout Post and bounded A* exploration; CI #621 passed 46/46. PR #67 (`feat/healer-infirmary`) adds Field Medicine, the two-slot Infirmary and reserved treatment; latest CI #626 passed 47/47. PR #68 (`feat/blacksmith-forge`) adds two Forge Blacksmith slots, individual soldier weapon/armor upgrades and save v17; it is stacked after Healer. All PRs remain open pending integration and in-game acceptance.

**Merged into `main`:** PR #63 (`a594069`) adds the optional 192×192 Frontier Expedition profile. It preserves Classic 64×64 and standard Frontier 128×128, begins in a 128×128 connected heartland, and opens each of four outer marches only after the player reaches its survey crossing. Four strongholds, seven regional objective sites and four faction camps are placed in their sealed outer marches; permanent fog reveals them as they are explored. Crossing state is derived from existing discovery objectives; save schema remains v13. PR workflow #41580977570 passed 88/88 jobs across Godot 4.3/4.7, both performance diagnostics, and Windows/Linux export checks. Main push workflow #41581523207 was pending at the time of this update. PR #63 is merged; Frontier Expedition is part of `main`.
- Game 2D top-down **village defense + light management** bertema medieval. Solo dev, semi-lightweight.
- **Native desktop, bukan web** (keputusan eksplisit pemilik). Godot 4 + GDScript, renderer GL Compatibility.
- Versi aktif: **Godot 4.7**. Godot 4.3 is not an active compatibility target or CI gate.
- Jendela default 1280×720, minimum 960×540. Viewport logis mengikuti setengah ukuran client window (minimum 480×270), pixel art integer-scale tepat 2×.
- Tujuan pemain: bertahan 15 hari, di malam ke-15 kalahkan Raja Lawan. Keep hancur = kalah.
- Loop: siang (kumpul, bangun, atur villager) -> malam (gelombang musuh) -> fajar (event acak, autosave).

## 2. Status fitur
Ringkasan implementasi aktual pada `main` setelah PR #62 (save schema v13; status per 3 November 2026). PR #62 (`4cc0420`) menggabungkan scripted combat-budget probe Phase 09.2 ke `main`; workflow #41564491766 lulus 86/86 jobs pada Godot 4.3/4.7. Perilaku Shieldbearer/Scout/Saboteur/Siege Engine/Beast Rider, faction camps/patrols/raids, combined warfare stress, Phase 08.3–08.7 visual/audio identity, dan Phase 09.3 late-act save/reload acceptance sudah tercakup. PR #57 menambah regression test end-to-end untuk Act I–IV, sebelas objective, empat stronghold, gate King hari ke-20 dan persistensi victory setelah reload; gameplay dan save schema tidak berubah.

| Area | Kondisi saat ini |
|---|---|
| Dunia | Classic 64×64 / 15 hari tetap tersedia; Frontier 128×128 / 20 hari / 4 act dengan lima biome deterministik, 32 urat besi, dan starting Keep claim radius 15 |
| Wilayah | Regional ownership neutral/player/enemy/contested; roads/bridges walkable; supply graph dari Keep; depot terputus tidak menerima deposit |
| Logistik | **Parsial:** Storage 180 dan Outpost 120 unit memiliki local stockpile; worker deposits, bounded automatic Keep transfers, player-directed physical shipments, cargo escrow dan route recovery tersedia. Explicit Keep/Storage/Outpost cost source for construction/research/repair is merged; deterministic contested-depot warning and targeted Saboteur raids merged through PR #35 |
| Kampanye | Classic satu stronghold; Frontier empat stronghold berurutan, garrison/reinforcement lokal, 11 objective regional, fog dan save/reload; Act I–IV + victory reload dilindungi `campaign_reload_hardening.gd` |
| Pemain | Gerak 8 arah, lari, serang, panen, HP/regen, respawn di Keep; XP dan Dash/Cleave/Rally |
| Bangunan | Keep, rumah, tembok, menara pengawas (turret + 128px vision), Lumbung 240 pangan, Gudang, ladang, tembok batu, tempa, Outpost, Lumber Camp, Quarry, road dan bridge pada `main`; PR #64 branch menambah Pondok Pemburu; `feat/scout-specialist` menambah Pondok Pengintai. |
| Villager | On `main`: woodcutter, miner, farmer, soldier and Builder. Hunter (#64), Scout (#65), Healer (#67) and Blacksmith (#68) are implemented on open stacked branches. |
| Faksi/musuh | Empat faction registry dan enam archetype definitions; War Shaman, Shieldbearer, Scout, Saboteur, Siege Engine dan Beast Rider charge behaviors merged; four destructible Frontier faction camps, bounded A* patrols and finite reinforcement budgets merged via PR #43; connected infrastructure raids and bounded counterattacks merged via PR #44; manual Frontier balance/play review remains open |
| Ekonomi | Kayu, batu, makanan, iron; kapasitas rumah dan upkeep; local depot economy dan trade belum tersedia |
| Teknologi | 21 technologies in three eras; Field Medicine unlocks Infirmary, while existing Iron Weapons/Armor research gates individual Blacksmith recipes on PR #68 |
| Save/load | v13 pada `main`; stacked branches add v14 Hunter, v15 Scout, v16 Healer and v17 Blacksmith/equipment. Legacy Classic v1–v16 and Frontier v7–v16 remain migration targets. |
| Kontrol | Rebind gerak, interaksi, serang, lari; shortcut UI/job/build belum dapat di-rebind |
| Tampilan | Adaptive logical viewport = setengah ukuran client window, minimum 480×270, pixel scale tepat 2×; physical-display/fullscreen review belum dilakukan |
| HUD | Top bar, vitals, stage, combat strip, JOBS drawer, strategic map with live tower sight, hotbar, objective tracker, tech panel, pause menu |
| Audio | 10 procedural ambience loops (5 biome × siang/malam), 2 original music loops, 14 event cues; Master bus routing dan crossfade; human listening/level-balance QA masih terbuka |
| Rilis | Export scripts/presets are retained; automatic Windows/Linux package checks are deferred until release phase |
| CI | Active gate: Godot 4.7 import/parse, 45 regression suites and two Frontier performance diagnostics; no Godot 4.3 or release-export jobs |

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
scripts/entities/      player, enemy, enemy_keep (stronghold/garrison source), villager (expedition/recall), building, resource_tree, rock, iron_ore, wildlife_node, arrow, corpse,
                       fx_layer, sprite_anim
scripts/ui/            hud.gd (layout viewport-aware), world_map_panel.gd, tech_panel.gd, pause_menu.gd (window-size presets), pixel_font.gd
data/                  buildings.json, enemies.json, waves.json, events.json, techs.json
assets/sprites/        40 SVG pixel-art (dibuat oleh tools/gen_assets.py)
assets/fonts/          Silkscreen (OFL) + lisensinya
tools/                 gen_assets.py (generator SVG), build.sh, build.ps1
tests/                 skrip tes headless dan screenshot (lihat tests/README.md)
```
Grup node yang dipakai lintas skrip: `main`, `hud`, `player`, `village`, `buildings`, `depots`, `farms`,
`harvestable`, `resource_nodes`, `wildlife`, `enemies`, `ranged_enemies`, `enemy_projectiles`, `enemy_garrison`, `enemy_strongholds`, `villagers`, `defenders`, `fog_of_war`.

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
- Hunter (#64), Scout (#65), Healer/Infirmary (#67) and Blacksmith/Forge (#68) are implemented on stacked PR branches; manual rendered-play acceptance remains open.
- Construction queue serta staged completion dengan Builder belum tersedia.
- Phase 06 baru memiliki faction/archetype foundation; perilaku counterable semua archetype, camps, patrol, raids, counterattacks, dan persistence belum lengkap.
- Phase 08 art/audio identity belum dikirim sebagai satu implementation slice; unit/faction/building visuals masih membutuhkan art pass khusus dan musik belum ada.
- Hotkey UI/job/build belum dapat di-rebind; tooltip bangunan/job dan Windows .ico juga belum tersedia.
- Steam integration opsional dan bukan blocker gameplay.
- Save v12 dan compatibility coverage tersedia di `main` melalui PR #31, tetapi acceptance upgrade pada mesin bersih tetap belum diverifikasi.

## 9. Rencana berikut
Urutan backlog berdasarkan dependency:
1. Phase 02: selesaikan player-directed shipments/carrier visuals, inspect/withdraw local stock, Outpost garrison dan local visibility. Supply attrition menunggu sampai transfer behavior dan local defense tervalidasi.
2. Phase 04: integrate Hunter (#64) → Scout (#65) → Healer/Infirmary (#67) → Blacksmith/Forge (#68) after branch CI and manual play acceptance.
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

## 9c. Phase 05.2a — Builder-driven construction sites (2026-11-02, merged via PR #58)
- Branch `feat/phase-05-builder-construction-sites` was squash-merged into `main` as `d3bba66` after workflow #41484825656 passed.
- A valid placement pays the selected depot once and creates an unfinished blueprint; it is not registered as a functional building until Builder work completes.
- Builders use their existing workplace assignment and bounded navigation to claim reachable blueprint sites. Maximum two Builders per site; additional work rate is capped at 1.65× one Builder.
- Completion replaces the blueprint with the normal building. Right-click cancellation returns only unconsumed materials to the original depot, with Keep fallback if the source cannot accept them.
- Save v13 receives an optional `construction_sites` array; older saves remain valid. Site progress, required work and source coordinates are validated and restored.
- Automated acceptance passed on Godot 4.3/4.7, including construction-site regression, Frontier diagnostic and Windows/Linux exports. Queue ordering/reorder UI moved to Phase 05.2b.

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
- Active orders can be cancelled/refunded. If a depot disappears or cannot accept recovered stock, cargo is returned to Keep Inventory. Direct build/research/repair spending from the selected remote depot was added through PR #34; see section 29.
- Save schema moves from v12 to v13: pending/history shipment records, reserved cargo and carrier position persist. Save v1–v12 remain compatible and load with an empty shipment ledger. Validator checks unique order IDs, resource kinds, amounts, statuses, cargo escrow, map cells and remote destination capacity reservations.
- New regression: `tests/physical_shipments.gd` covers physical delivery, Keep withdrawal, cancellation/refund, capacity rejection, route interruption, save/load resume and invalid-cargo rejection. It runs in both Godot matrices and passed on Godot 4.3 and 4.7.


## 29. Phase 02.2 — Explicit depot-funded costs (2026-11-01, merged)
- Merged into `main` via PR #34 at `67be2de`; workflow #41325205416 passed 52/52 jobs.
- Implementation branch was based on main `6cde7b9020e98f267a0bfbe0499f1d1954e02c5c`.
- A single source selector in `JOBS → POS` controls construction, technology research and building repair. It lists Keep, Storage and Outposts.
- Frontier costs are paid entirely from the selected depot. Remote depots must be connected to the Keep. Partial balances from different depots are never combined; no source switching or implicit transfer occurs during payment. Classic continues using central Keep Inventory.
- Remote multi-resource payment preflights the full cost before debiting and rolls back if a source withdrawal unexpectedly fails.
- Destroying/removing the selected remote depot resets the selected source to Keep. A disconnected depot remains selected but cannot fund costs until its route returns.
- The selected depot cell is an optional field inside save-v13 `supply` state. Older v13 saves without this field remain valid; no save version bump is required.
- `tests/depot_cost_sources.gd` covers source selection, construction, research, no cross-depot pooling, atomic payment failure, disconnection rejection, UI selector presence and save/reload compatibility. It is added to both the blocking runner and Godot 4.3/4.7 CI matrix.
- Validation is complete: 24 assertion suites passed on each Godot 4.3 and 4.7, both import/parse jobs passed, and Frontier performance plus Windows/Linux export passed (52/52 total).


## 30. Phase 02.5 — Contested depot supply pressure (2026-11-01, implementation pending CI)
- Branch: `feat/phase-02-supply-pressure`, based on main `185d75167992664ff3dd922084cc55a8be7db046`.
- Only disconnected remote Storage/Outpost depots under enemy/contested territorial control accrue pressure. An isolated depot under neutral/player control remains stock-safe.
- Warning is emitted at 30 seconds. The first targeted Saboteur dispatches at 60 seconds; a second can spawn at 210 seconds. Maximum two raids per continuous isolation.
- Saboteurs path to the selected depot with nav-grid paths, engage the player/local defenders before attacking the depot, damage its structure, and steal one resource every second successful depot hit in fixed priority (food, iron, wood, stone).
- Reconnecting to the Keep or reclaiming territory resets pressure and recalls active saboteurs. UI exposes TERPUTUS / TERPENCIL / ANCAMAN RAID / DIGEMPUR states on JOBS → POS.
- Save v13 gains optional pressure records and active saboteur target/hit-progress fields. Validator checks bounded pressure records, unique depot coordinates, valid cells, raid counts, and valid Storage/Outpost targets. Older v13 saves without these fields remain supported.
- `tests/supply_pressure.gd` is added to the blocking runner and both Godot CI matrices. Coverage: warning lead time, targeted spawn, fixed theft order, bounded repeat raid timing, UI state, save validation/load and recovery. CI has not completed; manual render/gameplay review is still required.


## 31. Phase 02.5 — Contested depot supply pressure (2026-11-01)
- Merged into `main` via PR #35 at `2ba5628`; workflow #41328005585 passed 54/54 jobs, including 25 assertion suites per Godot version, import/parse, Frontier performance diagnostic and Windows/Linux export.
- Frontier-only pressure targets disconnected Storage/Outposts under enemy/contested control; warnings precede targeted Saboteur dispatch, raids are capped at two per isolation, and reconnection/reclaim recalls attackers.
- Save v13 optionally preserves pressure timers and active Saboteur raid state. Manual rendered gameplay review remains open.

## 32. Phase 06.2 — Shieldbearer directional brace (2026-11-02, merged via PR #36)
- Branch: `feat/phase-06-shieldbearer-brace`, based on main after PR #35.
- Shieldbearer now uses a data-defined telegraphed brace, locks a facing direction during its active window, and mitigates frontal damage while leaving side/rear attacks more effective.
- Player attacks, Dash, Cleave and tower arrows pass their source position. Stagger interrupts the brace; target disengagement cancels an unfinished wind-up.
- New regression `tests/shieldbearer_behavior.gd` covers telegraph, facing, frontal mitigation, flank/rear damage, stagger interruption and disengage recovery. The available workflow result page showed the Shieldbearer regression successful; remaining matrix jobs were not independently exposed in that snapshot. No save-schema migration was needed.


## 33. Phase 06.2 — Scout scouting and faction focus (2026-11-02, merged via PR #39)
- Merged into `main` at `11f3f13`; workflow #41354720293 passed 58/58 jobs on Godot 4.3/4.7.
- Scout is no longer a fast pouncing melee unit. It maintains a data-defined safe range, telegraphs a target callout, then marks one visible player/soldier target for a finite duration.
- The mark is shared only with same-faction enemies within a bounded radius. Nearby allies prioritize the marked target; normal nearest-target behavior resumes at expiry.
- Stagger or target disengagement cancels an unfinished callout. Mark state is transient and does not alter save v13.
- Regression `tests/scout_marking.gd` covers telegraph, faction-only propagation, melee/ranged focus priority, mark expiry, stagger interruption and target disengage. Passed on both Godot versions. Save schema v13 remains unchanged.


## 34. Phase 06.2 — Scout faction-aware marking (2026-11-02, merged via PR #39)
- Merged into `main` at `11f3f13`; workflow #41354720293 completed with 58/58 successful jobs.
- Scout uses a ranged scouting posture, telegraphs a finite target mark and shares it only with same-faction enemies inside a bounded radius.
- Nearby melee, ranged, Shieldbearer and garrison enemies prioritize the marked defender while respecting range/leash limits. Marks expire naturally; stagger or target disengagement cancels an unfinished callout.
- `tests/scout_marking.gd` passes on Godot 4.3 and 4.7. Save schema v13 remains unchanged.


## 35. Phase 06.2 — Saboteur building disruption (2026-11-02, merged via PR #40)
- Merged into `main` at `8f1a914`; workflow #41355982522 passed 60/60 jobs on Godot 4.3/4.7.
- Saboteur scans a bounded set of reachable player buildings, scoring Tower/Outpost highest, then Storage, production facilities and House with path-distance weighting.
- It follows nav-adjacent paths, telegraphs a wind-up and applies reversible temporary suppression plus bounded structural damage and a cooldown. Stagger interrupts the wind-up.
- Sabotaged Towers stop firing; Storage/Outposts reject deposits and withdrawals; workplaces stop accepting new workers and pause active workers; repair and Outpost guard assignment are blocked until recovery.
- No save-schema change: sabotage timer is transient and uses simulation delta, pausing with the game. Regression `tests/saboteur_disruption.gd` covers target priority, pathing, disable/recovery and stagger interruption. All 28 assertion suites passed on both Godot versions; Frontier performance and Windows/Linux exports also passed.


## 36. Phase 06.2 — Saboteur building disruption (2026-11-02, merged via PR #40)
- Merged into `main` at `8f1a914`; workflow #41355982522 completed successfully with 60/60 jobs.
- Saboteur performs a rotating bounded scan of up to 32 buildings, prioritizing Tower/Outpost, then Storage, production facilities and House; path length adjusts target score.
- Nav-adjacent paths lead the unit to a target. A visible wind-up precedes temporary disruption and bounded structural damage. Player/defender interception and stagger can interrupt; a cooldown limits repeated attacks.
- Sabotaged Towers stop firing; Storage/Outposts reject deposits and withdrawals; workplaces stop new assignments and pause their workers; repairs and Outpost guard assignment are temporarily blocked.
- Disruption uses a transient simulation timer; save schema v13 remains unchanged. Regression passed on Godot 4.3 and 4.7.


## 37. Phase 06.2 — Siege Engine telegraphed siege cycle (2026-11-02, merged via PR #41)
- Branch: `feat/phase-06-siege-engine-cycle`, based on main after PR #40.
- Merged into `main` at `58da7be`; workflow #41356689758 passed 62/62 jobs on Godot 4.3/4.7.
- Siege Engine scans a bounded rotating set of reachable buildings. Stone walls and wooden walls take priority, followed by Tower, Outpost, Keep and Storage; path distance influences target selection.
- It moves to an adjacent attack position, holds a long visible wind-up, then applies heavy structure-only damage and enters a recovery cooldown.
- Nearby player/defender pressure interrupts the wind-up and makes the unit reposition; stagger cancels the impact. It does not use its heavy strike on player/defender targets.
- Siege state is transient and does not alter save v13. Regression `tests/siege_engine_behavior.gd` covers target priority, nav pathing, wind-up/impact timing, cooldown and stagger interruption. Passed on Godot 4.3 and 4.7.


## 38. Phase 06.2 — Siege Engine structural siege cycle (2026-11-02, merged via PR #41)
- Merged into `main` at `58da7be`; workflow #41356689758 completed with 62/62 successful jobs.
- Siege Engine performs a bounded rotating scan of up to 32 structures, prioritizing stone/wood walls, Tower, Outpost, Keep and Storage, with path distance in the target score.
- It follows adjacent navigation paths and advances through flow-field cells when no target is in scan range. A visible long wind-up precedes heavy structure-only damage and recovery cooldown.
- Nearby player/defender pressure interrupts and repositions the unit; stagger cancels an active siege wind-up. No heavy siege strike is applied to player/defender targets.
- Regression `tests/siege_engine_behavior.gd` passes on Godot 4.3 and 4.7. State is transient; save schema v13 remains unchanged.


## 39. Phase 06.2 — Beast Rider telegraphed charge (2026-11-02, merged via PR #42)
- Branch: `feat/phase-06-beast-rider-charge`, based on main `666b9fc`; squash merge `e6cf221`.
- Beast Rider scores visible player/defender candidates in a bounded scan, preferring isolated soldiers. It approaches with A*, telegraphs for 0.82 seconds and locks a walkable route to the defender's current tile.
- The target can sidestep out of the route; the charge does not steer mid-run. A nav-grid version change or stagger cancels the charge. A successful impact deals one data-tuned hit, applies a short push and enters recovery.
- New regression: `tests/beast_rider_charge.gd`. Added to `tools/run_tests.sh` and both Godot CI matrices. PR #42 workflow #41366304675 passed 64/64 jobs. Save schema v13 unchanged.


## 40. Phase 06.3 — Faction camps and bounded patrols (2026-11-02, implementation branch)
- Branch: `feat/phase-06-faction-camps-patrols`, based on main `8a5c6e5` after PR #42.
- Four deterministic Frontier camps are placed on reachable, empty enemy-owned cells near their regional strongholds. Camps remain hidden until fog reveal, then become inspectable/destructible player targets and receive observed-only strategic-map markers.
- Each faction defines a patrol archetype, radius, initial count, active cap, finite reinforcement budget and cooldown. Patrol movement uses A* and validates every in-leash route cell against faction region and enemy territory.
- Patrols stop pursuing targets and return when they exceed their leash. Losing enemy control suppresses the camp and recalls its patrols; destroying the camp exhausts its budget and ends reinforcement permanently.
- Camp HP/destruction, activation/suppression, budget/timer/spawn index and patrol assignment are optional save-v13 state. No save schema bump; legacy v13 data without camp records remains valid.
- Regression `tests/faction_camps_patrols.gd` is registered on Godot 4.3 and 4.7. PR/CI pending.


## 41. Phase 06.3 — Faction camps and bounded patrols (2026-11-02, merged via PR #43)
- Squash merge: `fa3a45a`; branch `feat/phase-06-faction-camps-patrols`, based on main `8a5c6e5` after PR #42.
- Four deterministic Frontier faction camps are placed on reachable, unoccupied enemy-owned cells near their regional strongholds. Camps remain hidden until fog reveal, then appear as strategic-map markers and destructible player targets.
- Each faction defines its patrol archetype, radius, initial count, active cap, finite reinforcement budget and cooldown. Patrols use A* paths constrained to faction region, enemy territory and camp leash; they stop pursuit and return after leash breach.
- Territorial loss suppresses camps and recalls patrols. Destruction permanently disables reinforcement and recalls linked patrols.
- Camp HP/destruction/discovery/suppression and patrol waypoint/return assignments persist as optional v13 fields; no schema bump and legacy v13 saves remain valid.
- Regression `tests/faction_camps_patrols.gd` passed on both Godot 4.3 and 4.7. Workflow #41377840888 completed successfully with 66/66 jobs, including 31 regression suites per engine, import/parse, Frontier performance diagnostic and Windows/Linux export.

## 42. Phase 06.4 — Faction infrastructure raids (2026-11-02, implementation branch)
- Branch: `feat/phase-06.4-faction-raids`, created from current `main` after PR #43.
- Faction camps dispatch finite raiding parties against exposed, connected infrastructure in their own region. Candidate priority is Outpost, Storage, bridge, then road; candidates are bounded to 48 scanned nodes and eight A* path checks, roads rotate through the group with a scan cursor, and a global four-raider ceiling prevents unbounded spawning.
- Faction-native raid units: Greenwood bandit, Iron Legion archer, Fen Cult wolf and Ashen Host brute. Each camp gets a finite two-raid budget, faction-specific cooldown (88–112 seconds) and configured active cap.
- Raiders retain an explicit depot/road target, attack the player or visible defenders when intercepted, then damage the target through the standard building API. Every second successful depot hit steals one unit in the existing fixed resource priority.
- A target is revalidated while the raider moves and attacks. Reconnection, reclamation, region mismatch, destruction, removal or loss of A* reachability aborts the raid. Camp destruction and loss of camp territory recall its active raiders.
- Save v13 optionally stores camp raid budget/cooldown and active faction-raider target kind/cell, camp, region and hit count. The existing disconnected-depot supply-pressure mechanic remains independent.
- Added `tests/faction_raids.gd` and registered it in `tools/run_tests.sh` plus both Godot 4.3/4.7 CI matrices. PR/CI and rendered Frontier playtest are pending.

## 43. Phase 06.5 — Combined faction warfare stress (2026-11-02, merged; correction verified, awaiting merge)
- Phase 06.4 is merged via PR #44 (`5cc5084`); workflow #41381487306 passed 68/68 jobs, including `faction_raids` on Godot 4.3 and 4.7, Frontier performance and Windows/Linux exports.
- The combined stress workload was merged through PR #45 (`83dd633`) from `feat/phase-06.5-faction-warfare-stress`.
- Regression `tests/faction_warfare_stress.gd` builds a deterministic Frontier workload: 48 faction garrisons, eight camp patrols, four simultaneous faction infrastructure raids (one per faction), and 48 villagers.
- The test creates exposed road targets inside each faction region, validates A* routes for all simultaneous raiders, asserts the global four-raider ceiling, and checks population plus camp/raid state against save-v13 validation.
- Registered in `tools/run_tests.sh` and both Godot 4.3/4.7 CI matrices. The first post-merge run #41384940850 failed at GDScript parsing on line 214 because a literal escaped newline was committed; PR #46 replaces it with a real line break. Corrected workflow #41385244114 passed 70/70 jobs, including `faction_warfare_stress` on both engines; PR #46 remains open and unmerged.
- `tests/release_hardening.gd` validates Classic save fixtures v1–v13 and Frontier fixtures v7–v13; active faction raid state round-trip is separately covered by `tests/faction_raids.gd`.

## 44. Phase 06.2 — Beast Rider composable behavior extraction (2026-11-02, implementation branch)
- Branch: `feat/phase-06.2-composable-behaviors`, based on the corrected Phase 06.5 verification head from PR #46.
- Extracted the Beast Rider target scan/scoring, A* approach and locked charge route, telegraph/wind-up, impact/knockback, miss handling, cooldown and stagger interruption into `scripts/behaviors/beast_rider_behavior.gd`.
- `scripts/entities/enemy.gd` now owns the shared enemy host and delegates Beast Rider lifecycle/timers/rendering to the component. The charge regression now reads/asserts component state directly.
- PR #47 workflow [#41386046423](https://github.com/shimleabyte/hold-the-keep/actions/runs/41386046423) passed 70/70 jobs: Godot 4.3/4.7 parse, all 33 assertion suites per version (including `beast_rider_charge` and `faction_warfare_stress`), Frontier performance and Windows/Linux export. PR #47 remains open and unmerged.

## 45. Phase 06.2 — Shieldbearer composable brace extraction (2026-11-02, implementation branch)
- Added `scripts/behaviors/shieldbearer_behavior.gd` for brace targeting response, wind-up/active timing, cooldown, disengage cancellation, stagger interruption, directional hit checks and telegraph drawing.
- `scripts/entities/enemy.gd` delegates Shieldbearer brace updates, cooldown advancement, damage mitigation and rendering to the behavior component; archetype-specific brace fields and the old inline state machine were removed from the host.
- `tests/shieldbearer_behavior.gd` now inspects the component state and directly verifies the damage-origin gate while retaining front/side/rear damage, stagger and disengage cases.
- Workflow [#41387134030](https://github.com/shimleabyte/hold-the-keep/actions/runs/41387134030) passed 70/70 jobs: both engine parse checks, all assertion suites on Godot 4.3/4.7 including `shieldbearer_behavior`, `beast_rider_charge` and `faction_warfare_stress`, Frontier performance and Windows/Linux export. PR #47 remains open and unmerged.

## 46. Phase 06.2 — Scout composable marking extraction (2026-11-02, implementation branch)
- Added `scripts/behaviors/scout_behavior.gd` for bounded defender selection, preferred-range positioning, telegraphed marking, bounded same-faction propagation, expiry, stagger interruption, target disengagement and marker rendering.
- `scripts/entities/enemy.gd` now delegates Scout state/timers/mark publication to this component. Thin host adapters remain so Shieldbearer, ranged enemies and garrisons can consume valid shared marks without depending on Scout internals.
- `tests/scout_marking.gd` now asserts component state directly while retaining same-faction sharing, rival-faction exclusion, marked-target priority, expiry, stagger interruption and target disengagement.
- Latest-head workflow [#41387833455](https://github.com/shimleabyte/hold-the-keep/actions/runs/41387833455) passed 70/70 jobs on Godot 4.3/4.7, including both Scout regressions, both Shieldbearer regressions, Beast Rider, faction raids and combined warfare stress. PR #47 remains open and unmerged.

## 47. Phase 06.2 — Saboteur composable disruption extraction (2026-11-02, implementation branch)
- Added `scripts/behaviors/saboteur_behavior.gd` for bounded priority scoring, rotating building scan, reachable A* path selection, interception, wind-up, suppression/damage application, cooldown, stagger interruption and disruption telegraph.
- `scripts/entities/enemy.gd` now delegates Saboteur navigation, target/path state, timers, impact/recovery and drawing to the component. The host retains only the archetype dispatch hook.
- `tests/saboteur_disruption.gd` now asserts through component state while retaining building priority, reachability, suppression, recovery, interception and stagger coverage.
- Workflow [#41388532624](https://github.com/shimleabyte/hold-the-keep/actions/runs/41388532624) passed 70/70 jobs on Godot 4.3/4.7.

## 48. Phase 06.2 — Siege Engine composable structural attack extraction (2026-11-02, implementation branch)
- Added `scripts/behaviors/siege_engine_behavior.gd` for bounded building-priority scanning, A* adjacent pathing, flow-field advance, defender interruption/retreat, telegraphed structural impact, recovery and marker rendering.
- `scripts/entities/enemy.gd` delegates Siege Engine navigation, target/path state, timers, attack cycle, retreat and telegraph rendering to the component; the shared host retains only the archetype dispatch hook.
- `tests/siege_engine_behavior.gd` now asserts through component state while retaining priority, reachable route, impact damage, cooldown, stagger interruption and building-only attack checks.
- Latest workflow [#41389136213](https://github.com/shimleabyte/hold-the-keep/actions/runs/41389136213) passed 70/70 jobs on Godot 4.3/4.7. PR #47 remains open and unmerged.

## 49. Phase 06.2 — War Shaman support component extraction (2026-11-02, implementation branch)
- Added `scripts/behaviors/war_shaman_support_behavior.gd` to own support radius/amount, heal cooldown and the decision to heal the nearest injured same-faction ally through the shared `enemy_support.gd` targeting helper.
- `scripts/entities/enemy.gd` delegates support timer advancement and the support tick to this component. The War Shaman's ranged attack remains on the shared ranged combat path; support is evaluated as a separate priority action and does not duplicate or replace projectile logic.
- `tests/faction_registry.gd` now inspects the component directly and verifies allied healing, rival-faction exclusion and no repeated healing during cooldown.
- Latest workflow [#41389866198](https://github.com/shimleabyte/hold-the-keep/actions/runs/41389866198) passed 70/70 jobs on Godot 4.3/4.7, including `faction_registry`, all behavior regressions, faction raids and warfare stress, Frontier performance and Windows/Linux export. The War Shaman support component is validated; PR #47 remains open and unmerged.


## Riwayat terbaru
- 2026-11-02: PR #47 merged (`b06c355`), extracting archetype-specific behavior into six dedicated components; latest workflow #41394905158 passed 70/70 jobs on Godot 4.3/4.7.
- 2026-11-02: Started Phase 08 on `feat/phase-08-visual-audio-identity-mainline`. Added `assets/sprites/tiles_frontier.svg`, a weathered seven-cell Frontier terrain atlas. `world_map.gd` selects it only for Frontier; Classic keeps `tiles.svg`. Extended `frontier_world.gd` to assert the atlas resource and dimensions. Phase plan and roadmap updated; rendered screenshot review and further environment/faction/audio work remain pending.


## Phase 08.3 — Frontier biome dressing (2026-11-02)
- PR #48 merged the seven-cell weathered Frontier terrain atlas into main at `9a2a849`; CI run #41395636707 passed 70/70 jobs on Godot 4.3/4.7.
- Current implementation branch: `feat/phase-08.3-frontier-biome-props`.
- Added deterministic non-blocking regional props and five biome landmarks through `scripts/entities/frontier_decoration.gd`; decoration placement is separate from terrain/resource RNG and avoids occupied cells.
- Extended `tests/frontier_world.gd` for deterministic decoration layout, no resource overlap and one landmark per biome. CI and rendered screenshot review are pending.


## Phase 08.3 — Frontier biome dressing (2026-11-02)
- The regional decoration pass includes fern clusters, reeds, dead pines, standing stones, ash pillars and five biome landmarks. Placement is deterministic, non-colliding, independent of resource RNG and avoids resource cells.
- Hearthland dressing uses a sparse ring beyond the Keep's protected core, because the original clearance threshold excluded the entire Hearthland region; the corrected density and placement rule preserve a usable starting area.
- Resource node variants: Greenwood pine, Fenlands willow, Ashen deadwood, Highlands stone and Ashen rock. Classic sprite behavior remains unchanged.
- `frontier_world.gd` verifies decoration coverage, five landmarks, deterministic placement, no resource overlap and regional resource sprite coverage. PR #50 merged as `c8eed384`; workflow #471 passed 30/30 jobs.


## Phase 08.4 — Faction/archetype visual identity (2026-11-02, implementation branch)
- PR #50 merged Phase 08.3 into main as `c8eed384`; workflow #471 passed 30/30 jobs on Godot 4.3/4.7.
- Branch `feat/phase-08.4-faction-visual-identity` introduces distinct data-driven faction palettes and heraldic motifs plus specialist equipment silhouettes for all six enemy archetypes.
- A modular draw helper keeps identity rendering separate from enemy AI/behavior components. No collision, combat timing or save-schema changes are intended.
- New regression `tests/faction_visual_identity.gd` validates palette/motif uniqueness, enemy profile assignment across all 24 faction/archetype combinations and Classic isolation. PR #52 merged as `ce69391`; workflow #473 passed 72/72 jobs. Rendered screenshot review remains pending.


## Phase 08.5 — Frontier building visual identity (2026-11-02, implementation branch)
- PR #52 merged Phase 08.4 into main as `ce69391`; workflow #41422716411 passed 72/72 jobs on Godot 4.3/4.7, Frontier performance, and Windows/Linux exports.
- Branch `feat/phase-08.5-building-visual-identity` adds material/feature profiles to all 13 shipped building definitions and a draw-only visual helper for structure details plus four HP-scaled damage states.
- Overlays are Frontier-only. Classic texture rendering, collision footprints, HP logic, AI/combat, and save schema v13 remain unchanged.
- Construction-stage art remains deferred until Phase 05 has a real staged-construction state. New regression: `tests/building_visual_identity.gd`; CI and rendered screenshots pending.


## Phase 08.6 — Combat visual feedback (2026-11-02, implementation branch)
- PR #53 merged Phase 08.5 into main as `3aaa37f`; workflow #475 passed 74/74 jobs on Godot 4.3/4.7, including 35 regression suites per engine, Frontier performance diagnostic and Windows/Linux exports.
- Branch `feat/phase-08.6-combat-visual-feedback` adds a shared draw-only feedback helper for melee/ranged wind-up, directional impact, stagger and Dash/Cleave/Rally cue shapes.
- Existing enemy archetype telegraphs, player slash/cleave arcs, particle caps and corpse/death animation are retained. The new layer does not change damage, timing, AI, collision or save schema v13.
- New regression: `tests/combat_visual_feedback.gd`; CI and native-scale rendered screenshots pending.


## Phase 08.7 — Regional ambience and audio identity (2026-11-02, implementation branch)
- PR #54 merged Phase 08.6 combat visual feedback into main as `cf41982`; workflow #476 passed 76/76 jobs across Godot 4.3/4.7, Frontier performance and Windows/Linux exports.
- Branch `feat/phase-08.7-regional-audio-identity` adds ten deterministic day/night ambience loops across five Frontier biomes, original procedural menu/campaign music, and 14 short event-driven combat/campaign cues.
- Region/day-night and menu/campaign transitions use two-player crossfades. All new AudioStreamPlayers use the existing Master bus, preserving the persisted master volume and mute control.
- Generated audio remains in code; no external recordings/music assets or save schema changes. Regression `tests/audio_identity.gd` validates stream format/loop boundaries, deterministic generation, cue availability and context routing. CI and human listening review pending.


## Phase 08.7 — Regional ambience and audio identity (2026-11-02, merged)
- PR #55 merged Phase 08.7 into main as `d933bb6`; workflow #41427499533 passed 78/78 jobs on Godot 4.3/4.7, including 37 assertion suites per engine, Frontier performance diagnostic and Windows/Linux release export.
- Ten deterministic loop-forward ambience streams cover five Frontier biomes × day/night; two original procedural music loops cover campaign and paused/menu context with crossfades.
- Fourteen event-driven cues cover combat anticipation/projectiles/block/stagger/abilities/charges/siege and campaign wave/camp/objective/act/victory events. All new players use Master bus and the existing persisted volume/mute control.
- No external audio recordings/music samples or save schema changes. `tests/audio_identity.gd` validates buffers/loop boundaries, deterministic samples, cue coverage, Master bus routing and context selection.
- Actual device listening, biome contrast, level balancing, loop seam and pause/resume audibility remain manual acceptance gates.


## Phase 09.3 — Frontier late-act save/reload acceptance (2026-11-02, merged)
- PR #57 merged into `main` as `a1ccebe`; workflow [#490](https://github.com/shimleabyte/hold-the-keep/actions/runs/41432676578) passed 78/78 jobs on Godot 4.3/4.7, including Frontier performance and Windows/Linux exports.
- `tests/campaign_reload_hardening.gd` now validates Act I–IV objective completion, the Act II active-escort checkpoint, three conquered strongholds, saved/reloaded damage to the Ashen Host, and the requirement to conquer the fourth stronghold before the day-20 King can finish Conquest.
- The test also saves and reloads the completed victory, verifying all eleven objectives, all four conquered strongholds and the final-boss completion flag survive.
- Escort path construction and restoration are asserted here; full path traversal remains exercised by `tests/frontier_campaign.gd`. No gameplay code or save schema v13 changes.


## Phase 05.2b — Construction queue (2026-11-03, merged via PR #59)
- PR #59 squash-merged into `main` as `6147cfc`; workflow #509 passed 80/80 jobs on Godot 4.3/4.7.
- Queue stores explicit priority in additive save-v13 `queue_order`; legacy v13 sites without the field remain loadable. Numeric integral indices are accepted after JSON parsing; fractional, duplicate, negative and out-of-range indices are rejected.
- Builder target selection follows queue order, remains bounded to workplace radius and eight path candidates, and skips unreachable projects so the queue can progress.
- HUD uses `N` for queue panel; `B` remains Builder job control. Panel displays project order, paid resource costs and live progress with UP/DN reorder and X cancellation. Active blueprint count is capped at 64 to match save validation.
- Regression covers JSON round-trip, queue order, Builder priority/fallback, HUD listing, legacy save compatibility, duplicate/fractional index rejection, and Storage cost-source save/reload.



## Phase 05.3a — Watchtower vision (2026-11-03, merged via PR #60)
- PR #60 squash-merged into `main` as `beef7b7`; workflow #515 passed 82/82 jobs on Godot 4.3/4.7.
- Existing `tower` now displays as `Menara Pengawas` and declares `vision_radius: 128`; no duplicate building ID, art asset or save schema field.
- Fog scanning permanently discovers terrain inside tower vision. Strategic-map enemy observation uses the same radius; demolishing a tower ends live observation but does not re-cover explored terrain.
- Existing turret range, damage and fire interval remain unchanged. Regression `tests/watchtower_vision.gd` passes on both engine versions; rendered map-marker review remains manual.

## Phase 05.3b — Granary food reserve (2026-11-03, merged via PR #61)
- PR #61 squash-merged into `main` as `d9b87b1`; workflow #41558978053 passed 84/84 jobs.
- Granary research unlocks a 3×2, 240-capacity food-only depot while preserving the +1 farm-worker slot bonus.
- Farmers prioritize reachable Granaries; Classic daily upkeep and villager growth draw from central Inventory first, then stored Granary food. The resource bar displays combined usable food.
- Frontier Granaries participate in connected depot transfers, food-only shipments, isolated-depot pressure and saboteur/faction raids. Granary is intentionally excluded as a construction/research cost source.
- Save schema stays v13 with per-building accepted-resource validation; legacy v13 saves without Granaries remain valid. Regression covers Classic/Frontier behavior and save/load on both Godot engines.


## Phase 09.2 — scripted campaign combat-budget probes (2026-11-03, merged via PR #62)
- PR #62 squash-merged into `main` as `4cc0420`; workflow #41564491766 passed 86/86 jobs on Godot 4.3/4.7, including the Frontier performance diagnostic and Windows/Linux exports.
- Menambahkan `tests/campaign_combat_simulation.gd`: lima encounter terkurasi untuk ujung Act I–IV dan serangan King pada hari ke-20.
- Menggunakan transaksi damage player/enemy, armor, structure multiplier, cooldown, Cleave dan Rally yang sudah ada; target schedule dibuat deterministik.
- Output JSON per kasus: wave budget vs sample count, Keep HP/damage, populasi tersisa/hilang, player downs, musuh dikalahkan/tersisa, waktu simulasi dan failure modes.
- Batas validitas: bukan simulasi seluruh wave 20–65 musuh, pathfinding, autonomous AI, ekonomi pekerja atau pengganti human playtest. Tidak mengubah angka balance runtime atau save schema v13.
- Test terdaftar di CI Godot 4.3/4.7 dan runner lokal. Probe ini menandai indikator untuk human follow-up: King case menghabiskan 345 Keep HP, menewaskan satu villager dan menjatuhkan player 10 kali dalam 75.1 detik simulasi; angka ini berasal dari roster terkurasi, bukan full-wave balance verdict.


## Feature branch — Healer + Infirmary (2026-11-03)
- Branch: `feat/healer-infirmary`, stacked after `feat/scout-specialist`; do not merge until Hunter PR #64 and Scout PR #65 are integrated and this branch is retargeted.
- Adds Era II `field_medicine`, a locked two-slot Infirmary with a 16-tile service radius, the Healer occupation (I shortcut), patient reservations per workplace, and bounded 10-HP treatment every 3.2 seconds.
- Save schema increments to v16. Existing v15 saves remain valid; migration coverage includes v1–v16 Classic and v7–v16 Frontier.
- Regression `tests/healer_infirmary.gd` covers Field Medicine unlock, capacity, assignment, most-wounded patient selection, independent reservations, treatment clamp, demolition cleanup and v16/v15 migration.
- This branch is not in `main`; manual rendered and gameplay acceptance remains pending.


## 52. Phase 04 — Blacksmith and Forge (2026-11-03, implementation branch)
- Branch: `feat/blacksmith-forge`, based on the green Healer head `7dc6ebf`; stacked PR #68 targets `feat/healer-infirmary`.
- Forge exposes two Blacksmith workplaces within an 18-tile service radius. Blacksmith is assigned through the JOBS drawer; no keyboard shortcut is taken from existing controls.
- Existing Era III Iron Weapons and Iron Armor research gate separate one-time soldier recipes. Iron Weapon costs 3 iron + 1 wood and adds 20% individual soldier damage; Iron Armor costs 4 iron + 2 wood and adds 20% individual maximum HP.
- Soldier targets are reserved per Forge. Workers reject expeditioning, recalling, hidden, fleeing or fighting targets; reservation cleanup runs on completion, invalid target, sabotage and workplace demolition.
- Save schema increments to v17 for Blacksmith occupation, equipment flags and stat restoration. Classic v1–v17 and Frontier v7–v17 migration fixtures are required.
- `tests/blacksmith_forge.gd` covers capacity, reservations, costs, stat effects, v16 migration and demolition cleanup. Latest full Godot 4.7 CI is required before marking the slice validated; rendered balance/art review remains manual.
