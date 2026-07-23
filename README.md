# Circuit-Bench Toolchains

Public, pinned Docker toolchains used to build and verify Circuit-Bench tasks.
The repository contains the Docker build sources, release workflow,
distribution metadata, and smoke checks. It does not contain benchmark tasks,
reference solutions, hidden tests, model logs, or credentials.

## Images

| Tool and process | Image |
| --- | --- |
| OpenROAD and ASAP7 | `ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0` |
| ngspice and Sky130 | `ghcr.io/arcadia-1/circuit-bench-sky130-ngspice:2.0.1` |

The tags are immutable public release tags. For reproducible automation, use
the registry digests recorded in `images.lock.json` rather than a mutable alias.
This project intentionally does not publish a `latest` tag.

## Pull

No GitHub account or registry login is required:

```bash
docker pull ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0
docker pull ghcr.io/arcadia-1/circuit-bench-sky130-ngspice:2.0.1
```

Run the local smoke checks after pulling:

```bash
./smoke.sh
```

## Contents

The OpenROAD-ASAP7 image contains Ubuntu 24.04, OpenROAD
`26Q2-2123-g8f0a892fa2`, Icarus Verilog 14.0 development snapshot
`s20260301-180-gde415b2f0-dirty`, Python 3.12.3, and the pinned ASAP7 platform
files used by Circuit-Bench digital timing tasks.

The ngspice-Sky130 image contains ngspice 46, Python with NumPy, the pinned
Sky130 continuous model library at `/opt/sky130/continuous/sky130.lib.spice`,
and the official RF R/C, inductor, and varactor model trees under
`/opt/sky130/rf`.

These are toolchain images, not complete task images. A task repository adds
its public starter files and, in the evaluator environment, its private
verification material as separate layers.

## Build sources

- `docker/ngspice.Dockerfile` builds ngspice 46 from a checksum-pinned source
  archive.
- `docker/ngspice-sky130.Dockerfile` adds the pinned Sky130 continuous and RF
  model trees.
- `.github/workflows/publish-images.yml` publishes versioned amd64 and arm64
  manifests to GHCR, attaches provenance and SBOM attestations, runs a
  transistor-level smoke simulation, and records the resulting manifest
  digests.

Published task Dockerfiles should consume the manifest digest recorded in
`images.lock.json`, not just the human-readable release tag.

## Offline Transfer

An operator can export both public images into one compressed archive:

```bash
docker save \
  ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0 \
  ghcr.io/arcadia-1/circuit-bench-sky130-ngspice:2.0.1 \
  | zstd -T0 -6 -o circuit-bench-toolchains.tar.zst
```

Import it with:

```bash
zstd -dc circuit-bench-toolchains.tar.zst | docker load
```
