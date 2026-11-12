# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE
ARG MODEL_FETCH_IMAGE=debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

FROM ${MODEL_FETCH_IMAGE} AS gf180-models

ARG DEBIAN_FRONTEND=noninteractive
ARG GF180_COMMIT=792ef67037d74c8c51811eab3ce23cf793491296
ARG GF180_COMMON_SHA256=1342fe46866de6a3f1d8c3edb3193dafa4c3cf955cb987a17791b2287c41e39d

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
ARG GF180_COMMIT=792ef67037d74c8c51811eab3ce23cf793491296

COPY --from=gf180-models /opt/gf180 /opt/gf180

ENV GF180_PDK_ROOT=/opt/gf180/pdk/gf180mcuD

RUN test "$(command -v ngspice)" = /opt/ngspice/bin/ngspice \
 && ngspice --version | grep -F "ngspice-46" \
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
      org.circuit-bench.ngspice.version="46" \
      org.circuit-bench.gf180mcu.commit="${GF180_COMMIT}"

CMD ["bash"]
