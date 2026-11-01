# Phase 09 — Balance, Performance and Release Hardening

**Status:** First hardening slice in progress. The automated Frontier stress and save/export-configuration gates are being added; measured hardware baselines, full campaign playtests and actual release exports remain open.
**Branch:** `feat/phase-09-balance-performance-release-v2`
**Base:** `feat/phase-07-conquest-objectives` (stacked so the test line includes the Frontier campaign and v11 save schema).
**Engine targets:** Godot 4.3 and 4.7.

## Goal

Make the expanded 128×128 Frontier campaign predictable under load and safe to ship without weakening Classic Mode or changing save compatibility. This phase is a verification and measured-optimization phase, not a content expansion phase.

## Workstreams

### 09.1 — Reproducible performance baseline
- [x] Replace the old Classic-only micro-benchmark with a configurable diagnostic for Classic or Frontier.
- [x] Include faction-specific rosters, villagers, ranged projectiles and capped particle effects in the Frontier workload.
- [x] Report process/physics frame-time percentiles, wall-frame percentiles, peak projectile count, particle count, node count and static memory.
- [ ] Run the benchmark on the actual target desktop hardware and record Godot version, OS, CPU, GPU, resolution and workload.
- [ ] Compare the same workload before/after any optimization; do not optimize based on intuition alone.

### 09.2 — Bounded stress and tactical balance
- [x] Add a CI stress scenario that instantiates a 128×128 world, all four factions, mixed faction rosters, a ranged projectile, 48 villagers and the 500-particle ceiling.
- [ ] Add representative campaign balance cases for the ends of all four Frontier acts and the final day-20 encounter.
- [ ] Check that Classic remains a 15-day campaign with its original rules.
- [ ] Record faction-specific failure modes, Keep damage, surviving population, remaining enemy count and elapsed simulated time.
- [ ] Perform human playtests across all four acts; automated simulations are not a substitute for pathing, readability and pacing review.

### 09.3 — Save and recovery hardening
- [x] Validate the current save structure and legacy schemas v1–v11 in Classic, plus v7–v11 in Frontier.
- [x] Exercise the interrupted-write window: valid primary save plus an incomplete `save.tmp`.
- [x] Add an end-to-end Frontier reload pass preserving completed objectives, unlocked act, an active escort/path index and damaged stronghold HP.
- [x] Verify the next save removes stale temporary data, rotates a valid backup and leaves a valid primary.
- [x] Verify corrupt-primary detection and backup eligibility.
- [ ] Extend reload coverage to later acts, conquered strongholds and the final-boss gate.
- [ ] Run the migration matrix on both supported Godot versions.

### 09.4 — Release export hardening
- [x] Add deterministic checks for the Windows Desktop and Linux export preset names, paths, resource filters and embedded PCK settings.
- [ ] Install the matching export templates in CI and produce real Windows and Linux release artifacts.
- [ ] Launch or smoke-check each exported build on its target platform.
- [ ] Verify clean-machine first launch, save directory creation, settings persistence and upgrade from an older save.

### 09.5 — Manual release gate
- [ ] Classic: fresh campaign, day 1–15, victory/defeat, save/load and settings.
- [ ] Frontier: fresh campaign, all four acts, all regional objective types, four strongholds and day-20 King.
- [ ] Stress: large settlements, faction camps/raids when available, projectile-heavy combat, night waves and effects.
- [ ] UI/render: 1280×720, 1600×900 and 1920×1080; day/night, fog, strategic map and objective panel.
- [ ] No known blocker bugs; publish benchmark evidence and build artifacts before marking the phase complete.

## Workload and provisional budget

The reference workload is Frontier 128×128 with 96 faction enemies, 80 villagers, active ranged attacks/projectiles and up to 500 transient particles. The stress test uses a smaller deterministic CI workload to catch regressions without imposing hardware-specific timing assertions.

Provisional desktop target (not yet measured or accepted):
- 60 FPS at 1280×720 under the reference workload.
- p95 total frame time at or below 16.67 ms; p99 at or below 33.3 ms.
- Particle storage must remain bounded at 500.
- No fixed memory ceiling is declared until a real reference machine and renderer configuration are recorded.

The benchmark is diagnostic by design. CI must validate bounded counts and functional behavior, not enforce one machine's timing numbers across different runners.

## Architecture guardrails

- Keep the complete 128×128 world loaded unless profiling demonstrates a real memory or frame-time problem. Logical 32×32 sectors are not a reason by themselves to add streaming.
- Preserve the Classic 64×64 / 15-day path and legacy save loading.
- Keep entity and particle work bounded; avoid per-frame full-map scans, unbounded spawns and per-particle scene nodes.
- Do not silently change combat values to make a benchmark pass. Every balance change requires a reproducible case and a documented reason.
- Release exports must include all JSON data and embed the PCK.

## Current blockers / honesty of verification

The implementation environment does not contain Godot and cannot reach GitHub from the local shell. The repository changes can be committed through the connected GitHub integration, but local Godot execution, rendered screenshot review, target-hardware profiling and real export execution cannot be claimed here. The GitHub Actions matrix and export-smoke job must provide the engine-backed verification after the branch is pushed.
