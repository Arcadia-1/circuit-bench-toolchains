#!/usr/bin/env bash
set -euo pipefail

docker_cmd="${DOCKER:-docker}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
openroad_image="${OPENROAD_IMAGE:-ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0}"
rtlforge_image="${RTL_FORGE_IMAGE:-ghcr.io/arcadia-1/circuit-bench-rtl-forge-openroad-asap7:1.0.0}"
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

"$docker_cmd" pull "$rtlforge_image"
"$docker_cmd" run --rm "$rtlforge_image" bash -lc '
  set -euo pipefail
  test -x "$OPENROAD_EXE"
  "$OPENROAD_EXE" -version
  yosys -V
  iverilog -V >/tmp/iverilog-version
  grep -q "Icarus Verilog version 14.0" /tmp/iverilog-version
  python3 --version
  test -d "$ASAP7_PLATFORM_DIR/lib/NLDM"
  test -d "$ASAP7_PLATFORM_DIR/lef"
  test -f "$ASAP7_PLATFORM_DIR/lef/asap7_tech_1x_201209.lef"
  test -f "$ASAP7_PLATFORM_DIR/lib/NLDM/asap7sc7p5t_SEQ_RVT_FF_nldm_220123.lib"
  ! ldd "$OPENROAD_EXE" 2>&1 | grep -F "not found"
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
