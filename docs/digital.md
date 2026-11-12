# Digital images: notes

- `orfs-verilator-coverage`: upstream ORFS `26Q3-273-g9768f0f54` (complete
  flow and platform trees, OpenROAD, Yosys, KLayout) plus Verilator 5.050.
  Built and validated on a fixed amd64 host, because the upstream image's
  Kepler LEC binary does not run on every hosted-runner CPU. Smoke tests:
  `tests/verilator-coverage-smoke.sh`, `tests/gcd-coverage.sh`,
  `tests/orfs-gcd-smoke.sh`.
- `openroad-asap7`: compatibility image for existing ASAP7 timing tasks
  (OpenROAD `26Q2-2123-g8f0a892fa2`, Icarus Verilog 14.0, Python 3.12).
- Do not use `circuit-bench-ngspice-sky130` (legacy) or
  `circuit-bench-rtl-forge-openroad-asap7` (never published).
