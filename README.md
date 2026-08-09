# Circuit-Bench Toolchains

Public, pinned Docker toolchains used to build and verify Circuit-Bench tasks.
The repository contains Docker build sources, release metadata, smoke checks,
and public validation records. It does not contain
benchmark tasks, reference solutions, hidden tests, model logs, or credentials.

## Published images

The maintained consumer set currently contains three published and digest-locked
images:

| Use | Image | Platforms | Recommendation |
| --- | --- | --- | --- |
| Full RTL-to-GDS and Verilator coverage | `ghcr.io/arcadia-1/circuit-bench-orfs-verilator-coverage:1.0.0` | `linux/amd64` | Preferred digital toolchain for new tasks. |
| Existing OpenROAD/ASAP7 synthesis and STA tasks | `ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0` | `linux/amd64` | Compatibility image; keep for tasks that already depend on its `/opt/openroad` runtime contract. It is not a complete upstream ORFS tree. |
| ngspice with complete Sky130 model trees | `ghcr.io/arcadia-1/circuit-bench-sky130-ngspice:2.0.8` | `linux/amd64`, `linux/arm64` | Recommended analog/Sky130 base. |

The registry also publishes
`ghcr.io/arcadia-1/circuit-bench-ngspice:2.0.8` as the policy-free build base
for the Sky130 image. Use the Sky130 image for normal analog tasks unless the
task intentionally needs ngspice without any PDK models.

Do not use these old or nonexistent names for new work:

- `ghcr.io/arcadia-1/circuit-bench-ngspice-sky130` is a legacy package that
  also contains historical task-layer tags. Use
  `circuit-bench-sky130-ngspice:2.0.8` instead.
- `ghcr.io/arcadia-1/circuit-bench-rtl-forge-openroad-asap7:1.0.0` was
  proposed by an older compatibility branch but was never published.

Tags are immutable public release tags. Reproducible automation should use the
manifest digests recorded in `images.lock.json`. This project intentionally
does not publish a `latest` tag.

## Full ORFS and Verilator

`docker/orfs-verilator-coverage.Dockerfile` defines the preferred digital
toolchain:

```text
ghcr.io/arcadia-1/circuit-bench-orfs-verilator-coverage:1.0.0
```

The image is published and locked by manifest digest in `images.lock.json`.
It should be preferred for new digital tasks that require either Verilator
coverage or a complete ASAP7 RTL-to-GDS flow. The older OpenROAD/ASAP7 image
remains available for compatibility rather than being silently replaced.

The image derives from the digest-pinned upstream ORFS
`26Q3-273-g9768f0f54` image and adds Verilator 5.050. It contains:

- the complete upstream ORFS `flow/Makefile`, `scripts`, `util`, `designs`, and
  `platforms` trees;
- OpenROAD, Yosys, and KLayout versions supplied by that matched ORFS release;
- Verilator and `verilator_coverage` for line, branch, expression, and bit-level
  toggle coverage.

It intentionally does not add benchmark RTL, testbenches, task-specific flow
configuration, generated results, Z3, UVM, or Cocotb. Validation assets remain
in this repository and are mounted read-only when used.

The image is `linux/amd64` because the pinned upstream ORFS image is
currently published only for that platform.

## Pull published releases

No GitHub account or registry login is required:

```bash
docker pull ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0
docker pull ghcr.io/arcadia-1/circuit-bench-orfs-verilator-coverage:1.0.0
docker pull ghcr.io/arcadia-1/circuit-bench-sky130-ngspice:2.0.8
```

Run the local smoke checks after pulling:

```bash
./smoke.sh
```

## Published image contents

The compatibility OpenROAD-ASAP7 image contains Ubuntu 24.04, OpenROAD
`26Q2-2123-g8f0a892fa2`, Icarus Verilog 14.0 development snapshot
`s20260301-180-gde415b2f0-dirty`, Python 3.12.3, and the pinned ASAP7 platform
files used by existing Circuit-Bench digital timing tasks.

The ngspice-Sky130 image contains ngspice 46, Python with NumPy, and the pinned
Sky130 continuous model library at
`/opt/sky130/continuous/sky130.lib.spice`. It also carries the complete official
Sky130 ngspice model trees at:

```text
/opt/sky130/pdk/sky130A/libs.tech/ngspice/
/opt/sky130/pdk/sky130A/libs.ref/sky130_fd_pr/spice/
```

`SKY130_PDK_ROOT` is `/opt/sky130/pdk/sky130A`. The image is deliberately
policy-free: benchmark checkers, allowlists, task contracts, and scoring code
belong to benchmark-owned layers.

These are toolchain images, not complete task images. A task repository adds
its checker, starter files, task-specific contracts, scoring, and verification
rules as separate layers.

## Build sources and release workflows

- `docker/ngspice.Dockerfile` builds ngspice 46 from a checksum-pinned source
  archive.
- `docker/ngspice-sky130.Dockerfile` adds the pinned Sky130 continuous model
  library and complete official ngspice device-model trees.
- `docker/orfs-verilator-coverage.Dockerfile` derives from the pinned full ORFS
  release and builds the pinned Verilator 5.050 revision.
- `.github/workflows/publish-images.yml` publishes the multi-architecture
  ngspice and Sky130 releases.

ORFS releases are built and validated on a fixed compatible amd64 host. Full
EDA signoff is intentionally not run on GitHub-hosted runners: the upstream
image includes an optional precompiled Kepler LEC binary whose CPU instruction
requirements are not portable across every hosted-runner CPU. Coverage and
RTL-to-GDS acceptance are run against the exact published manifest digest on
the fixed host.

Published task Dockerfiles should consume manifest digests from
`images.lock.json`, not only human-readable tags.

## Build and validate the ORFS release

Build on an amd64 Docker host:

```bash
sudo docker build \
  --file docker/orfs-verilator-coverage.Dockerfile \
  --tag circuit-bench-orfs-verilator-coverage:1.0.0 \
  .
```

Run the tool/coverage smoke and a complete upstream ASAP7 GCD flow:

```bash
sudo docker run --rm --network none \
  --env TEST_ROOT=/tests \
  --volume "$PWD/tests:/tests:ro" \
  circuit-bench-orfs-verilator-coverage:1.0.0 \
  /tests/verilator-coverage-smoke.sh

sudo docker run --rm --network none \
  --env TEST_ROOT=/tests \
  --volume "$PWD/tests:/tests:ro" \
  circuit-bench-orfs-verilator-coverage:1.0.0 \
  /tests/gcd-coverage.sh

sudo docker run --rm --network none \
  --volume "$PWD/tests:/tests:ro" \
  circuit-bench-orfs-verilator-coverage:1.0.0 \
  /tests/orfs-gcd-smoke.sh
```

The recorded GCD and RTL-Forge NoC-router acceptance results are under
`validation/`. They demonstrate coverage, complete RTL-to-GDS execution, DRC,
STA, electrical checks, and GDS generation without putting design-specific
content into the image.

## Offline transfer

Export the current digest-locked consumer images:

```bash
docker save \
  ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0 \
  ghcr.io/arcadia-1/circuit-bench-orfs-verilator-coverage:1.0.0 \
  ghcr.io/arcadia-1/circuit-bench-sky130-ngspice:2.0.8 \
  | zstd -T0 -6 -o circuit-bench-toolchains.tar.zst
```

Import them with:

```bash
zstd -dc circuit-bench-toolchains.tar.zst | docker load
```
