# Phase 10 — Resolution-Matched Viewport and HUD Safe Area

**Branch:** `feat/phase-10-adaptive-viewport`  
**Base:** `feat/phase-09-balance-performance-release-v5` (Phase 09 PR #26)  
**Engine targets:** Godot 4.3 and 4.7

## Problem

The game previously used a fixed 480×270 logical viewport for every window resolution. A 1280×720 window therefore enlarged the same 480×270 view instead of showing a larger portion of the world. The HUD stayed responsive, but it occupied a relatively large fraction of the playable view.

Changing Camera2D zoom would also change apparent sprite/tile scale and could make controls and combat harder to read. Phase 10 therefore changes the logical viewport dimensions, not gameplay zoom or world-space values.

## Design

The root Window's `content_scale_size` follows the actual client-window size at a 2× scale:

```text
logical_width  = max(480, floor(window_width  / 2))
logical_height = max(270, floor(window_height / 2))
```

Reference mapping:

| Window | Logical viewport | Pixel scale |
|---:|---:|---:|
| 960×540 | 480×270 | 2× |
| 1280×720 | 640×360 | 2× |
| 1280×800 | 640×400 | 2× |
| 1366×768 | 683×384 | 2× |
| 1600×900 | 800×450 | 2× |
| 1920×1080 | 960×540 | 2× |

The window-size check runs cheaply and only recalculates content scaling when the native dimensions change. This is deliberate: the root Window's `size_changed` signal is not reliable when the project uses viewport stretch mode.

The Settings autoload emits `content_viewport_resized` after a real logical viewport change. HUD and technology UI subscribe to that event. The HUD keeps its established logical dimensions and edge anchors; the optional JOBS drawer remains on the upper-right side, while the build/combat controls remain in the lower band. The central playfield grows with the viewport.

## Non-goals and compatibility

- Do not alter Camera2D zoom, player movement speed, attack ranges, tile size, collision, world dimensions, pathfinding, faction balance or campaign timing.
- Do not change save data or save version. This is a presentation-only change.
- Do not switch to non-integer pixel scaling or stretch sprite proportions.
- Do not add automatic zoom controls; the selected display resolution is the viewport control.
- Keep the 960×540 minimum window and all existing 16:9 / 16:10 / 4:3 window presets.

## Verification

`tests/responsive_layout.gd` verifies all six mappings, the live window-to-content-size relationship, unchanged camera zoom, HUD reflow, a minimum central safe-playfield height, and map/hotbar/overlay bounds. The existing Godot CI matrix must pass import, parse and all assertion suites on Godot 4.3 and 4.7.

CI cannot validate the visual result on the owner's physical display. Manual review remains required at the listed resolutions and in fullscreen, particularly during combat when the JOBS drawer, boss strip and transient banners are visible.
