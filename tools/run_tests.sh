#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
GODOT_BIN="${GODOT:-godot}"

# Only assert-based checks belong in the blocking CI suite. Long print-only
# simulations are kept in tools/run_diagnostics.sh for deliberate manual runs.
tests=(
    animation_motion
    campaign_assault
    campaign_multi_stronghold
    input_rebinding
    map_stages
    player_combat
    resource_save_state
    responsive_layout
    territory_claims
    world_config
    frontier_world
    regional_control_roads
)

for test_name in "${tests[@]}"; do
    echo "::group::Godot regression: ${test_name}"
    "$GODOT_BIN" --headless --fixed-fps 60 --path . --script "res://tests/${test_name}.gd"
    echo "::endgroup::"
done

echo "PASS: ${#tests[@]} headless regression scripts."
