#!/usr/bin/env bash
# Verifies the two things this image exists to combine: the current ORFS tools,
# and the ASAP7 runtime contract with a working simulator. It checks that each
# tool resolves to the intended copy, not merely that some version is present --
# a graft like this fails by resolving to the wrong one, silently.
set -euo pipefail

test_root="${TEST_ROOT:-/opt/circuit-bench-toolchain-tests}"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

echo "== tool versions and resolution =="
openroad -version | grep -q '^26Q3-'
verilator --version | grep -q 'Verilator 5.050'
yosys -V | grep -q '0.68'
iverilog -V | head -1 | grep -q 'version 14'
test "$(command -v openroad)"  = /opt/cb-unified/bin/openroad
test "$(command -v verilator)" = /opt/verilator/bin/verilator
test "$(command -v iverilog)"  = /opt/oss-cad-suite/bin/iverilog
test "$(command -v vvp)"       = /opt/oss-cad-suite/bin/vvp

echo "== both Python environments =="
/opt/oss-cad-suite/py3bin/python3.11 -c \
  'import cocotb; assert cocotb.__version__.startswith("2.1"), cocotb.__version__'
/opt/circuit-bench-digital-venv/bin/python3 -c \
  'import sys, cocotb, numpy, scipy
assert sys.version.startswith("3.12"), sys.version
assert cocotb.__version__ == "2.0.1", cocotb.__version__'

echo "== the ASAP7 runtime contract the task corpus references by path =="
test -d /opt/orfs/flow/platforms/asap7/verilog/stdcell
# The sequential liberty is the one file in this directory that is not gzipped.
# A *.lib.gz glob silently drops every flip-flop model and report_power still
# returns a well-formed table, so the asymmetry is asserted rather than assumed.
test -f /opt/orfs/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib
test -f /opt/orfs/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_SIMPLE_RVT_TT_nldm_211120.lib.gz

echo "== simulate =="
cd "$work_dir"
printf '%s\n' \
  'module m(input logic clk, input logic [3:0] a, output logic [4:0] y);' \
  '  always_ff @(posedge clk) y <= a + 1;' \
  'endmodule' > m.sv
printf '%s\n' \
  'module tb; reg clk=0; reg [3:0] a=7; wire [4:0] y;' \
  '  m u(.clk(clk), .a(a), .y(y));' \
  '  initial begin #1 clk=1; #1 if (y !== 5'"'"'d8) $fatal(1, "got %0d", y); $display("SIM_OK"); $finish; end' \
  'endmodule' > tb.v
iverilog -g2012 -o a.out m.sv tb.v
vvp a.out | grep -q SIM_OK

echo "== lint =="
verilator --lint-only --timing -Wall \
  -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-DECLFILENAME m.sv

echo "== OpenROAD reads the ASAP7 technology =="
printf '%s\n' \
  'read_lef /opt/orfs/flow/platforms/asap7/lef/asap7_tech_1x_201209.lef' \
  'read_liberty /opt/orfs/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib' \
  'puts "ORD_OK"' > ord.tcl
openroad -no_init -exit ord.tcl | grep -q ORD_OK

echo "ASAP7_COCOTB_SMOKE_OK"
