# Skrip tes

Skrip `SceneTree` (bukan GUT): dijalankan langsung dengan Godot, mencetak hasil ke stdout.
Sebagian skrip lama mencetak hasil untuk inspeksi manual; tes regresi baru memakai `assert` dan akan menghentikan tes saat kondisi gagal.
Folder ini ada di dalam proyek, jadi Godot akan mengimpornya sebagai skrip biasa (tidak mengganggu game).

## Menjalankan
Dari akar proyek:

    godot --headless --path . --import
    bash tools/check_gdscript.sh
    bash tools/run_tests.sh
    bash tools/run_diagnostics.sh

`check_gdscript.sh` menjalankan parse-only terhadap seluruh skrip di `scripts/` dan `tests/`.
`run_tests.sh` menjalankan pemeriksaan regresi berbasis `assert` di headless dengan fixed 60 FPS.
Skrip observasi lama yang hanya mencetak hasil tanpa assertion dipisahkan ke `run_diagnostics.sh`;
jalankan saat meninjau animasi, pertarungan, efek, ekonomi atau alur save/menu.

GitHub Actions menjalankan import/parse pada Godot 4.3 dan 4.7, 37 assertion regression tests per versi, Frontier performance diagnostic, serta Windows/Linux export. Workflow berjalan pada push `main`, pull request ke `main`/`feat/**`, dan workflow manual. Mainline workflow #41314731305 menyelesaikan 46/46 jobs setelah PR #31, termasuk test local depot stockpile pada kedua versi Godot.

