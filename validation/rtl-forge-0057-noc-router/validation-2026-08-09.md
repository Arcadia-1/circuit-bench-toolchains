# RTL-Forge 0057 NoC Router ORFS/ASAP7 Validation

Validation date: 2026-08-09 (Asia/Shanghai)

## Outcome

The public validated solution for RTL-Forge task `0057-noc-router` completed a
full ASAP7 RTL-to-GDS flow in the generic Circuit-Bench ORFS/Verilator release
candidate. The final run is detailed-route DRC-clean, antenna-clean,
setup/hold-clean, and free of max-slew, max-capacitance, and max-fanout
violations.

The RTL, SDC, testbench, and task-specific ORFS configuration were mounted
read-only. None of them are baked into the generic toolchain image.

## Provenance

- Release-candidate image:
  `circuit-bench-orfs-verilator-coverage:26q3-273-v5.050-generic1`
- Local image ID:
  `sha256:9de381ac21e5fefefab531c83b9229482b10e0ae02d84d362b59b48cd5efac9b`
- Local image size: 1,997,559,829 bytes
- Pinned ORFS revision:
  `9768f0f5432c77b215be1ff3ce7a3417f2b27bcd`
- RTL-Forge repository revision:
  `4622cc6e1e55041abad51e637e8377df7ce7747f`
- Task: `task/0057-noc-router`, top module `noc_router`
- RTL source: public `solution/rtl`, not the starter skeleton
- Public constraint: 1000 ps clock, 50 ps clock uncertainty, 50 ps input and
  output delays

Input hashes:

| Input | SHA-256 |
| --- | --- |
| `rtl/noc_router.sv` | `54d8d5cc43f7054723d4de72ba62cc298b61338a8f6a18c34a966f5d876ce99d` |
| `rtl/noc_router_gen.svh` | `e625c54c470cb680193c506b172f89672b7ab3c252d5bfa75591771edfe04f86` |
| `constraints/noc_router_asap7.sdc` | `840dd37b312989393536d0bb2e20179644e559dc0501bd8252fd74d2765535d1` |

## Functional precheck

Verilator 5.050 compiled the solution and public visible testbench. All 60
visible semantic criteria reported `1`, there were zero failed criteria, and
the run ended with:

```text
VISIBLE_SCORE_DONE
TB_PASS: packet-aware NoC router criteria passed
```

Verilator emitted non-fatal lint warnings in the public source/testbench,
including width, shared-variable, and combinational-temporary latch warnings.
They did not prevent elaboration or the 60/60 functional result.

## Full-P&R configuration

The original task is calibrated only through mapped synthesis and setup STA.
Two explicit physical-implementation adjustments were applied by the external
validation config:

1. `HOLD_SLACK_MARGIN=10` ps and a 50% hold-buffer ceiling. The default 20%
   ceiling stopped the first P&R attempt before hold repair completed.
2. `set_max_fanout 20 [current_design]` in an SDC overlay. The public SDC
   declares the asynchronous reset a false timing path but does not constrain
   its physical fanout. Without the overlay, final RC extraction left 98
   max-slew violations on the reset tree even though setup and hold passed.

The original public SDC remains unmodified. The overlay sources it and adds
only the physical fanout constraint.

The final clean run used 8 CPUs, a 32 GiB container memory limit, no network,
and completed in 345 seconds wall-clock time.

## Final results

| Check or metric | Result |
| --- | ---: |
| ORFS return code | 0 |
| Flow errors | 0 |
| Detailed-route DRC violations | 0 |
| Global-route antenna violations | 0 |
| Detailed-route antenna violations | 0 |
| Setup WNS | +210.658 ps |
| Setup TNS / violations | 0 ps / 0 |
| Hold WNS | +10.6535 ps |
| Hold TNS / violations | 0 ps / 0 |
| Max-slew violations | 0 |
| Max-capacitance violations | 0 |
| Max-fanout violations | 0 |
| Estimated minimum clock period | 789.342 ps |
| Estimated Fmax | 1.26688 GHz |
| Standard-cell count | 4,318 |
| Sequential-cell count | 331 |
| Timing-repair buffers | 1,261 |
| Placed standard-cell area | 453.977 um^2 |
| Core area | 922.622 um^2 |
| Standard-cell utilization | 49.2051% |
| Total power estimate | 5.02371 mW |
| Worst VDD IR drop | 3.6044 mV |
| Worst VSS rise | 3.41667 mV |

The power number is the flow's vectorless estimate, not a workload-derived
VCD/SAIF power measurement. It is useful as a physical-flow sanity check, but
must not be treated as representative application power.

OpenROAD's post-CTS timing-repair logic-equivalence check passed. KLayout also
reported that every LEF cell had a matching GDS/OAS cell and that the final
layout contained no orphan cells.

The remaining non-fatal flow warnings are early-stage wire-load estimates,
empty macro PDN grids for this macro-free design, unavailable ASAP7 antenna
diodes (both antenna reports are nevertheless empty), a deprecated RCX option,
core-grid snapping, and a headless GUI runtime-directory warning.

## Artifact hashes

The large local run products are intentionally not committed to this source
repository. Their identities are retained here:

- Final GDS size: 4,953,196 bytes
- Final GDS SHA-256:
  `c006215f5eabcda42fda193df10924614c88d77369ed9958d19535f51a4d4614`
- Final Verilog SHA-256:
  `02f3dee9315fe9555629bbcda16b0dfc94f037d5f4cd017180694e1c33bc8bed`
