# Skrip tes

Skrip `SceneTree` (bukan GUT): dijalankan langsung dengan Godot, mencetak hasil ke stdout.
Sebagian skrip lama mencetak hasil untuk inspeksi manual; tes regresi baru memakai `assert` dan akan menghentikan tes saat kondisi gagal.
Folder ini ada di dalam proyek, jadi Godot akan mengimpornya sebagai skrip biasa (tidak mengganggu game).

## Menjalankan
Dari akar proyek:

    godot --headless --path . --import
    bash tools/check_gdscript.sh
    bash tools/run_tests.sh

`check_gdscript.sh` menjalankan parse-only terhadap seluruh skrip di `scripts/` dan `tests/`.
`run_tests.sh` menjalankan suite regresi headless dengan fixed 60 FPS. `--fixed-fps 60` penting:
tanpa itu simulasi tes panjang berjalan mengikuti waktu nyata.

GitHub Actions menjalankan kedua langkah tersebut pada Godot 4.3 dan 4.7 untuk setiap pull request
ke `main`, push ke `main` atau branch `feat/**` / `fix/**`, serta workflow manual.

| Skrip | Menguji |
|---|---|
| tech_tree.gd | syarat riset, efek ke entitas yang ada, bangunan terkunci, bijih besi, HUD, panel, save/load |
| territory_claims.gd | klaim Keep, larangan bangunan di luar klaim, penempatan Outpost di frontier, ekspansi, pembongkaran |
| combat_tower_walls.gd | menara menembak, cincin tembok, 150 musuh, game over |
| villagers_economy.gd | job, setor ke gudang, ladang, populasi, malam, upkeep, performa |
| events_boss_final_night.gd | event acak, boss, kemenangan, malam terakhir vs tingkat pertahanan |
| save_load_audio_menu.gd | round-trip save/load, autosave, save rusak, audio, menu, pengaturan |
| resource_save_state.gd | status pohon/batu/bijih besi dan timer tumbuh ulang, rollback ke backup save |
| campaign_assault.gd | klaim musuh, fog reveal/save, G assault/recall, garrison saat fajar, conquest victory |
| map_stages.gd | empat biome, fog map panel, batas tiga bab, bobot archer/brute per bab |
| responsive_layout.gd | expanded integer-scaled viewport, HUD/map/hotbar bounds across five logical resolutions |
| player_combat.gd | XP/level, skill unlock/cooldown, Dash/Cleave/Rally, archer projectile, brute armor, combat save |
| input_rebinding.gd | perubahan keybind, penolakan konflik/reserved key, persistensi settings |
| restart_gameover.gd | layar game over dan restart (R) |
| fx_shake_settings.gd | batas partikel, guncangan layar, tombol menu, performa dengan efek |
| perf.gd | biaya per frame: 150 musuh + 42 villager |
| anim_sync.gd | pukulan penebang jatuh di frame benturan; pelarian memakai klip lari |
| animation_motion.gd | idle breathing, walk/run lift, directional attack/work lean, hurt recoil, stable death pose |
| world_config.gd | profile dimensions, tile indexing, Keep placement, Classic/Frontier profile definitions |
| balance_final_night.gd | `CASES="4,2;6,3"` = daftar "prajurit,menara"; `TECH=era2` atau `TECH=all` memberi teknologi; hasil MENANG/KALAH |

Catatan: sebagian label teks di dalam skrip sudah usang (misalnya "tower 7dmg"; nilai sebenarnya 12).
Selisih "state identical after load" pada save_load_audio_menu.gd hanya urutan key dictionary inventori.

## Skrip yang dijalankan otomatis di CI
Suite headless saat ini mencakup: `anim_sync`, `animation_motion`, `campaign_assault`,
`combat_tower_walls`, `events_boss_final_night`, `fx_shake_settings`, `input_rebinding`,
`map_stages`, `player_combat`, `resource_save_state`, `responsive_layout`,
`restart_gameover`, `save_load_audio_menu`, `tech_tree`, `territory_claims`,
`villagers_economy`, dan `world_config`.

`perf.gd` dan `balance_final_night.gd` tetap berupa diagnostic/balance runs; jalankan terpisah saat
mengukur performa atau mengubah komposisi gelombang. Screenshot, preview sprite dan klik HUD tetap
memerlukan jalur render/manual yang dijelaskan di bawah.

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
