#!/usr/bin/env python3
"""Validate authored civilian atlases and reproducible legacy enemy sheets."""
from __future__ import annotations

import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "tools" / "gen_assets.py"
OUTPUT = ROOT / "build" / "generated-role-sprites"

HAND_AUTHORED_SPRITES = (
    "villager_idle.svg",
    "villager_woodcutter.svg",
    "villager_miner.svg",
    "villager_farmer.svg",
    "villager_builder.svg",
    "villager_hunter.svg",
    "villager_scout.svg",
    "villager_healer.svg",
    "villager_blacksmith.svg",
    "villager_soldier.svg",
)
REPRODUCIBLE_SPRITES = (
    "enemy_archer.svg",
    "enemy_brute.svg",
)


def validate_authored_svg(path: Path) -> list[str]:
    failures: list[str] = []
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as exc:
        return [f"{path.name}: invalid SVG/XML ({exc})"]

    expected = {"width": "440", "height": "60", "viewBox": "0 0 440 60"}
    for key, value in expected.items():
        if root.attrib.get(key) != value:
            failures.append(f"{path.name}: {key} must be {value!r}, got {root.attrib.get(key)!r}")
    if root.attrib.get("shape-rendering") != "crispEdges":
        failures.append(f"{path.name}: missing shape-rendering=crispEdges")

    elements = list(root.iter())
    forbidden = {"image", "filter", "linearGradient", "radialGradient", "foreignObject"}
    for element in elements:
        tag = element.tag.rsplit("}", 1)[-1]
        if tag in forbidden:
            failures.append(f"{path.name}: forbidden SVG element <{tag}>")
        if tag == "rect":
            for attr in ("x", "y", "width", "height"):
                value = element.attrib.get(attr, "0")
                if not re.fullmatch(r"-?\\d+", value):
                    failures.append(f"{path.name}: rect {attr}={value!r} is not integer-grid aligned")
                    break
        if tag == "polygon":
            points = element.attrib.get("points", "")
            if not re.fullmatch(r"\\s*-?\\d+,-?\\d+(?:\\s+-?\\d+,-?\\d+)*\\s*", points):
                failures.append(f"{path.name}: polygon points are not integer-grid aligned")

    top_level_frames = [node for node in list(root) if node.tag.rsplit("}", 1)[-1] == "g"]
    if len(top_level_frames) != 66:
        failures.append(f"{path.name}: expected 66 frame groups (22 frames × 3 directions), got {len(top_level_frames)}")
    return failures


def main() -> int:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["HTK_ASSET_OUTPUT_DIR"] = str(OUTPUT)
    result = subprocess.run(
        [sys.executable, str(GENERATOR)],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.returncode != 0:
        print(result.stdout)
        print("FAIL: legacy asset generator exited non-zero")
        return result.returncode

    failures: list[str] = []
    for filename in HAND_AUTHORED_SPRITES:
        committed = ROOT / "assets" / "sprites" / filename
        if not committed.is_file():
            failures.append(f"{filename}: hand-authored source is missing")
            continue
        failures.extend(validate_authored_svg(committed))

    for filename in REPRODUCIBLE_SPRITES:
        generated = OUTPUT / filename
        committed = ROOT / "assets" / "sprites" / filename
        if not generated.is_file() or not committed.is_file():
            failures.append(f"{filename}: generated or committed file is missing")
            continue
        if generated.read_bytes() != committed.read_bytes():
            failures.append(f"{filename}: legacy generator output is not byte-for-byte reproducible")

    generator_source = GENERATOR.read_text(encoding="utf-8")
    if 'PROTECTED_AUTHORED_ASSETS = {' not in generator_source:
        failures.append("legacy generator must keep a protected hand-authored asset registry")
    for filename in HAND_AUTHORED_SPRITES:
        sprite_name = filename.removesuffix(".svg")
        if f'"{sprite_name}"' not in generator_source:
            failures.append(f"{sprite_name}: missing from legacy generator ownership registry")
        if f'humanoid_sheet("{sprite_name}"' in generator_source:
            failures.append(f"{sprite_name}: still owned by generic humanoid renderer")

    if failures:
        print("FAIL: civilian atlas validation:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print(
        "PASS: 10 hand-authored civilian SVGs satisfy 440x60/22x3 integer-grid contracts; "
        "legacy enemy archer/brute outputs remain byte-for-byte reproducible"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
