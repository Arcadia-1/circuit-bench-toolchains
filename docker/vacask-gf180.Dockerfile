# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE
ARG MODEL_FETCH_IMAGE=debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

FROM ${MODEL_FETCH_IMAGE} AS gf180-models

ARG DEBIAN_FRONTEND=noninteractive
ARG GF180_COMMIT=e7a6777d157a9d94c7ac757457b9e4309e9e9000
ARG GF180_COMMON_SHA256=f7584fe2d0622d0d3fb8db3d5bc1f27a6697ab80e853d0f6ba14a55ab3c9f476

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl zstd \
 && rm -rf /var/lib/apt/lists/*

# Same open_pdks snapshot as circuit-bench-gf180-ngspice. VACASK's converter
# reads the ngspice models of one variant; gf180mcuD is the one converted.
RUN mkdir -p /tmp/gf180 /opt/gf180/pdk/gf180mcuD/libs.tech \
 && curl --fail --location --retry 5 --retry-all-errors \
      --output /tmp/gf180-common.tar.zst \
      "https://github.com/fossi-foundation/ciel-releases/releases/download/gf180mcu-${GF180_COMMIT}/common.tar.zst" \
 && echo "${GF180_COMMON_SHA256}  /tmp/gf180-common.tar.zst" | sha256sum -c - \
 && tar --use-compress-program=unzstd -xf /tmp/gf180-common.tar.zst -C /tmp/gf180 \
      --wildcards 'gf180mcuD/libs.tech/ngspice/*' \
 && cp -a /tmp/gf180/gf180mcuD/libs.tech/ngspice /opt/gf180/pdk/gf180mcuD/libs.tech/

# Convert with VACASK's own gf180tovc. The converted library loads VACASK's
# bundled SPICE-compatible OSDI models (BSIM4, BJT, diode, R, C).
FROM ${BASE_IMAGE} AS gf180-vacask

COPY --from=gf180-models /opt/gf180 /opt/gf180

RUN cd /opt/gf180/pdk \
 && PDK_ROOT=/opt/gf180/pdk PDK=gf180mcuD PYTHONPATH=/usr/lib/vacask/python \
      python3 -m gf180tovc > /tmp/gf180tovc.log 2>&1 \
 || { cat /tmp/gf180tovc.log; exit 1; } \
 && printf '%s\n' \
      '# VACASK configuration for the converted GF180MCU (gf180mcuD) models.' \
      '[Paths]' \
      'include_path_prefix = [ "/opt/gf180/pdk/gf180mcuD/libs.tech/vacask/models" ]' \
      'module_path_prefix = [ "/usr/lib/vacask/mod" ]' \
      > /opt/gf180/pdk/gf180mcuD/libs.tech/vacask/.vacaskrc.toml

FROM ${BASE_IMAGE}

ARG IMAGE_VERSION=dev
ARG GF180_COMMIT=e7a6777d157a9d94c7ac757457b9e4309e9e9000

COPY --from=gf180-vacask /opt/gf180/pdk/gf180mcuD/libs.tech/vacask /opt/gf180/pdk/gf180mcuD/libs.tech/vacask

ENV GF180_PDK_ROOT=/opt/gf180/pdk/gf180mcuD

RUN { vacask -v 2>&1 || true; } | grep -F "This is vacask 0.3.4" \
 && test ! -e /usr/local/bin/check_circuit.py \
 && test -s "${GF180_PDK_ROOT}/libs.tech/vacask/.vacaskrc.toml" \
 && for lib in gf180_vacask_common.lib design.lib mos_tt.lib bjt_tt.lib diode_tt.lib mimcap_tt.lib; do \
      test -s "${GF180_PDK_ROOT}/libs.tech/vacask/models/${lib}" || exit 1; \
    done

LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains" \
      org.opencontainers.image.description="Pinned VACASK and GF180MCU runtime for Circuit-Bench tasks" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.circuit-bench.vacask.version="0.3.4" \
      org.circuit-bench.gf180mcu.commit="${GF180_COMMIT}"

CMD ["bash"]
