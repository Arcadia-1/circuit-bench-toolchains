#!/usr/bin/env bash
# Run inside the Xyce base image with this directory mounted at $TEST_ROOT (default /smoke).
set -euo pipefail

test_root="${TEST_ROOT:-/smoke}"

Xyce -v | grep -F "Xyce Release 7.10.0"
test -x /opt/xyce/bin/admsXml
test -x /opt/xyce/bin/buildxyceplugin
python3 -c 'import numpy'
test ! -e /usr/local/bin/check_circuit.py

work=$(mktemp -d)
cp "${test_root}/xyce-smoke.cir" "${work}/"
cd "${work}"
Xyce xyce-smoke.cir > xyce.log 2>&1 || { cat xyce.log >&2; exit 1; }

python3 - <<'PY'
import numpy as np

data = np.genfromtxt("xyce-smoke.cir.csv", delimiter=",", names=True)
t, out, da, dn = data["TIME"], data["VOUT"], data["VDA"], data["VDN"]
v_tau3 = float(np.interp(31e-9, t, out))  # three time constants after the edge
checks = {
    "RC output after three time constants": 0.93 < v_tau3 < 0.97,
    "diode forward voltage": 0.40 < da[-1] < 0.80,
    # Level-1 NMOS in triode with a 10k load: 0.5*V^2 - 2.3*V + 1.8 = 0 gives V = 1.0.
    "level-1 MOSFET drain voltage": 0.99 < dn[-1] < 1.01,
}
failed = [name for name, ok in checks.items() if not ok]
print(f"v(out)@31ns={v_tau3:.4f} v(da)={da[-1]:.4f} v(dn)={dn[-1]:.4f}")
if failed:
    raise SystemExit("Xyce smoke checks failed: " + ", ".join(failed))
print("Xyce smoke checks passed.")
PY
