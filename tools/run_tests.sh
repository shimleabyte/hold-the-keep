#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
GODOT_BIN="${GODOT:-godot}"

tests=(
    anim_sync
    animation_motion
    campaign_assault
    combat_tower_walls
    events_boss_final_night
    fx_shake_settings
    input_rebinding
    map_stages
    player_combat
    resource_save_state
    responsive_layout
    restart_gameover
    save_load_audio_menu
    tech_tree
    territory_claims
    villagers_economy
    world_config
    frontier_world
)

for test_name in "${tests[@]}"; do
    echo "::group::Godot regression: ${test_name}"
    "$GODOT_BIN" --headless --fixed-fps 60 --path . --script "res://tests/${test_name}.gd"
    echo "::endgroup::"
done

echo "PASS: ${#tests[@]} headless regression scripts."
