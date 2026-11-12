#!/usr/bin/env bash
# Run inside the GF180MCU VACASK image with this directory mounted at $TEST_ROOT (default /smoke).
# The converted GF180 library contains behavioral elements that VACASK compiles
# with OpenVAF at run time, which needs a host kernel >= 5.3 (pidfd_open).
set -euo pipefail

test_root="${TEST_ROOT:-/smoke}"

{ vacask -v 2>&1 || true; } | grep -F "This is vacask 0.3.4"
test ! -e /usr/local/bin/check_circuit.py
test "${GF180_PDK_ROOT}" = /opt/gf180/pdk/gf180mcuD
test -s "${GF180_PDK_ROOT}/libs.tech/vacask/.vacaskrc.toml"

work=$(mktemp -d)
# VACASK reads .vacaskrc.toml from the working directory; the PDK's copy puts
# the converted models on the include path.
cp "${GF180_PDK_ROOT}/libs.tech/vacask/.vacaskrc.toml" "${test_root}/vacask-gf180-smoke.sim" "${work}/"
cd "${work}"
vacask vacask-gf180-smoke.sim > vacask.log 2>&1 || { cat vacask.log >&2; exit 1; }

PYTHONPATH=/usr/lib/vacask/python python3 - <<'PY'
import numpy as np
from rawfile import rawread

op = rawread("op1.raw").get()
current = {name: abs(float(op[f"{name}:flow(br)"][0])) for name in ("vn1", "vn2", "vp1", "vp2")}
# Drain currents from ngspice 46 on the same PDK models and bias points.
reference = {"vn1": 0.000520289, "vn2": 0.000166791, "vp1": 0.0002480605, "vp2": 5.7187e-05}
tr = rawread("tran1.raw").get()
before = float(np.interp(1.9e-9, tr["time"], tr["out"]))
after = float(np.interp(5.5e-9, tr["time"], tr["out"]))
checks = {f"{name} current within 0.5 % of ngspice": abs(current[name] / reference[name] - 1) < 0.005
          for name in reference}
checks["pulsed inverter high before the edge"] = before > 3.3 - 0.05
checks["pulsed inverter low after the edge"] = after < 0.1
failed = [name for name, ok in checks.items() if not ok]
print(" ".join(f"{name}={current[name]:.6e}" for name in reference)
      + f" tran_high={before:.4f} tran_low={after:.4f}")
if failed:
    raise SystemExit("GF180MCU VACASK smoke checks failed: " + ", ".join(failed))
print("GF180MCU VACASK smoke checks passed.")
PY
