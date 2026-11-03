# Phase 10 — Resolution-Matched Viewport and HUD Safe Area

**Status:** Implementation merged through PR #30 into `main`; mainline workflow #294 passed 44/44 jobs. Manual physical-display screenshots and fullscreen playtest remain open.  
**Mainline:** `main`  
**Engine target:** Godot 4.7 only

## Problem

The previous fixed 480×270 logical viewport enlarged the same small world view at every display resolution. At 1280×720, the player still saw only 480×270 logical pixels. Changing Camera2D zoom would also shrink tiles and alter apparent combat distances.

## Design

The root Window's `content_scale_size` follows half the actual client-window size:

```text
logical_width  = max(480, floor(window_width  / 2))
logical_height = max(270, floor(window_height / 2))
```

| Window | Logical viewport | Pixel scale |
|---:|---:|---:|
| 960×540 | 480×270 | 2× |
| 1280×720 | 640×360 | 2× |
| 1280×800 | 640×400 | 2× |
| 1366×768 | 683×384 | 2× |
| 1600×900 | 800×450 | 2× |
| 1920×1080 | 960×540 | 2× |

Settings polls the inexpensive native window-size value and only updates the content viewport when dimensions change. It emits `content_viewport_resized`; HUD and technology UI subscribe to that event instead of relying solely on the root Window resize signal.

HUD stays in logical-pixel top/bottom bands. The central playfield expands as resolution increases. Camera zoom, tile dimensions, movement, combat ranges, world size, campaign balance and save schema do not change.

## Verification

`tests/responsive_layout.gd` covers all six mappings, live synchronization, unchanged camera zoom, HUD reflow, minimum central playfield height and map/hotbar bounds. Godot 4.7 CI and manual rendered gameplay at target resolutions/fullscreen are required before merge.
