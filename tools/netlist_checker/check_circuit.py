#!/usr/bin/env python3
"""Check that a circuit uses approved PDK and ideal elements."""

import argparse
import os
from pathlib import Path


IDEAL_ELEMENTS = {"R", "C", "L", "S"}
SOURCE_PDK_LIST = Path(__file__).with_name("sky130_pdk_subcircuits.txt")


def logical_lines(path: Path):
    lines = []
    for number, raw in enumerate(path.read_text().splitlines(), 1):
        text = raw.split("$", 1)[0].split(";", 1)[0].strip()
        if text.startswith("+") and lines:
            lines[-1] = (lines[-1][0], f"{lines[-1][1]} {text[1:].strip()}")
        else:
            lines.append((number, text))
    return lines


def x_target(text: str) -> str:
    target = ""
    for word in text.split()[1:]:
        if word.lower() == "params:" or "=" in word:
            break
        target = word
    return target.lower()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("circuit", type=Path)
    parser.add_argument(
        "--allow-ideal",
        nargs="*",
        choices=sorted(IDEAL_ELEMENTS),
        default=(),
        metavar="ELEMENT",
    )
    args = parser.parse_args()

    pdk_list = Path(os.environ.get("SKY130_PDK_SUBCIRCUITS", SOURCE_PDK_LIST))
    pdk_subcircuits = set(pdk_list.read_text().split())
    lines = logical_lines(args.circuit)
    local_subcircuits = {
        text.split()[1].lower()
        for _, text in lines
        if text.lower().startswith(".subckt ") and len(text.split()) > 1
    }
    allowed_elements = {"X", *args.allow_ideal}
    local_references = {name: set() for name in local_subcircuits}
    has_leaf = {name: False for name in local_subcircuits}
    violations = []
    current_subcircuit = None

    for name in sorted(local_subcircuits & pdk_subcircuits):
        violations.append((0, f"local subcircuit shadows PDK name {name}", name))

    for number, text in lines:
        lower = text.lower()
        if lower.startswith(".subckt "):
            current_subcircuit = lower.split()[1]
            continue
        if lower.startswith(".ends"):
            current_subcircuit = None
            continue
        if not text or text[0] in "*;.":
            continue
        kind = text[0].upper()
        if kind not in allowed_elements:
            violations.append((number, f"disallowed {kind}", text))
        elif kind == "X":
            target = x_target(text)
            if target in local_subcircuits:
                if current_subcircuit:
                    local_references[current_subcircuit].add(target)
            elif target in pdk_subcircuits:
                if current_subcircuit:
                    has_leaf[current_subcircuit] = True
            else:
                violations.append((number, f"unknown subcircuit {target or '?'}", text))
        elif current_subcircuit:
            has_leaf[current_subcircuit] = True

    resolved = {}

    def resolves(name: str, visiting=frozenset()) -> bool:
        if name in resolved:
            return resolved[name]
        if name in visiting:
            return False
        children_resolve = all(
            resolves(child, visiting | {name})
            for child in local_references[name]
        )
        resolved[name] = children_resolve and (
            has_leaf[name] or bool(local_references[name])
        )
        return resolved[name]

    for name in sorted(local_subcircuits):
        if not resolves(name):
            violations.append((0, f"subcircuit {name} has no approved leaf", name))

    for number, reason, text in violations:
        location = f"{args.circuit}:{number}" if number else str(args.circuit)
        print(f"{location}: {reason}: {text}")
    if violations:
        return 1
    print(f"{args.circuit}: netlist check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
