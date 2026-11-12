# Analog images: usage notes

PDK snapshots: Sky130 and GF180MCU from open_pdks (GF180 `792ef67`), IHP SG13G2
from IHP-Open-PDK `0dedf26` (2026-09-15, the snapshot VACASK 0.3.4 supports).
Exact inputs are in `images.lock.json`. Working decks for every image are in
`tests/`.

- **ngspice + IHP**: copy `$IHP_PDK_ROOT/libs.tech/ngspice/.spiceinit` into
  the working directory (it loads the OSDI models), then
  `.lib cornerMOSlv.lib mos_tt`.
- **Xyce**: one analysis per netlist. IHP needs
  `Xyce -plugin "$IHP_XYCE_PLUGINS" deck.cir`; its varactor model (`mosvar`)
  is not available.
- **VACASK**: its own netlist language. Copy the PDK's
  `libs.tech/vacask/.vacaskrc.toml` into the working directory. VACASK
  compiles Verilog-A at run time when a deck needs it (`load "x.va"`, or
  behavioral elements such as the GF180 library's voltage-dependent
  resistors). That needs a host kernel 5.3 or newer; on RHEL/Rocky 8 hosts
  (kernel 4.18) VACASK aborts with "assign: Bad file descriptor". IHP needs no
  run-time compile. For GF180 use the plain MOS devices, not `*_dss`.
- No Sky130 Xyce image: through the ngspice library, Xyce matches MOS and
  resistors but rejects the diodes and MIM capacitors and mis-models the PNP
  (see `validation/`). No Sky130 VACASK image: VACASK cannot convert the
  library.
