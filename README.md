# Circuit-Bench Toolchains

Public, pinned Docker toolchains used to build and verify Circuit-Bench tasks.
The repository contains distribution metadata and smoke checks only. It does
not contain benchmark tasks, reference solutions, hidden tests, model logs, or
credentials.

## Images

| Tool and process | Image |
| --- | --- |
| OpenROAD and ASAP7 | `ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0` |
| ngspice and Sky130 | `ghcr.io/arcadia-1/circuit-bench-ngspice-sky130:1.0.0` |

The tags are immutable public release tags. For reproducible automation, use
the registry digests recorded in `images.lock.json` rather than a mutable alias.
This project intentionally does not publish a `latest` tag.

## Pull

No GitHub account or registry login is required:

```bash
docker pull ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0
docker pull ghcr.io/arcadia-1/circuit-bench-ngspice-sky130:1.0.0
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

The ngspice-Sky130 image contains ngspice 39, Python 3.11.2, and the pinned
Sky130 continuous model library at
`/opt/sky130/continuous/sky130.lib.spice`.

These are toolchain images, not complete task images. A task repository adds
its public starter files and, in the evaluator environment, its private
verification material as separate layers.

## Offline Transfer

An operator can export both public images into one compressed archive:

```bash
docker save \
  ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0 \
  ghcr.io/arcadia-1/circuit-bench-ngspice-sky130:1.0.0 \
  | zstd -T0 -6 -o circuit-bench-toolchains.tar.zst
```

Import it with:

```bash
zstd -dc circuit-bench-toolchains.tar.zst | docker load
```
