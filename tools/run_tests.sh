#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
GODOT_BIN="${GODOT:-godot}"

# Keep CI limited to scripts that enforce outcomes with assertions.
# Print-only simulations are available through tools/run_diagnostics.sh.
tests=(
    animation_motion
    campaign_assault
    input_rebinding
    map_stages
    player_combat
    resource_save_state
    responsive_layout
    territory_claims
    world_config
)

for test_name in "${tests[@]}"; do
    echo "::group::Godot regression: ${test_name}"
    "$GODOT_BIN" --headless --fixed-fps 60 --path . --script "res://tests/${test_name}.gd"
    echo "::endgroup::"
done

echo "PASS: ${#tests[@]} headless regression scripts."
