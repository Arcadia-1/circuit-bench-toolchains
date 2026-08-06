#!/usr/bin/env python3
"""Check that a circuit uses approved PDK and ideal elements."""

import argparse
import math
import os
import re
from pathlib import Path


IDEAL_ELEMENTS = {"R", "C", "L"}
ALLOWED_DIRECTIVES = {".subckt", ".ends"}
SOURCE_PDK_LIST = Path(__file__).with_name("sky130_pdk_subcircuits.txt")
NUMBER_RE = re.compile(
    r"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?[a-z]*$",
    re.IGNORECASE,
)
SCALE_FACTORS = {
    "t": 1e12,
    "g": 1e9,
    "meg": 1e6,
    "k": 1e3,
    "m": 1e-3,
    "u": 1e-6,
    "n": 1e-9,
    "p": 1e-12,
    "f": 1e-15,
    "mil": 25.4e-6,
}
POSITIVE_PARAMETERS = {"l", "w", "nf", "m", "mult", "mf"}
NONNEGATIVE_PARAMETERS = {"ad", "as", "pd", "ps"}


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


def spice_number(token: str) -> float | None:
    """Parse a finite SPICE numeric literal without evaluating expressions."""
    value = token.strip().lower()
    if not NUMBER_RE.fullmatch(value):
        return None
    match = re.match(
        r"^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?)([a-z]*)$",
        value,
    )
    if match is None:
        return None
    number_text, suffix = match.groups()
    scale = 1.0
    matched_suffix = not suffix
    for prefix in ("meg", "mil", "t", "g", "k", "m", "u", "n", "p", "f"):
        if suffix.startswith(prefix):
            scale = SCALE_FACTORS[prefix]
            matched_suffix = True
            break
    if not matched_suffix:
        return None
    try:
        number = float(number_text) * scale
    except ValueError:
        return None
    return number if math.isfinite(number) else None


def assignment_violations(words: list[str]) -> list[str]:
    violations = []
    for word in words:
        if "=" not in word:
            continue
        name, value_text = word.split("=", 1)
        name = name.lower()
        value = spice_number(value_text)
        if not name or value is None:
            violations.append(f"parameter {word} is not a finite numeric literal")
        elif name in POSITIVE_PARAMETERS and value <= 0:
            violations.append(f"parameter {name} must be positive")
        elif name in NONNEGATIVE_PARAMETERS and value < 0:
            violations.append(f"parameter {name} must be non-negative")
    return violations


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
    seen_subcircuits = set()

    for name in sorted(local_subcircuits & pdk_subcircuits):
        violations.append((0, f"local subcircuit shadows PDK name {name}", name))

    for number, text in lines:
        if not text or text[0] in "*;":
            continue
        if text.startswith("."):
            words = text.split()
            directive = words[0].lower()
            if directive not in ALLOWED_DIRECTIVES:
                violations.append((number, f"disallowed directive {directive}", text))
            elif directive == ".subckt":
                if len(words) < 2:
                    violations.append((number, "malformed .subckt", text))
                elif current_subcircuit is not None:
                    violations.append((number, "nested .subckt", text))
                elif words[1].lower() in seen_subcircuits:
                    violations.append((number, "duplicate .subckt", text))
                else:
                    current_subcircuit = words[1].lower()
                    seen_subcircuits.add(current_subcircuit)
                    for reason in assignment_violations(words[2:]):
                        violations.append((number, reason, text))
            elif current_subcircuit is None:
                violations.append((number, ".ends outside subcircuit", text))
            else:
                if len(words) > 1 and words[1].lower() != current_subcircuit:
                    violations.append((number, ".ends name does not match .subckt", text))
                current_subcircuit = None
            continue
        kind = text[0].upper()
        if current_subcircuit is None:
            violations.append((number, "element outside subcircuit", text))
        if kind not in allowed_elements:
            violations.append((number, f"disallowed {kind}", text))
        elif kind == "X":
            target = x_target(text)
            for reason in assignment_violations(text.split()[1:]):
                violations.append((number, reason, text))
            if target in local_subcircuits:
                if current_subcircuit:
                    local_references[current_subcircuit].add(target)
            elif target in pdk_subcircuits:
                if current_subcircuit:
                    has_leaf[current_subcircuit] = True
            else:
                violations.append((number, f"unknown subcircuit {target or '?'}", text))
        else:
            words = text.split()
            if len(words) < 4:
                violations.append((number, f"malformed {kind}", text))
            else:
                value = spice_number(words[3])
                if value is None:
                    violations.append((number, f"{kind} value is not a finite numeric literal", text))
                elif value <= 0:
                    violations.append((number, f"{kind} value must be positive", text))
                for reason in assignment_violations(words[4:]):
                    violations.append((number, reason, text))
            if current_subcircuit:
                has_leaf[current_subcircuit] = True

    if current_subcircuit is not None:
        violations.append((0, f"subcircuit {current_subcircuit} is missing .ends", current_subcircuit))

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
