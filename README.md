# Circuit-Bench Toolchains

[![Images on GHCR](https://img.shields.io/badge/images-ghcr.io%2Farcadia--1-2496ED?logo=docker&logoColor=white)](https://github.com/orgs/Arcadia-1/packages?repo_name=circuit-bench-toolchains)
[![ngspice 46](https://img.shields.io/badge/ngspice-46-blue)](https://ngspice.sourceforge.io/)
[![Xyce 7.10.0](https://img.shields.io/badge/Xyce-7.10.0-blue)](https://github.com/Xyce/Xyce)
[![VACASK 0.3.4](https://img.shields.io/badge/VACASK-0.3.4-blue)](https://codeberg.org/arpadbuermen/VACASK)
[![PDKs](https://img.shields.io/badge/PDKs-Sky130%20%7C%20GF180%20%7C%20IHP%20SG13G2-2ea44f)](docs/analog.md)
[![Publish ngspice](https://github.com/Arcadia-1/circuit-bench-toolchains/actions/workflows/publish-images.yml/badge.svg)](https://github.com/Arcadia-1/circuit-bench-toolchains/actions/workflows/publish-images.yml)

Pinned Docker images with the simulators and open PDKs that Circuit-Bench
tasks run on. Pick the image for your simulator and PDK; it contains
everything. The images carry no benchmark checker or scoring code.

## Analog

`ghcr.io/arcadia-1/circuit-bench-<name>`

| PDK | ngspice 46 | Xyce 7.10.0 | VACASK 0.3.4 |
| --- | --- | --- | --- |
| Sky130 | `sky130-ngspice:2.0.8` | — | — |
| GF180MCU | `gf180-ngspice` * | `gf180-xyce` * | `gf180-vacask` * |
| IHP SG13G2 | `ihp-sg13g2-ngspice` * | `ihp-sg13g2-xyce` * | `ihp-sg13g2-vacask` * |

\* Release candidate, `1.0.0` once published. Sky130 and GF180 ngspice images
are amd64 + arm64; the rest are amd64.

## Digital

| Image | Use |
| --- | --- |
| `orfs-verilator-coverage:1.0.0` | RTL-to-GDS (full ORFS) and Verilator coverage |
| `openroad-asap7:1.0.0` | existing ASAP7 synthesis and STA tasks |

## Use

```bash
docker run --rm -v "$PWD:/work" -w /work \
  ghcr.io/arcadia-1/circuit-bench-sky130-ngspice:2.0.8 ngspice -b deck.spice
```

In task Dockerfiles, pin the digest from [`images.lock.json`](images.lock.json).

## Versions

Tags never change and there is no `latest`. Each tag fixes the simulator
version and PDK snapshot. When ngspice, Xyce, VACASK or a PDK releases a new
version, it gets a new tag; old tags stay, so existing tasks are unaffected
until they are moved and re-validated on purpose.

More: [analog notes](docs/analog.md) · [digital notes](docs/digital.md) ·
[maintaining](docs/maintainers.md) · [third-party licenses](THIRD_PARTY.md) ·
[validation records](validation/)
