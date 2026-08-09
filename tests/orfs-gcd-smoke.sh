#!/usr/bin/env bash
set -euo pipefail

: "${FLOW_HOME:=/OpenROAD-flow-scripts/flow}"
cd "$FLOW_HOME"
make DESIGN_CONFIG=./designs/asap7/gcd/config.mk
test -s results/asap7/gcd/base/6_final.gds
