#!/usr/bin/env bash
set -euo pipefail

test_root="${TEST_ROOT:-/opt/circuit-bench-toolchain-tests}"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

cd "$work_dir"
verilator --binary --timing --coverage --top-module coverage_smoke \
  "$test_root/verilator-coverage-smoke.sv"
./obj_dir/Vcoverage_smoke +verilator+coverage+file+coverage.dat

test -s coverage.dat
verilator_coverage --write-info coverage.info coverage.dat
test -s coverage.info
grep -q '^DA:' coverage.info
