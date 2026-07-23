#!/usr/bin/env bash
set -euo pipefail

docker_cmd="${DOCKER:-docker}"
openroad_image="${OPENROAD_IMAGE:-ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0}"
ngspice_image="${NGSPICE_IMAGE:-ghcr.io/arcadia-1/circuit-bench-ngspice-sky130:1.0.0}"
expected_ngspice_version="${EXPECTED_NGSPICE_VERSION:-39}"

"$docker_cmd" pull "$openroad_image"
"$docker_cmd" run --rm "$openroad_image" bash -lc '
  set -euo pipefail
  openroad -version
  iverilog -V >/tmp/iverilog-version 2>&1
  grep -q "Icarus Verilog version 14.0" /tmp/iverilog-version
  python3 --version
  test -d "$ASAP7_PLATFORM_DIR/lib/NLDM"
  test -d "$ASAP7_PLATFORM_DIR/lef"
'

"$docker_cmd" pull "$ngspice_image"
"$docker_cmd" run --rm \
  -e EXPECTED_NGSPICE_VERSION="$expected_ngspice_version" \
  "$ngspice_image" bash -lc '
  set -euo pipefail
  ngspice --version | grep -q "ngspice-${EXPECTED_NGSPICE_VERSION}"
  python3 --version
  test -s "$SKY130_MODEL_LIB"
'

printf '%s\n' "All Circuit-Bench toolchain smoke checks passed."
