# Third-Party Components

The published images redistribute open-source EDA tools and open process data.
Refer to each upstream project for its authoritative source and license terms:

- OpenROAD: <https://github.com/The-OpenROAD-Project/OpenROAD>
- OpenROAD-flow-scripts and ASAP7 platform data:
  <https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts>
- Verilator: <https://github.com/verilator/verilator>
- Icarus Verilog: <https://github.com/steveicarus/iverilog>
- OSS CAD Suite: <https://github.com/YosysHQ/oss-cad-suite-build>
- ngspice: <https://ngspice.sourceforge.io/>
- SkyWater SKY130 PDK: <https://github.com/google/skywater-pdk>
- GlobalFoundries GF180MCU PDK (Apache-2.0):
  <https://github.com/google/gf180mcu-pdk>, packaged through open_pdks and
  <https://github.com/fossi-foundation/ciel-releases>
- IHP SG13G2 Open PDK (Apache-2.0): <https://github.com/IHP-GmbH/IHP-Open-PDK>.
  The ngspice and VACASK images ship OSDI objects compiled from the PDK's
  Verilog-A models; the Xyce image ships Xyce plugins built from the same
  sources. The Verilog-A sources are included in all three images.
- Xyce (GPL-3.0): <https://github.com/Xyce/Xyce>, built from the
  `Release-7.10.0` source archive
- Trilinos (BSD-3-Clause and LGPL-2.1 packages):
  <https://github.com/trilinos/Trilinos>, built from `trilinos-release-14-4-0`
- ADMS (Debian package `adms`): <https://github.com/Qucs/ADMS>
- VACASK (AGPL-3.0): <https://codeberg.org/arpadbuermen/VACASK>, the 0.3.4
  release package. It bundles OpenVAF-Reloaded (GPL-3.0,
  <https://github.com/OpenVAF-Reloaded/OpenVAF>), which also compiles the IHP
  OSDI objects shipped in the ngspice image.

The image tags in this repository identify the exact Circuit-Bench runtime
snapshots. They are not upstream project releases.
