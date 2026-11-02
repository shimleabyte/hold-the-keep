# Phase 09 — Balance, Performance and Release Hardening

**Status:** Phase 09.3 late-act save/reload coverage is merged through PR #57 (`a1ccebe`); workflow [#490](https://github.com/shimleabyte/hold-the-keep/actions/runs/41432676578) passed 78/78 jobs on Godot 4.3/4.7, Frontier performance diagnostic and Windows/Linux release export. Save schema remains v13. Target-hardware profiling, campaign balance simulations/human playtests, native Windows runtime and clean-machine release acceptance remain open.
**Mainline:** `main` (PR #57 merged); continue with measured balance and manual release-acceptance gates.
**Save schema:** v13 on `main`; PR #57 adds regression coverage only and does not change runtime save data.
**Engine targets:** Godot 4.3 and 4.7.

## Goal

Make the expanded 128×128 Frontier campaign predictable under load and safe to ship without weakening Classic Mode or changing save compatibility. This phase is a verification and measured-optimization phase, not a content expansion phase.

## Workstreams

### 09.1 — Reproducible performance baseline
- [x] Replace the old Classic-only micro-benchmark with a configurable diagnostic for Classic or Frontier.
- [x] Include faction-specific rosters, villagers, ranged projectiles and capped particle effects in the Frontier workload.
- [x] Report process/physics frame-time percentiles, wall-frame percentiles, peak projectile count, particle count, node count and static memory.
- [x] Run the reference Frontier workload in CI and publish p50/p95/p99 metrics as an artifact (Godot 4.7 headless runner; diagnostic only).
- [ ] Run the benchmark on the actual target desktop hardware and record Godot version, OS, CPU, GPU, resolution and workload.
- [ ] Compare the same workload before/after any optimization; do not optimize based on intuition alone.

### 09.2 — Bounded stress and tactical balance
- [x] Add a CI stress scenario that instantiates a 128×128 world, all four factions, mixed faction rosters, a ranged projectile, 48 villagers and the 500-particle ceiling.
- [x] Add a deterministic Classic/Frontier campaign matrix for stage transitions, day-by-day wave budgets, act-specific faction rosters and final-boss timing.
- [ ] Add representative campaign balance cases for the ends of all four Frontier acts and the final day-20 encounter.
- [x] Check that Classic remains a 15-day campaign with its original rules (15-day / 3-stage assertions in the campaign matrix).
- [ ] Record faction-specific failure modes, Keep damage, surviving population, remaining enemy count and elapsed simulated time.
- [ ] Perform human playtests across all four acts; automated simulations are not a substitute for pathing, readability and pacing review.

### 09.3 — Save and recovery hardening
- [x] Validate the current save structure and legacy schemas v1–v12 in Classic, plus v7–v12 in Frontier.
- [x] Exercise the interrupted-write window: valid primary save plus an incomplete `save.tmp`.
- [x] Add an end-to-end Frontier reload pass preserving completed objectives, unlocked act, an active escort/path index and damaged stronghold HP.
- [x] Verify the next save removes stale temporary data, rotates a valid backup and leaves a valid primary.
- [x] Verify corrupt-primary detection and backup eligibility.
- [x] Extend reload coverage through Frontier Acts I–IV, completed regional objectives, conquered strongholds, damaged Ashen Host HP, the day-20 King gate and save/reload of the final victory (PR #57; workflow #490, 78/78).
- [x] Run the migration and campaign regression matrix on Godot 4.3 and 4.7; late-act reload and persisted-victory coverage also passes on both engines (workflow #490).

### 09.4 — Release export hardening
- [x] Add deterministic checks for the Windows Desktop and Linux export preset names, paths, resource filters and embedded PCK settings.
- [x] Install the Godot 4.3-matching export templates in CI and produce real Windows and Linux release artifacts.
- [x] Verify the Windows PE executable format and launch the Linux release headlessly for a bounded smoke test.
- [ ] Smoke-test the Windows build on a Windows runner and verify both binaries on clean target machines.
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

The latest completed mainline workflow #41314731305 executed 46 successful jobs, including Godot 4.3/4.7 import/parse and regression coverage, Frontier performance diagnostics, and Windows/Linux export checks. PR #31 merged the Phase 02 local stockpile/automatic-shipment slice and save schema v12; its 21 regression scripts per engine, export and diagnostic checks all passed. No target-hardware frame-time result, native Windows runtime test or full manual playtest is claimed.


## CI evidence

**Workflow run #271** completed successfully on the PR merge ref. It covered Godot 4.3 and 4.7 import/parse plus the configured regression jobs; the campaign balance matrix, Frontier reload, Frontier stress and save/release hardening checks passed. The stress job reported 64 registered enemies, 50 villagers (including the two initial villagers), one live projectile and exactly 500 particles.

The Godot 4.3 export job generated both desktop binaries, validated the Windows PE format, smoke-launched Linux headlessly and uploaded the artifacts. The Godot 4.7 diagnostic job uploaded a `frontier-performance-godot-4.7` report. Its first report reached only 340 live particles, so the benchmark has been updated to sustain the full 500-particle ceiling; do not treat the older report as the final reference workload. A new workflow run is required to validate that change.


## Latest CI evidence — workflow run #278

All 30 jobs reported completed successfully on PR #26: Godot 4.3/4.7 import and parse, the configured regression matrix, the Frontier performance diagnostic and the Windows/Linux export job. The Frontier diagnostic recorded a 128×128 world, 119 active enemies, 82 villagers, six peak projectiles, 500 peak particles and about 62.7 MB static memory. Wall-frame samples were p50 4.27 ms, p95 10.45 ms and p99 13.55 ms. Godot process monitor p95 contained a 102.24 ms spike; treat the run as headless diagnostic evidence only, not an accepted target-machine frame-time budget.

The Godot 4.3 export job produced both binaries, verified Windows PE format, passed the bounded Linux headless launch, and uploaded the release artifact. Manual campaign playtests, desktop hardware profiling, Windows runtime smoke and clean-machine save/settings upgrade tests remain open.
