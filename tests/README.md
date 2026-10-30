# Skrip tes

Skrip `SceneTree` (bukan GUT): dijalankan langsung dengan Godot, mencetak hasil ke stdout.
Sebagian skrip lama mencetak hasil untuk inspeksi manual; tes regresi baru memakai `assert` dan akan menghentikan tes saat kondisi gagal.
Folder ini ada di dalam proyek, jadi Godot akan mengimpornya sebagai skrip biasa (tidak mengganggu game).

## Menjalankan
Semua dari akar proyek (setelah `godot --headless --path . --import` sekali):

    godot --headless --fixed-fps 60 --path . --script tests/<nama>.gd

`--fixed-fps 60` penting: tanpa itu simulasi berjalan real-time dan tes panjang tidak selesai.

| Skrip | Menguji |
|---|---|
| tech_tree.gd | syarat riset, efek ke entitas yang ada, bangunan terkunci, bijih besi, HUD, panel, save/load |
| territory_claims.gd | klaim Keep, larangan bangunan di luar klaim, penempatan Outpost di frontier, ekspansi, pembongkaran |
| combat_tower_walls.gd | menara menembak, cincin tembok, 150 musuh, game over |
| villagers_economy.gd | job, setor ke gudang, ladang, populasi, malam, upkeep, performa |
| events_boss_final_night.gd | event acak, boss, kemenangan, malam terakhir vs tingkat pertahanan |
| save_load_audio_menu.gd | round-trip save/load, autosave, save rusak, audio, menu, pengaturan |
| resource_save_state.gd | status pohon/batu/bijih besi dan timer tumbuh ulang, rollback ke backup save |
| input_rebinding.gd | perubahan keybind, penolakan konflik/reserved key, persistensi settings |
| restart_gameover.gd | layar game over dan restart (R) |
| fx_shake_settings.gd | batas partikel, guncangan layar, tombol menu, performa dengan efek |
| perf.gd | biaya per frame: 150 musuh + 42 villager |
| anim_sync.gd | pukulan penebang jatuh di frame benturan; pelarian memakai klip lari |
| balance_final_night.gd | `CASES="4,2;6,3"` = daftar "prajurit,menara"; `TECH=era2` atau `TECH=all` memberi teknologi; hasil MENANG/KALAH |

Catatan: sebagian label teks di dalam skrip sudah usang (misalnya "tower 7dmg"; nilai sebenarnya 12).
Selisih "state identical after load" pada save_load_audio_menu.gd hanya urutan key dictionary inventori.

## Skrip yang butuh layar (render sungguhan)
Dijalankan di layar virtual dengan OpenGL software, hasilnya PNG di /tmp/shots:

    sudo apt-get install -y xvfb libgl1-mesa-dri libglx-mesa0
    mkdir -p /tmp/shots
    xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --fixed-fps 60 --script tests/shot_overview.gd

- shot_overview.gd: siang, bantuan, malam, boss, mode bangun
- shot_tech.gd: panel teknologi, HUD dengan riset berjalan, urat bijih besi
- shot_animation.gd: close-up serang, lari, mayat
- shot_fx.gd: close-up efek partikel
- hud_clicks.gd: klik mouse sungguhan di HUD (event sintetis memakai koordinat jendela = viewport x 3;
  posisi mouse viewport harus diset dengan `warp_mouse`)
- preview_sprites.gd: `NAMES=player,enemy_wolf SCALE=3 godot --headless --path . --script tests/preview_sprites.gd`
  menulis /tmp/prev.png (pratinjau sprite sheet)