| Skrip | Menguji |
|---|---|
| tech_tree.gd | syarat riset, efek ke entitas yang ada, bangunan terkunci, bijih besi, HUD, panel, save/load |
| territory_claims.gd | klaim Keep, larangan bangunan di luar klaim, penempatan Outpost di frontier, ekspansi, pembongkaran |
| combat_tower_walls.gd | menara menembak, cincin tembok, 150 musuh, game over |
| villagers_economy.gd | job, setor ke gudang, ladang, populasi, malam, upkeep, performa |
| events_boss_final_night.gd | event acak, boss, kemenangan, malam terakhir vs tingkat pertahanan |
| save_load_audio_menu.gd | round-trip save/load, autosave, save rusak, audio, menu, pengaturan |
| resource_save_state.gd | status pohon/batu/bijih besi dan timer tumbuh ulang, rollback ke backup save |
| campaign_assault.gd | Classic single-stronghold compatibility, fog reveal/save, G assault/recall, garrison at dawn and conquest victory |
| faction_visual_identity.gd | four distinct faction palettes/crests, six specialist equipment signatures, enemy visual assignment and Classic isolation |
| building_visual_identity.gd | visual material/detail coverage for all 13 buildings, Frontier-only rendering, unique feature signatures and deterministic damage-state thresholds |
| audio_identity.gd | ten biome/day-night ambience loops, two original music themes, deterministic sample buffers, 14 event cues, Master bus routing and menu/campaign crossfade selection |\n| combat_visual_feedback.gd | melee/ranged anticipation, directional impact, stagger and distinct Dash/Cleave/Rally cue lifetimes |
| faction_registry.gd | four faction definitions, region mapping, roster membership, stronghold garrisons, component-backed War Shaman allied healing/cooldown and v11 faction save persistence |
| frontier_campaign.gd | Classic/Frontier campaign calendars, act gates, all regional objectives, rewards, save/load and day-20 King victory |
| campaign_multi_stronghold.gd | four Frontier strongholds, deterministic objective order, regional placement, independent garrisons, locked objectives, save/load and final conquest |
| workplace_assignments.gd | Builder workplace capacity/radius, repair material consumption, reachable depot selection, job priority reassignment and v11 save validation |
| production_worksites.gd | Lumber Camp/Quarry workplace limits, specialist work radius, Classic fallback, cleanup and v11 save compatibility |
| map_stages.gd | empat biome Classic, fog map panel, batas tiga bab, bobot archer/brute per bab |
| responsive_layout.gd | resolution-to-viewport mapping, exact 2× pixel scale, live synchronization, HUD safe playfield and map/hotbar bounds across six desktop resolutions |
| player_combat.gd | XP/level, skill unlock/cooldown, Dash/Cleave/Rally, archer projectile, brute armor, combat save |
| input_rebinding.gd | perubahan keybind, penolakan konflik/reserved key, persistensi settings |
| restart_gameover.gd | layar game over dan restart (R) |
| fx_shake_settings.gd | batas partikel, guncangan layar, tombol menu, performa dengan efek |
| perf.gd | configurable Classic/Frontier benchmark; `PROFILE=frontier ENEMIES=96 VILLAGERS=80 FRAMES=360` reports p50/p95/p99 frame time, nodes, static memory, projectiles and particles |
| frontier_stress.gd | Frontier 128×128, faction rosters, 48 villagers, projectile and 500-particle ceiling |
| campaign_reload_hardening.gd | Act I–IV Frontier reloads, completed regional objectives, active escort recovery, three conquered strongholds, damaged final stronghold, day-20 King gate and persisted victory reload |
| campaign_balance_matrix.gd | Classic 15-day and Frontier 20-day schedules, act wave budgets, faction rosters and final-boss gate |
| release_hardening.gd | Classic v1–v12 and Frontier v7–v12 save migration, interrupted writes, backup recovery and export presets |
| anim_sync.gd | pukulan penebang jatuh di frame benturan; pelarian memakai klip lari |
| animation_motion.gd | idle breathing, walk/run lift, directional attack/work lean, hurt recoil, stable death pose |
| world_config.gd | profile dimensions, tile indexing, Keep placement, Classic/Frontier profile definitions |
| frontier_world.gd | 128×128 terrain, five biomes, dedicated Frontier terrain atlas contract, regional resources, iron veins, Keep claims, reachability and deterministic generation |
| regional_control_roads.gd | regional neutral/player/enemy/contested states, walkable roads/bridges, Keep-connected supply routes, depot isolation, rerouting and save persistence |
| local_depot_stockpiles.gd | Frontier local depot balances, capacity rejection, worker cargo deposit, bounded connected-depot shipments, v13 migration and save/load round-trip |
| physical_shipments.gd | Player-directed depot orders, visible carriers, Keep withdrawals, capacity reservations, cancellation/refund, route interruption recovery and v13 persistence |
| depot_cost_sources.gd | Explicit Keep/Storage/Outpost cost source, construction/research debit, no cross-depot pooling, disconnected-source rejection, atomic payment and v13 preference persistence |
| supply_pressure.gd | Contested disconnected-depot warning, targeted saboteur pathing, deterministic stock theft, bounded repeat raid, depot damage, HUD state, v13 persistence and recovery |
| shieldbearer_behavior.gd | component-backed brace telegraph, frontal source-origin mitigation, side/rear counterplay, stagger interruption and disengage cancellation |
| scout_marking.gd | component-backed Scout telegraph, same-faction-only bounded sharing, focus-target priority, mark expiry, stagger interruption and target disengage |
| saboteur_disruption.gd | component-backed Saboteur priority scan, A* reachability, telegraphed disruption, structure damage, tower/depot/workplace suppression and recovery, stagger interruption |
| siege_engine_behavior.gd | component-backed Siege Engine target priorities, A* pathing, telegraphed structural impact, recovery, defender interruption and building-only attack |
| beast_rider_charge.gd | component-backed isolated defender target priority, A* locked charge route, telegraphed impact, sidestep miss and stagger interruption |
| faction_camps_patrols.gd | deterministic enemy-territory camp placement, fog activation, A* patrol leash, bounded reinforcement, camp destruction and v13 save/restore |
| faction_raids.gd | exposed connected depot/road target selection, finite camp dispatch, pathing, structure damage, depot theft, target abort, faction raid save/restore and cleanup |
| faction_warfare_stress.gd | simultaneous 48 faction garrisons, eight patrols, four raids, 48 villagers, per-raider A* routing, global raid cap and v13 snapshot validation |
| balance_final_night.gd | `CASES="4,2;6,3"` = daftar "prajurit,menara"; `TECH=era2` atau `TECH=all` memberi teknologi; hasil MENANG/KALAH |

Catatan: sebagian label teks di dalam skrip sudah usang (misalnya "tower 7dmg"; nilai sebenarnya 12).
Selisih "state identical after load" pada save_load_audio_menu.gd hanya urutan key dictionary inventori.

## Skrip yang dijalankan otomatis di CI

Suite assertion yang dijalankan pada Godot 4.3 dan 4.7 masing-masing mencakup 37 skrip:

`animation_motion`, `campaign_assault`, `campaign_multi_stronghold`, `workplace_assignments`, `production_worksites`, `faction_registry`, `faction_visual_identity`, `building_visual_identity`, `combat_visual_feedback`, `audio_identity`, `frontier_campaign`, `frontier_stress`, `campaign_reload_hardening`, `campaign_balance_matrix`, `release_hardening`, `input_rebinding`, `map_stages`, `player_combat`, `resource_save_state`, `responsive_layout`, `territory_claims`, `world_config`, `frontier_world`, `regional_control_roads`, `local_depot_stockpiles`, `outpost_garrisons`, `physical_shipments`, `depot_cost_sources`, `supply_pressure`, `shieldbearer_behavior`, `scout_marking`, `saboteur_disruption`, `siege_engine_behavior`, `beast_rider_charge`, `faction_camps_patrols`, `faction_raids`, serta `faction_warfare_stress`.

