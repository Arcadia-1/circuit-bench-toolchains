# Third-Party Components

The published images redistribute open-source EDA tools and open process data.
Refer to each upstream project for its authoritative source and license terms:

- OpenROAD: <https://github.com/The-OpenROAD-Project/OpenROAD>
- OpenROAD-flow-scripts and ASAP7 platform data:
  <https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts>
- Icarus Verilog: <https://github.com/steveicarus/iverilog>
- OSS CAD Suite: <https://github.com/YosysHQ/oss-cad-suite-build>
- ngspice: <https://ngspice.sourceforge.io/>
- SkyWater SKY130 PDK: <https://github.com/google/skywater-pdk>

The image tags in this repository identify the exact Circuit-Bench runtime
snapshots. They are not upstream project releases.

The RTL-Forge OpenROAD/ASAP7 image is assembled from the pinned public
`circuit-bench-openroad-asap7:1.0.0` base digest. That base carries the
`2026-06-20` OSS CAD Suite payload; consult the upstream repositories for the
individual component licenses.
