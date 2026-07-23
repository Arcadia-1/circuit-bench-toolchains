#!/usr/bin/env bash
set -euo pipefail

docker_cmd="${DOCKER:-docker}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
openroad_image="${OPENROAD_IMAGE:-ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0}"
ngspice_image="${NGSPICE_IMAGE:-ghcr.io/arcadia-1/circuit-bench-sky130-ngspice:2.0.2}"
expected_ngspice_version="${EXPECTED_NGSPICE_VERSION:-46}"

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
  --workdir /opt/sky130/continuous \
  -e EXPECTED_NGSPICE_VERSION="$expected_ngspice_version" \
  -v "$script_dir/tests:/smoke:ro" \
  "$ngspice_image" bash -lc '
  set -euo pipefail
  /opt/ngspice/bin/ngspice --version | grep -q "ngspice-${EXPECTED_NGSPICE_VERSION}"
  python3 --version
  python3 -c "import numpy"
  test -s "$SKY130_MODEL_LIB"
  test -d "$SKY130_PDK_ROOT/libs.tech/ngspice"
  test -d "$SKY130_PDK_ROOT/libs.ref/sky130_fd_pr/spice"
  /opt/ngspice/bin/ngspice -b -o /dev/stdout /smoke/ngspice-sky130-smoke.spice
  /opt/ngspice/bin/ngspice -b -o /dev/stdout /smoke/ngspice-sky130-full-pdk-smoke.spice
'

printf '%s\n' "All Circuit-Bench toolchain smoke checks passed."
