# Analog images: usage notes

PDK snapshots: Sky130 and GF180MCU from open_pdks `e7a6777` (2026-11-12, the
ciel-releases builds), IHP SG13G2 from IHP-Open-PDK `e73adb4` (main,
2026-11-10). The IHP VACASK image stays on `0dedf26` (2026-09-15): VACASK
0.3.4's `sg13g2tovc` still reads `sg13g2_hbt_mod_mismatch.lib` and
`resistors_mod_mismatch.lib`, which IHP removed after it, so the IHP models in
the VACASK image are older than those in the ngspice and Xyce images (their
MOS models are the same; the HBT, resistor and diode statistics differ).
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
