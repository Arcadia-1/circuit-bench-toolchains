#!/usr/bin/env bash
set -euo pipefail

test_root="${TEST_ROOT:-/opt/circuit-bench-toolchain-tests}"
orfs_root="${ORFS_ROOT:-/OpenROAD-flow-scripts}"
rtl_file="$orfs_root/flow/designs/src/gcd/gcd.v"
testbench_file="$test_root/gcd-coverage-tb.sv"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

test -f "$rtl_file"
test -f "$testbench_file"

cd "$work_dir"
verilator \
  --binary \
  --timing \
  --timescale 1ns/1ps \
  --coverage \
  -Wno-BADVLTPRAGMA \
  -Wno-LATCH \
  --top-module gcd_coverage_tb \
  "$rtl_file" \
  "$testbench_file"

./obj_dir/Vgcd_coverage_tb +verilator+coverage+file+coverage.dat
test -s coverage.dat

verilator_coverage --write-info coverage.info coverage.dat
test -s coverage.info
verilator_coverage --annotate annotated coverage.dat

printf '%s\n' 'Uncovered DUT coverage points:'
perl -ne '
  next unless / 0$/;
  my %field;
  while (/\x01([^\x02]+)\x02([^\x01]*)/g) {
    $field{$1} = $2;
  }
  printf "  %-7s %s:%s:%s  %s\n",
    ($field{t} // "unknown"),
    ($field{f} // "unknown"),
    ($field{l} // "?"),
    ($field{n} // "?"),
    ($field{o} // "unknown");
' coverage.dat
