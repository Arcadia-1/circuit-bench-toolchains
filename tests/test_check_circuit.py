#!/usr/bin/env python3
"""Regression tests for the public Sky130 netlist eligibility gate."""

import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHECKER = Path(
    os.environ.get(
        "CHECK_CIRCUIT",
        ROOT / "tools" / "netlist_checker" / "check_circuit.py",
    )
)
PDK_DEVICE = "sky130_fd_pr__nfet_01v8"


class CheckerTest(unittest.TestCase):
    def run_checker(self, body: str, *arguments: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            circuit = root / "circuit.spi"
            pdk_list = root / "pdk.txt"
            circuit.write_text(textwrap.dedent(body).lstrip())
            pdk_list.write_text(f"{PDK_DEVICE}\n")
            environment = os.environ.copy()
            environment["SKY130_PDK_SUBCIRCUITS"] = str(pdk_list)
            return subprocess.run(
                [str(CHECKER), str(circuit), *arguments],
                check=False,
                capture_output=True,
                text=True,
                env=environment,
            )

    def assert_rejected(self, body: str, reason: str, *arguments: str) -> None:
        result = self.run_checker(body, *arguments)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(reason, result.stdout)

    def test_valid_pdk_hierarchy_and_positive_ideal_values_pass(self) -> None:
        result = self.run_checker(
            """
            .subckt leaf vss vin vout
            X1 vout vin vss vss sky130_fd_pr__nfet_01v8 L=0.15 W=2 nf=2
            R1 vout vss 10k tc1=-0.003
            C1 vout vss 1.5p
            .ends leaf
            .subckt top vss vin vout
            XLEAF vss vin vout leaf
            .ends top
            """,
            "--allow-ideal",
            "R",
            "C",
        )
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_all_unpublished_dot_directives_are_rejected(self) -> None:
        for directive in (
            ".include secret.spi",
            ".lib models.lib tt",
            ".model rogue nmos level=1",
            ".param width=1",
            ".control",
            ".measure tran reward param=1",
            ".tran 1n 10n",
            ".ac dec 10 1 1g",
            ".op",
            ".save all",
            ".option savecurrents",
            ".end",
        ):
            with self.subTest(directive=directive):
                self.assert_rejected(
                    f"""
                    .subckt dut vss vin vout
                    X1 vout vin vss vss {PDK_DEVICE} L=0.15 W=1
                    {directive}
                    .ends dut
                    """,
                    "disallowed directive",
                )

    def test_sources_and_switches_are_rejected(self) -> None:
        for element in (
            "V1 vout vss 1",
            "I1 vout vss 1u",
            "E1 vout vss vin vss 1",
            "G1 vout vss vin vss 1m",
            "F1 vout vss VSENSE 1",
            "H1 vout vss VSENSE 1",
            "B1 vout vss V=1",
            "S1 vout vss vin vss rogue",
        ):
            with self.subTest(element=element):
                self.assert_rejected(
                    f"""
                    .subckt dut vss vin vout
                    X1 vout vin vss vss {PDK_DEVICE} L=0.15 W=1
                    {element}
                    .ends dut
                    """,
                    f"disallowed {element[0]}",
                )

    def test_nonpositive_nonfinite_and_expression_ideal_values_are_rejected(self) -> None:
        for value in ("0", "-1", "nan", "inf", "1e999", "{value}", "1banana"):
            with self.subTest(value=value):
                expected = "must be positive" if value in {"0", "-1"} else "not a finite numeric literal"
                self.assert_rejected(
                    f"""
                    .subckt dut vss vin vout
                    R1 vout vss {value}
                    .ends dut
                    """,
                    expected,
                    "--allow-ideal",
                    "R",
                )

    def test_invalid_instance_parameters_are_rejected(self) -> None:
        for parameter, reason in (
            ("W=nan", "not a finite numeric literal"),
            ("L=inf", "not a finite numeric literal"),
            ("W={width}", "not a finite numeric literal"),
            ("nf=0", "parameter nf must be positive"),
            ("m=-1", "parameter m must be positive"),
            ("ad=-1", "parameter ad must be non-negative"),
        ):
            with self.subTest(parameter=parameter):
                self.assert_rejected(
                    f"""
                    .subckt dut vss vin vout
                    X1 vout vin vss vss {PDK_DEVICE} L=0.15 W=1 {parameter}
                    .ends dut
                    """,
                    reason,
                )

    def test_elements_must_be_inside_a_subcircuit(self) -> None:
        self.assert_rejected(
            f"""
            XTOP vout vin vss vss {PDK_DEVICE} L=0.15 W=1
            .subckt dut vss vin vout
            X1 vout vin vss vss {PDK_DEVICE} L=0.15 W=1
            .ends dut
            """,
            "element outside subcircuit",
        )

    def test_subcircuit_boundaries_must_be_well_formed(self) -> None:
        cases = (
            (".ends dut", ".ends outside subcircuit"),
            (f".subckt dut a b\nX1 a b b b {PDK_DEVICE} L=0.15 W=1", "missing .ends"),
            (
                f".subckt dut a b\nX1 a b b b {PDK_DEVICE} L=0.15 W=1\n.ends other",
                ".ends name does not match",
            ),
        )
        for body, reason in cases:
            with self.subTest(reason=reason):
                self.assert_rejected(body, reason)


if __name__ == "__main__":
    unittest.main(verbosity=2)
