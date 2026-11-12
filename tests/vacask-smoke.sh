#!/usr/bin/env bash
# Run inside the VACASK base image with this directory mounted at $TEST_ROOT (default /smoke).
set -euo pipefail

test_root="${TEST_ROOT:-/smoke}"

# `vacask -v` exits non-zero after printing its banner.
{ vacask -v 2>&1 || true; } | grep -F "This is vacask 0.3.4"
command -v openvaf-r
test -s /usr/lib/vacask/mod/resistor.osdi
python3 -c 'import numpy'
test ! -e /usr/local/bin/check_circuit.py

work=/tmp/vacask-smoke
rm -rf "${work}" && mkdir -p "${work}"
cp "${test_root}/vacask-smoke.sim" "${test_root}/vacask-smoke.va" "${work}/"
mv "${work}/vacask-smoke.va" "${work}/vares.va"
cd "${work}"
# Compile the Verilog-A model ahead of time, so this check also passes on hosts
# whose kernel is too old for VACASK's on-the-fly compile (see docs/analog.md).
openvaf-r -o vares.osdi vares.va > openvaf.log 2>&1 || { cat openvaf.log >&2; exit 1; }
vacask vacask-smoke.sim > vacask.log 2>&1 || { cat vacask.log >&2; exit 1; }

PYTHONPATH=/usr/lib/vacask/python python3 - <<'PY'
import numpy as np
from rawfile import rawread

op = rawread("op1.raw").get()
mid = float(op["mid"][0])
tr = rawread("tran1.raw").get()
v_tau3 = float(np.interp(31e-9, tr["time"], tr["out"]))
checks = {
    "Verilog-A resistor divider": 0.745 < mid < 0.755,
    "RC output after three time constants": 0.93 < v_tau3 < 0.97,
}
failed = [name for name, ok in checks.items() if not ok]
print(f"v(mid)={mid:.4f} v(out)@31ns={v_tau3:.4f}")
if failed:
    raise SystemExit("VACASK smoke checks failed: " + ", ".join(failed))
print("VACASK smoke checks passed.")
PY
