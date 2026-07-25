#!/usr/bin/env python3
"""Build Gothic A1 containers that trigger Seers Isle's 4096px TMP atlas."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import shutil
from pathlib import Path


MIN_RUNTIME_SIZE = 524_288
MAX_RUNTIME_SIZE = 16_777_216
DEFAULT_TARGET_SIZE = MAX_RUNTIME_SIZE


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def loader_parameters(size: int) -> dict[str, int | float]:
    factor = max(
        0.0,
        min(
            1.0,
            (size - MIN_RUNTIME_SIZE)
            / (MAX_RUNTIME_SIZE - MIN_RUNTIME_SIZE),
        ),
    )
    return {
        "file_size": size,
        "inverse_lerp_factor": factor,
        "sampling_point_size": math.floor(96 + (56 - 96) * factor),
        "atlas_width": 1 << round(10 + (12 - 10) * factor * factor),
        "atlas_height": 1 << round(10 + (12 - 10) * factor * factor),
        "atlas_padding": math.floor(10 + (5 - 10) * factor),
        "population_mode": "Dynamic",
    }


def font_record(path: Path) -> dict[str, object]:
    return {
        "path": str(path),
        "size": path.stat().st_size,
        "sha256": sha256(path),
    }


def build_font(source: Path, destination: Path, target_size: int) -> dict:
    source_data = source.read_bytes()
    if source_data[:4] not in {
        b"\x00\x01\x00\x00",
        b"OTTO",
        b"true",
        b"typ1",
    }:
        raise ValueError(f"Not an SFNT font: {source}")
    if len(source_data) > target_size:
        raise ValueError(
            f"Source is larger than target container: {source} "
            f"({len(source_data)} > {target_size})"
        )
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(
        source_data + b"\0" * (target_size - len(source_data))
    )
    output_data = destination.read_bytes()
    if output_data[: len(source_data)] != source_data:
        raise ValueError(f"Font prefix changed while building: {destination}")
    if any(output_data[len(source_data) :]):
        raise ValueError(f"Font padding is not all zero: {destination}")
    return {
        "source": font_record(source),
        "output": font_record(destination),
        "source_prefix_preserved": True,
        "trailing_zero_bytes": target_size - len(source_data),
        "runtime_loader": loader_parameters(target_size),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--regular-source", required=True, type=Path)
    parser.add_argument("--bold-source", required=True, type=Path)
    parser.add_argument("--license-source", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument(
        "--target-size",
        type=int,
        default=DEFAULT_TARGET_SIZE,
    )
    args = parser.parse_args()

    if args.target_size != MAX_RUNTIME_SIZE:
        raise ValueError(
            "This verified build requires exactly 16,777,216 bytes so the "
            "game selects a 4096x4096 atlas."
        )

    output = args.output_dir.resolve()
    regular_output = output / "GothicA1-Regular.ttf"
    bold_output = output / "GothicA1-Bold.ttf"
    license_output = output / "OFL.txt"
    report = {
        "format": 1,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "strategy": "preserve_sfnt_bytes_and_append_zero_padding",
        "reason": (
            "Seers Isle derives TextMeshPro atlas dimensions from the font "
            "file length. The original Gothic A1 files select a 1024px atlas, "
            "which saturates and drops Korean syllables. A 16 MiB container "
            "selects the game's maximum 4096px atlas without changing the "
            "licensed font tables or glyph data."
        ),
        "target_size": args.target_size,
        "regular": build_font(
            args.regular_source.resolve(),
            regular_output,
            args.target_size,
        ),
        "bold": build_font(
            args.bold_source.resolve(),
            bold_output,
            args.target_size,
        ),
    }
    output.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.license_source.resolve(), license_output)
    report["license"] = font_record(license_output)

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "output_dir": str(output),
                "report": str(args.report),
                "report_sha256": sha256(args.report),
                "regular": report["regular"]["output"],
                "bold": report["bold"]["output"],
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
