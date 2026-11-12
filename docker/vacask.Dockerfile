# syntax=docker/dockerfile:1.7

# Policy-free VACASK base: the VACASK 0.3.4 release package, which bundles the
# OpenVAF-Reloaded Verilog-A compiler (openvaf-r) and a library of OSDI device
# models. gcc and binutils stay in the image because openvaf-r links with them.
ARG BUILD_IMAGE=debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

FROM ${BUILD_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG IMAGE_VERSION=dev
ARG VACASK_VERSION=0.3.4
ARG VACASK_DEB_SHA256=211cf53dbdd94af38240052f64ed376d5b011ffa3a2d83fa1cd449971038d817
# Codeberg rate-limits anonymous downloads; a mirror of the same file can be
# passed instead; the checksum still has to match.
ARG VACASK_DEB_URL=https://codeberg.org/arpadbuermen/VACASK/releases/download/_${VACASK_VERSION}/vacask_${VACASK_VERSION}_amd64.deb

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gcc binutils python3 python3-numpy \
 && curl --fail --location --retry 8 --retry-all-errors --retry-delay 30 \
      -o /tmp/vacask.deb "${VACASK_DEB_URL}" \
 && echo "${VACASK_DEB_SHA256}  /tmp/vacask.deb" | sha256sum -c - \
 && apt-get install -y --no-install-recommends /tmp/vacask.deb \
 && rm -rf /var/lib/apt/lists/* /tmp/vacask.deb

RUN { vacask -v 2>&1 || true; } | grep -F "This is vacask ${VACASK_VERSION}" \
 && command -v openvaf-r \
 && test -s /usr/lib/vacask/mod/resistor.osdi \
 && test -s /usr/lib/vacask/mod/spice/bsim4v8.osdi \
 && python3 -c 'import numpy' \
 && test ! -e /usr/local/bin/check_circuit.py

WORKDIR /work

LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains" \
      org.opencontainers.image.description="Pinned VACASK 0.3.4 with OpenVAF-Reloaded for Circuit-Bench tasks" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.circuit-bench.vacask.version="${VACASK_VERSION}"

CMD ["bash"]
