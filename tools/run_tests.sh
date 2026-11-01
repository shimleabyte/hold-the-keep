#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
GODOT_BIN="${GODOT:-godot}"
TIMEOUT_BIN="${TIMEOUT_BIN:-timeout}"
TEST_TIMEOUT_SECONDS="${TEST_TIMEOUT_SECONDS:-120}"

if ! command -v "$TIMEOUT_BIN" >/dev/null 2>&1; then
    echo "ERROR: Required timeout command '$TIMEOUT_BIN' was not found." >&2
    echo "Install GNU coreutils or set TIMEOUT_BIN to a compatible timeout command." >&2
    exit 127
fi

if [[ ! "$TEST_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: TEST_TIMEOUT_SECONDS must be a positive integer; got '$TEST_TIMEOUT_SECONDS'." >&2
    exit 2
fi

# Only assert-based checks belong in the blocking CI suite. Long print-only
# simulations are kept in tools/run_diagnostics.sh for deliberate manual runs.
tests=(
    animation_motion
    campaign_assault
    campaign_multi_stronghold
    workplace_assignments
    production_worksites
    faction_registry
    frontier_campaign
    frontier_stress
    campaign_reload_hardening
    campaign_balance_matrix
    release_hardening
    input_rebinding
    map_stages
    player_combat
    resource_save_state
    responsive_layout
    territory_claims
    world_config
    frontier_world
    regional_control_roads
    local_depot_stockpiles
    outpost_garrisons
    physical_shipments
    depot_cost_sources
    supply_pressure
    shieldbearer_behavior
)

for test_name in "${tests[@]}"; do
    test_script="res://tests/${test_name}.gd"
    echo "::group::Godot regression: ${test_name}"
    echo "START: ${test_name} (timeout: ${TEST_TIMEOUT_SECONDS}s)"

    started_at=$SECONDS
    set +e
    "$TIMEOUT_BIN" --foreground --signal=TERM --kill-after=10s "${TEST_TIMEOUT_SECONDS}s" \
        "$GODOT_BIN" --headless --fixed-fps 60 --path . --script "$test_script"
    test_status=$?
    set -e
    elapsed_seconds=$((SECONDS - started_at))

    case "$test_status" in
        0)
            echo "PASS: ${test_name} (${elapsed_seconds}s)"
            ;;
        124|137)
            echo "TIMEOUT: ${test_name} exceeded ${TEST_TIMEOUT_SECONDS}s (elapsed: ${elapsed_seconds}s)." >&2
            echo "Increase TEST_TIMEOUT_SECONDS only if this test is expected to take longer; otherwise investigate the test/runtime hang." >&2
            echo "::endgroup::"
            exit 124
            ;;
        *)
            echo "FAIL: ${test_name} exited with status ${test_status} after ${elapsed_seconds}s." >&2
            echo "::endgroup::"
            exit "$test_status"
            ;;
    esac

    echo "::endgroup::"
done

echo "PASS: All ${#tests[@]} headless regression scripts completed within ${TEST_TIMEOUT_SECONDS}s per test."
