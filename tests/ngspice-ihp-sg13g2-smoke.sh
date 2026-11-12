#!/usr/bin/env bash
# Run inside the IHP SG13G2 ngspice image with this directory mounted at $TEST_ROOT (default /smoke).
set -euo pipefail

test_root="${TEST_ROOT:-/smoke}"
expected_ngspice_version="${EXPECTED_NGSPICE_VERSION:-46}"

test "$(command -v ngspice)" = /opt/ngspice/bin/ngspice
ngspice --version | grep -F "ngspice-${expected_ngspice_version}"
python3 -c 'import numpy'
test ! -e /usr/local/bin/check_circuit.py
test "${IHP_PDK_ROOT}" = /opt/ihp/pdk/ihp-sg13g2
test "${PDK_ROOT}/${PDK}" = "${IHP_PDK_ROOT}"
for model in psp103 psp103_nqs r3_cmc mosvar cap_cmomi cap_cmomf; do
  test -s "${IHP_PDK_ROOT}/libs.tech/ngspice/osdi/${model}.osdi"
done

# ngspice reads .spiceinit from the working directory; the PDK's copy sets the
# model source path and loads the OSDI models.
work=$(mktemp -d)
cp "${IHP_PDK_ROOT}/libs.tech/ngspice/.spiceinit" "${work}/"
cd "${work}"
rm -f /tmp/ihp-smoke-op.dat /tmp/ihp-smoke-tran.txt
ngspice -b -o /tmp/ihp-smoke.log "${test_root}/ngspice-ihp-sg13g2-smoke.spice"
if grep -qiE '^error|fatal' /tmp/ihp-smoke.log; then
  cat /tmp/ihp-smoke.log >&2
  exit 1
fi

python3 - <<'PY'
import numpy as np

# Columns: scale, v(out), v(outh), v(rmid), v(qb), v(da), i(VDD).
row = np.loadtxt("/tmp/ihp-smoke-op.dat", skiprows=1, ndmin=2)[0]
out, outh, rmid, qb, da, i_vdd = row[1:7]
_, vhigh, vlow = open("/tmp/ihp-smoke-tran.txt").read().split()
vhigh, vlow = float(vhigh), float(vlow)
checks = {
    "1.2 V inverter output high": out > 1.15,
    "3.3 V inverter output low": outh < 0.05,
    "rsil divider at half supply": 0.57 < rmid < 0.63,
    "npn13G2 base-emitter voltage": 0.60 < qb < 1.00,
    "antenna diode forward voltage": 0.40 < da < 0.90,
    "supply delivers current": i_vdd < 0,
    "pulsed inverter high before the edge": vhigh > 1.10,
    "pulsed inverter low after the edge": vlow < 0.10,
}
failed = [name for name, ok in checks.items() if not ok]
print(f"out={out:.4f} outh={outh:.4f} rmid={rmid:.4f} qb={qb:.4f} da={da:.4f} "
      f"i_vdd={i_vdd:.3e} tran_high={vhigh:.4f} tran_low={vlow:.4f}")
if failed:
    raise SystemExit("IHP SG13G2 smoke checks failed: " + ", ".join(failed))
print("IHP SG13G2 ngspice smoke checks passed.")
PY
