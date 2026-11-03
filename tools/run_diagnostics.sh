#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
GODOT_BIN="${GODOT:-godot}"

# These legacy scripts are intentionally verbose simulations that report
# observations to stdout but do not enforce assertions. Run them when reviewing
# animation timing, combat balance, effects, economy or save/menu behavior.
diagnostics=(
    anim_sync
    combat_tower_walls
    events_boss_final_night
    fx_shake_settings
    restart_gameover
    save_load_audio_menu
    tech_tree
    villagers_economy
    frontier_campaign_simulation
    perf
)

for diagnostic in "${diagnostics[@]}"; do
    echo "::group::Godot diagnostic: ${diagnostic}"
    "$GODOT_BIN" --headless --fixed-fps 60 --path . --script "res://tests/${diagnostic}.gd"
    echo "::endgroup::"
done

echo "Finished ${#diagnostics[@]} manual diagnostics."
