#!/usr/bin/env python3
"""Generate role sprite SVGs into build/ for review and verify exact reproducibility."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "tools" / "gen_assets.py"
OUTPUT = ROOT / "build" / "generated-role-sprites"
ROLE_SPRITES = (
    "villager_builder.svg",
    "enemy_archer.svg",
    "enemy_brute.svg",
)


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
        print("FAIL: asset generator exited non-zero")
        return result.returncode

    failures: list[str] = []
    for filename in ROLE_SPRITES:
        generated = OUTPUT / filename
        committed = ROOT / "assets" / "sprites" / filename
        if not generated.is_file() or not committed.is_file():
            failures.append(f"{filename}: generated or committed file is missing")
            continue
        if generated.read_bytes() != committed.read_bytes():
            generated_bytes = generated.read_bytes()
            committed_bytes = committed.read_bytes()
            mismatch = next(
                (index for index, pair in enumerate(zip(generated_bytes, committed_bytes))
                 if pair[0] != pair[1]),
                min(len(generated_bytes), len(committed_bytes)),
            )
            failures.append(
                f"{filename}: generator output differs at byte {mismatch} "
                f"(generated={len(generated_bytes)}, committed={len(committed_bytes)})"
            )

    if failures:
        print("FAIL: role sprite assets are not reproducible:")
        for failure in failures:
            print(f" - {failure}")
        print(f"Generated candidates retained in {OUTPUT}")
        return 1

    print("PASS: Builder, Archer and Brute SVGs reproduce exactly from tools/gen_assets.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
