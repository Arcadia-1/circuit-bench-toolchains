#!/usr/bin/env bash
# Run inside the GF180 Xyce image with this directory mounted at $TEST_ROOT (default /smoke).
set -euo pipefail

test_root="${TEST_ROOT:-/smoke}"

Xyce -v | grep -F "Xyce Release 7.10.0"
test ! -e /usr/local/bin/check_circuit.py
test "${GF180_PDK_ROOT}" = /opt/gf180/pdk/gf180mcuD
for variant in A B C D; do
  for model in design.xyce sm141064.xyce sm141064_mim.xyce smbb000149.xyce; do
    test -s "/opt/gf180/pdk/gf180mcu${variant}/libs.tech/xyce/${model}"
  done
done

work=$(mktemp -d)
cp "${test_root}"/xyce-gf180-smoke-dc.cir "${test_root}"/xyce-gf180-smoke-tran.cir "${work}/"
cd "${work}"
for deck in xyce-gf180-smoke-dc.cir xyce-gf180-smoke-tran.cir; do
  Xyce "${deck}" > "${deck}.log" 2>&1 || { cat "${deck}.log" >&2; exit 1; }
done

python3 - <<'PY'
import numpy as np

dc = np.genfromtxt("xyce-gf180-smoke-dc.cir.csv", delimiter=",", names=True)
out, out6, rmid, qe, da, i_vdd = (float(dc[n]) for n in ("VOUT", "VOUT6", "VRMID", "VQE", "VDA", "IVDD"))
tr = np.genfromtxt("xyce-gf180-smoke-tran.cir.csv", delimiter=",", names=True)
t, vout = tr["TIME"], tr["VOUT"]
before = float(np.interp(1.9e-9, t, vout))
after = float(np.interp(5.5e-9, t, vout))
checks = {
    "3.3 V inverter output high": out > 3.25,
    "6 V inverter output low": out6 < 0.05,
    "poly divider at half supply": 1.60 < rmid < 1.70,
    "PNP base-emitter voltage": 0.40 < qe < 0.90,
    "P+/Nwell diode forward voltage": 0.40 < da < 0.90,
    "supply delivers current": i_vdd < 0,
    "pulsed inverter high before the edge": before > 3.2,
    "pulsed inverter low after the edge": after < 0.1,
}
failed = [name for name, ok in checks.items() if not ok]
print(f"out={out:.4f} out6={out6:.4f} rmid={rmid:.4f} qe={qe:.4f} da={da:.4f} "
      f"i_vdd={i_vdd:.3e} tran_high={before:.4f} tran_low={after:.4f}")
if failed:
    raise SystemExit("GF180 Xyce smoke checks failed: " + ", ".join(failed))
print("GF180 Xyce smoke checks passed.")
PY