CI juga menjalankan import/parse pada kedua versi Godot, performance diagnostic Frontier pada Godot 4.7, serta template-backed Windows/Linux release export pada Godot 4.3. Pada 1 November 2026, PR #32 workflow #41318897606 lulus 48/48 jobs. Setelah Phase 02.3, PR #33 workflow #41323062111 lulus 50/50 jobs; 23 assertion suite berjalan pada masing-masing Godot 4.3 dan 4.7, bersama import/parse, performance diagnostic dan Windows/Linux export. PR #34 workflow #41325205416 completed successfully with 52/52 jobs: 24 assertion suites passed on each Godot 4.3 and 4.7, with import/parse, Frontier performance diagnostic and Windows/Linux release export.

Skrip observasi/manual yang tidak termasuk assertion CI: `anim_sync`, `combat_tower_walls`, `events_boss_final_night`, `fx_shake_settings`, `restart_gameover`, `save_load_audio_menu`, `tech_tree`, dan `villagers_economy`. Jalankan skrip tersebut ketika memeriksa perilaku runtime yang belum dikonversi menjadi assertion.

`perf.gd` dan `balance_final_night.gd` tetap berupa diagnostic/balance runs; jalankan terpisah saat mengukur performa atau mengubah komposisi gelombang. Benchmark default menjalankan Frontier 128×128; atur `PROFILE=classic` untuk pembanding 64×64. Screenshot, preview sprite dan klik HUD tetap memerlukan jalur render/manual di bawah.

## Skrip yang butuh layar (render sungguhan)
Dijalankan di layar virtual dengan OpenGL software, hasilnya PNG di /tmp/shots:

    sudo apt-get install -y xvfb libgl1-mesa-dri libglx-mesa0
    mkdir -p /tmp/shots
    xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --fixed-fps 60 --script tests/shot_overview.gd

- shot_overview.gd: siang, bantuan, malam, boss, mode bangun
- strategic map: buka TAB/MAP dan cek fog, marker, ownership tint, serta label region
- shot_tech.gd: panel teknologi, HUD dengan riset berjalan, urat bijih besi
- shot_animation.gd: close-up serang, lari, mayat
- shot_fx.gd: close-up efek partikel
- hud_clicks.gd: klik mouse sungguhan di HUD (event sintetis memakai koordinat jendela = viewport x 3;
  posisi mouse viewport harus diset dengan `warp_mouse`)
- preview_sprites.gd: `NAMES=player,enemy_wolf SCALE=3 godot --headless --path . --script tests/preview_sprites.gd`
  menulis /tmp/prev.png (pratinjau sprite sheet)


Phase 09 CI runs the Frontier timing benchmark as a non-gating diagnostic and uploads a p50/p95/p99 artifact. These runner-specific measurements do not substitute for target-hardware profiling.

The release-export workflow installs Godot 4.3-matching templates, builds Windows and Linux binaries, validates the Windows PE format and smoke-tests the Linux executable. These checks do not replace clean-machine user acceptance.


PR #35 merged Phase 02.5 at `2ba5628`; workflow #41328005585 passed. PR #36 merged Shieldbearer directional brace at `b02aa60`; PR #39 merged Scout faction-aware marking at `11f3f13`; PR #40 merged Saboteur building disruption at `8f1a914`. PR #41 merged Siege Engine structural siege cycle at `58da7be`; workflow #41356689758 passed 62/62 jobs, including 29 assertion suites on each of Godot 4.3 and 4.7. PR #42 merged Beast Rider charge at `e6cf221`; workflow [#41366304675](https://github.com/shimleabyte/hold-the-keep/actions/runs/41366304675) passed 64/64 jobs. PR #43 merged Phase 06.3 faction camps and bounded patrols at `fa3a45a`; workflow [#41377840888](https://github.com/shimleabyte/hold-the-keep/actions/runs/41377840888) passed 66/66 jobs, including 31 assertion suites per engine, import/parse, Frontier performance diagnostic and Windows/Linux release export.


PR #42 merged the Beast Rider charge and its regression coverage. The test verifies isolated-defender selection, a walkable route around a wall, telegraph/impact timing, sidestep avoidance, stagger interruption and the cooldown window. The ability is transient; save schema v13 is unchanged.


PR #43 merged Phase 06.3 camp/patrol coverage. `faction_camps_patrols` passed on Godot 4.3 and 4.7. It checks deterministic placement in enemy territory, fog-gated activation, A* path/leash bounds, return behavior, active cap and finite reinforcement budget, camp destruction cleanup, and v13 save/restore persistence.
