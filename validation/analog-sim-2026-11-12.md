# IHP SG13G2, Xyce and VACASK images: validation, 2026-11-12

Release candidates built locally with rootless podman 4.9 on two x86-64 hosts
(Rocky Linux 8.10, kernel 4.18). The GF180 VACASK image needs a newer kernel
(see below) and is checked by `.github/workflows/check-vacask.yml` on
GitHub's Ubuntu 24.04 runners.

## Builds and smoke tests

| Image | Size | Smoke test | Result |
| --- | --- | --- | --- |
| `circuit-bench-ihp-sg13g2-ngspice` | 282 MB | `ngspice-ihp-sg13g2-smoke.sh` | passed |
| `circuit-bench-xyce` | 2.09 GB | `xyce-smoke.sh` | passed |
| `circuit-bench-gf180-xyce` | 2.10 GB | `xyce-gf180-smoke.sh` | passed |
| `circuit-bench-ihp-sg13g2-xyce` | 2.09 GB | `xyce-ihp-sg13g2-smoke.sh` | passed |
| `circuit-bench-vacask` | 590 MB | `vacask-smoke.sh` | passed, 53/53 runs |
| `circuit-bench-gf180-vacask` | 591 MB | `vacask-gf180-smoke.sh` | needs kernel >= 5.3; CI |
| `circuit-bench-ihp-sg13g2-vacask` | 594 MB | `vacask-ihp-sg13g2-smoke.sh` | passed, 53/53 runs |

Xyce 7.10.0 and Trilinos 14.4 took 22 minutes to build with 30 jobs. The
smoke tests cover DC operating points of every device class the PDKs ship
(1.2/3.3 V or 3.3/6 V MOS, poly resistors, BJT/HBT, diodes) and a transient
of an inverter driving a MIM capacitor. Output lines:

```text
ihp-sg13g2-ngspice  out=1.2000 outh=0.0000 rmid=0.6000 qb=0.7266 da=0.7412 tran_high=1.2000 tran_low=0.0000
xyce                v(out)@31ns=0.9501 v(da)=0.5360 v(dn)=1.0000
gf180-xyce          out=3.3000 out6=0.0000 rmid=1.6500 qe=0.6892 da=0.7854 tran_high=3.3000 tran_low=-0.0000
ihp-sg13g2-xyce     out=1.2000 outh=0.0000 rmid=0.6000 qb=0.7266 da=0.7205 tran_high=1.2000 tran_low=0.0000
vacask              v(mid)=0.7500 v(out)@31ns=0.9502
ihp-sg13g2-vacask   vn1=4.005261e-04 vn2=2.402225e-05 vp1=2.114547e-04 vp2=1.683571e-05
```

## Cross-simulator check

Four MOS bias points per PDK (NMOS and PMOS, |Vgs| = VDD and VDD/2, |Vds| =
VDD; W = 1 um, minimum L), same models, drain currents in uA:

| PDK | Device | ngspice 46 | Xyce 7.10.0 | VACASK 0.3.4 |
| --- | --- | ---: | ---: | ---: |
| Sky130 (1.8 V) | NMOS full / half | 501.05 / 48.35 | 501.05 / 48.35 | — |
| | PMOS full / half | 200.75 / 21.71 | 200.75 / 21.71 | — |
| GF180 (3.3 V) | NMOS full / half | 520.29 / 166.79 | 520.31 / 166.82 | 520.31 / 166.82 |
| | PMOS full / half | 248.06 / 57.19 | 248.08 / 57.20 | 248.08 / 57.20 |
| IHP SG13G2 (1.2 V) | NMOS full / half | 400.53 / 24.02 | 400.53 / 24.02 | 400.53 / 24.02 |
| | PMOS full / half | 211.45 / 16.84 | 211.45 / 16.84 | 211.45 / 16.84 |

All simulators agree within 0.03 %. Sky130 has no Xyce image (no official
Xyce models; Xyce reads the ngspice models, but only this DC check was run)
and no VACASK image (VACASK's generic converter cannot read the library).

## Findings recorded in the images and docs

- **IHP-Open-PDK pin.** VACASK 0.3.4's `sg13g2tovc` reads
  `resistors_mod_mismatch.lib` and `sg13g2_hbt_mod_mismatch.lib`, which IHP
  removed on 2026-09-17 and 2026-10-18. Every IHP image therefore uses
  `0dedf265` (2026-09-15).
- **VACASK and old kernels.** VACASK compiles Verilog-A at run time when a
  deck needs it, and waits for the compiler with `pidfd_open`, which kernels
  before 5.3 lack. It then aborts with "assign: Bad file descriptor" (traced
  with strace: `pidfd_open` returns `ENOSYS`, then `epoll_ctl(..., -1, ...)`).
  The converted GF180 library always triggers such a compile (its
  voltage-dependent resistors become a behavioral module); IHP never does.
- **GF180 `*_dss` wrappers** in VACASK's typical-corner conversion reference a
  dropped resistor parameter; the plain devices work.
- **Xyce with IHP.** PSP103 and R3_CMC build as plugins when Xyce/ADMS runs in
  each model's own directory; `mosvar` fails in ADMS.
- **IHP test diode.** A 0.78 um antenna diode shows 1.67 V at 10 uA
  (series resistance); the smoke test uses 10 um x 10 um (0.74 V).
