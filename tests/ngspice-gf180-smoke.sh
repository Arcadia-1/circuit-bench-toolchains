#!/usr/bin/env bash
# Run inside the GF180 image with this directory mounted at $TEST_ROOT (default /smoke).
set -euo pipefail

test_root="${TEST_ROOT:-/smoke}"
expected_ngspice_version="${EXPECTED_NGSPICE_VERSION:-46}"

test "$(command -v ngspice)" = /opt/ngspice/bin/ngspice
ngspice --version | grep -F "ngspice-${expected_ngspice_version}"
python3 -c 'import numpy'
test ! -e /usr/local/bin/check_circuit.py
test "${GF180_PDK_ROOT}" = /opt/gf180/pdk/gf180mcuD
for variant in A B C D; do
  for model in design.ngspice sm141064.ngspice sm141064_mim.ngspice smbb000149.ngspice; do
    test -s "/opt/gf180/pdk/gf180mcu${variant}/libs.tech/ngspice/${model}"
  done
done

rm -f /tmp/gf180-smoke.dat
ngspice -b -o /tmp/gf180-smoke.log "${test_root}/ngspice-gf180-smoke.spice"
if grep -qiE '^error|fatal' /tmp/gf180-smoke.log; then
  cat /tmp/gf180-smoke.log >&2
  exit 1
fi

python3 - <<'PY'
import numpy as np

# Columns: scale, v(out), v(out6), v(rmid), v(qe), v(da), i(VDD).
row = np.loadtxt("/tmp/gf180-smoke.dat", skiprows=1, ndmin=2)[0]
out, out6, rmid, qe, da, i_vdd = row[1:7]
checks = {
    "3.3 V inverter output high": out > 3.25,
    "6 V inverter output low": out6 < 0.05,
    "poly divider at half supply": 1.60 < rmid < 1.70,
    "PNP base-emitter voltage": 0.40 < qe < 0.90,
    "P+/Nwell diode forward voltage": 0.40 < da < 0.90,
    "supply delivers current": i_vdd < 0,
}
failed = [name for name, ok in checks.items() if not ok]
print(f"out={out:.4f} out6={out6:.4f} rmid={rmid:.4f} qe={qe:.4f} da={da:.4f} i_vdd={i_vdd:.3e}")
if failed:
    raise SystemExit("GF180 smoke checks failed: " + ", ".join(failed))
print("GF180 ngspice smoke checks passed.")
PY
