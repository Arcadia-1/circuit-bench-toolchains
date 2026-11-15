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

# The four GF180MCU variants ship the same ngspice model files; all four are
# kept so that task decks can name the variant they are written for.
RUN mkdir -p /tmp/gf180 /opt/gf180/pdk \
 && curl --fail --location --retry 5 --retry-all-errors \
      --output /tmp/gf180-common.tar.zst \
      "https://github.com/fossi-foundation/ciel-releases/releases/download/gf180mcu-${GF180_COMMIT}/common.tar.zst" \
 && echo "${GF180_COMMON_SHA256}  /tmp/gf180-common.tar.zst" | sha256sum -c - \
 && tar --use-compress-program=unzstd -xf /tmp/gf180-common.tar.zst -C /tmp/gf180 \
      --wildcards '*/libs.tech/ngspice/*' \
 && for variant in A B C D; do \
      mkdir -p "/opt/gf180/pdk/gf180mcu${variant}/libs.tech" \
      && cp -a "/tmp/gf180/gf180mcu${variant}/libs.tech/ngspice" \
           "/opt/gf180/pdk/gf180mcu${variant}/libs.tech/" \
      || exit 1; \
    done

FROM ${BASE_IMAGE}

ARG IMAGE_VERSION=dev
ARG GF180_COMMIT=e7a6777d157a9d94c7ac757457b9e4309e9e9000

COPY --from=gf180-models /opt/gf180 /opt/gf180

ENV GF180_PDK_ROOT=/opt/gf180/pdk/gf180mcuD

RUN test "$(command -v ngspice)" = /opt/ngspice/bin/ngspice \
 && ngspice --version | grep -F "ngspice-47" \
 && python3 -c 'import numpy' \
 && test ! -e /usr/local/bin/check_circuit.py \
 && for variant in A B C D; do \
      for model in design.ngspice sm141064.ngspice sm141064_mim.ngspice smbb000149.ngspice; do \
        test -s "/opt/gf180/pdk/gf180mcu${variant}/libs.tech/ngspice/${model}" || exit 1; \
      done; \
    done

LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains" \
      org.opencontainers.image.description="Pinned ngspice and GF180MCU runtime for Circuit-Bench tasks" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.circuit-bench.ngspice.version="47" \
      org.circuit-bench.gf180mcu.commit="${GF180_COMMIT}"

CMD ["bash"]
