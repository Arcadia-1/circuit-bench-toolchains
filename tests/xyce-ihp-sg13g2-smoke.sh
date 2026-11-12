#!/usr/bin/env bash
# Run inside the IHP SG13G2 Xyce image with this directory mounted at $TEST_ROOT (default /smoke).
set -euo pipefail

test_root="${TEST_ROOT:-/smoke}"

Xyce -v | grep -F "Xyce Release 7.10.0"
test ! -e /usr/local/bin/check_circuit.py
test "${IHP_PDK_ROOT}" = /opt/ihp/pdk/ihp-sg13g2
for plugin in $(echo "${IHP_XYCE_PLUGINS}" | tr , ' '); do
  test -s "${plugin}"
done

work=$(mktemp -d)
cp "${test_root}"/xyce-ihp-sg13g2-smoke-dc.cir "${test_root}"/xyce-ihp-sg13g2-smoke-tran.cir "${work}/"
cd "${work}"
for deck in xyce-ihp-sg13g2-smoke-dc.cir xyce-ihp-sg13g2-smoke-tran.cir; do
  Xyce -plugin "${IHP_XYCE_PLUGINS}" "${deck}" > "${deck}.log" 2>&1 \
    || { cat "${deck}.log" >&2; exit 1; }
done

python3 - <<'PY'
import numpy as np

dc = np.genfromtxt("xyce-ihp-sg13g2-smoke-dc.cir.csv", delimiter=",", names=True)
out, outh, rmid, qb, da, i_vdd = (float(dc[n]) for n in ("VOUT", "VOUTH", "VRMID", "VQB", "VDA", "IVDD"))
tr = np.genfromtxt("xyce-ihp-sg13g2-smoke-tran.cir.csv", delimiter=",", names=True)
t, vout = tr["TIME"], tr["VOUT"]
before = float(np.interp(0.9e-9, t, vout))
after = float(np.interp(2.5e-9, t, vout))
checks = {
    "1.2 V inverter output high": out > 1.15,
    "3.3 V inverter output low": outh < 0.05,
    "rsil divider at half supply": 0.57 < rmid < 0.63,
    "npn13G2 base-emitter voltage": 0.60 < qb < 1.00,
    "antenna diode forward voltage": 0.40 < da < 0.90,
    "supply delivers current": i_vdd < 0,
    "pulsed inverter high before the edge": before > 1.10,
    "pulsed inverter low after the edge": after < 0.10,
}
failed = [name for name, ok in checks.items() if not ok]
print(f"out={out:.4f} outh={outh:.4f} rmid={rmid:.4f} qb={qb:.4f} da={da:.4f} "
      f"i_vdd={i_vdd:.3e} tran_high={before:.4f} tran_low={after:.4f}")
if failed:
    raise SystemExit("IHP SG13G2 Xyce smoke checks failed: " + ", ".join(failed))
print("IHP SG13G2 Xyce smoke checks passed.")
PY
