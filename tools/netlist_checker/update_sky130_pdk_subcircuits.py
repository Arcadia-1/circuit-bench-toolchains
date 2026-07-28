#!/usr/bin/env python3
"""Regenerate the official SKY130 subcircuit list from a Volare PDK tree."""

import argparse
from pathlib import Path


PDK_TREES = (
    "libs.tech/combined/continuous",
    "libs.tech/ngspice",
    "libs.ref/sky130_fd_pr/spice",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("sky130a", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).with_name("sky130_pdk_subcircuits.txt"),
    )
    args = parser.parse_args()

    names = set()
    for relative_tree in PDK_TREES:
        for model in (args.sky130a / relative_tree).rglob("*.spice"):
            for line in model.read_text(errors="replace").splitlines():
                words = line.split()
                if (
                    len(words) > 1
                    and words[0].lower() == ".subckt"
                    and words[1].lower().startswith("sky130_")
                ):
                    names.add(words[1].lower())

    args.output.write_text("\n".join(sorted(names)) + "\n")
    print(f"{args.output}: wrote {len(names)} SKY130 subcircuits")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
