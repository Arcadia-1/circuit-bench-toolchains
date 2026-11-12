# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE
ARG SOURCE_FETCH_IMAGE=debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818
ARG OSDI_BUILD_IMAGE=debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

# IHP SG13G2 model files at a pinned commit of IHP-Open-PDK. The commit is the
# one VACASK 0.3.4's converter targets, so every IHP image uses the same models.
FROM ${SOURCE_FETCH_IMAGE} AS ihp-src

ARG DEBIAN_FRONTEND=noninteractive
ARG IHP_COMMIT=0dedf265f0cad6ef81aeb64b9ddd17eef88c0460

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --quiet --filter=blob:none --no-checkout \
      https://github.com/IHP-GmbH/IHP-Open-PDK.git /tmp/ihp \
 && cd /tmp/ihp \
 && git sparse-checkout init --no-cone \
 && git sparse-checkout set /LICENSE \
      /ihp-sg13g2/libs.tech/ngspice/ /ihp-sg13g2/libs.tech/verilog-a/ \
      /ihp-sg13g2/libs.ref/sg13g2_stdcell/spice/ /ihp-sg13g2/libs.ref/sg13g2_io/spice/ \
 && git checkout --quiet "${IHP_COMMIT}" \
 && test "$(git rev-parse HEAD)" = "${IHP_COMMIT}" \
 && mkdir -p /opt/ihp/pdk \
 && cp -a ihp-sg13g2 /opt/ihp/pdk/ \
 && cp LICENSE /opt/ihp/pdk/ihp-sg13g2/LICENSE

# Compile the PDK's Verilog-A models to OSDI with OpenVAF-Reloaded, taken from
# the VACASK 0.3.4 release package. Generic x86-64 code, so any amd64 host runs it.
FROM ${OSDI_BUILD_IMAGE} AS ihp-osdi

ARG DEBIAN_FRONTEND=noninteractive
ARG VACASK_VERSION=0.3.4
ARG VACASK_DEB_SHA256=211cf53dbdd94af38240052f64ed376d5b011ffa3a2d83fa1cd449971038d817
# Codeberg rate-limits anonymous downloads; a mirror of the same file can be
# passed instead; the checksum still has to match.
ARG VACASK_DEB_URL=https://codeberg.org/arpadbuermen/VACASK/releases/download/_${VACASK_VERSION}/vacask_${VACASK_VERSION}_amd64.deb

COPY --from=ihp-src /opt/ihp /opt/ihp

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gcc binutils \
 && curl --fail --location --retry 8 --retry-all-errors --retry-delay 30 \
      -o /tmp/vacask.deb "${VACASK_DEB_URL}" \
 && echo "${VACASK_DEB_SHA256}  /tmp/vacask.deb" | sha256sum -c - \
 && apt-get install -y --no-install-recommends /tmp/vacask.deb \
 && rm -rf /var/lib/apt/lists/* /tmp/vacask.deb

RUN cd /opt/ihp/pdk/ihp-sg13g2/libs.tech/verilog-a \
 && bash openvaf-compile-va.sh --compile-model-generic \
 && rm -f r3_cmc/r3_cmc-patched.va \
 && for model in psp103 psp103_nqs r3_cmc mosvar cap_cmomi cap_cmomf; do \
      test -s "../ngspice/osdi/${model}.osdi" || exit 1; \
    done

FROM ${BASE_IMAGE}

ARG IMAGE_VERSION=dev
ARG IHP_COMMIT=0dedf265f0cad6ef81aeb64b9ddd17eef88c0460

COPY --from=ihp-osdi /opt/ihp /opt/ihp

# The PDK's .spiceinit expects PDK_ROOT and PDK; it adds the model directories
# to the source path and loads the OSDI models.
ENV PDK_ROOT=/opt/ihp/pdk \
    PDK=ihp-sg13g2 \
    IHP_PDK_ROOT=/opt/ihp/pdk/ihp-sg13g2

RUN test "$(command -v ngspice)" = /opt/ngspice/bin/ngspice \
 && ngspice --version | grep -F "ngspice-46" \
 && python3 -c 'import numpy' \
 && test ! -e /usr/local/bin/check_circuit.py \
 && test -s "${IHP_PDK_ROOT}/libs.tech/ngspice/.spiceinit" \
 && for lib in cornerMOSlv.lib cornerMOShv.lib cornerRES.lib cornerCAP.lib cornerHBT.lib cornerDIO.lib; do \
      test -s "${IHP_PDK_ROOT}/libs.tech/ngspice/models/${lib}" || exit 1; \
    done

LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains" \
      org.opencontainers.image.description="Pinned ngspice and IHP SG13G2 runtime for Circuit-Bench tasks" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.circuit-bench.ngspice.version="46" \
      org.circuit-bench.ihp-sg13g2.commit="${IHP_COMMIT}"

CMD ["bash"]
