# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE
ARG MODEL_FETCH_IMAGE=debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

FROM ${MODEL_FETCH_IMAGE} AS sky130-models

ARG DEBIAN_FRONTEND=noninteractive
ARG SKY130_COMMIT=e7a6777d157a9d94c7ac757457b9e4309e9e9000
ARG SKY130_COMMON_SHA256=00633ea50acdb6c92044bf7467a3a9048b3d685cd9489e45ea58cd82f8d99a8d
ARG SKY130_FD_PR_SHA256=1a0ba63249fda16a337508a5e3126bfa598c4e7fdab843078353db3f261086af

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl zstd \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/sky130 /opt/sky130/continuous \
      /opt/sky130/pdk/sky130A/libs.tech \
      /opt/sky130/pdk/sky130A/libs.ref/sky130_fd_pr \
 && curl --fail --location --retry 5 --retry-all-errors \
      --output /tmp/sky130-common.tar.zst \
      "https://github.com/fossi-foundation/ciel-releases/releases/download/sky130-${SKY130_COMMIT}/common.tar.zst" \
 && curl --fail --location --retry 5 --retry-all-errors \
      --output /tmp/sky130-fd-pr.tar.zst \
      "https://github.com/fossi-foundation/ciel-releases/releases/download/sky130-${SKY130_COMMIT}/sky130_fd_pr.tar.zst" \
 && echo "${SKY130_COMMON_SHA256}  /tmp/sky130-common.tar.zst" | sha256sum -c - \
 && echo "${SKY130_FD_PR_SHA256}  /tmp/sky130-fd-pr.tar.zst" | sha256sum -c - \
 && tar --use-compress-program=unzstd -xf /tmp/sky130-common.tar.zst -C /tmp/sky130 \
 && tar --use-compress-program=unzstd -xf /tmp/sky130-fd-pr.tar.zst -C /tmp/sky130 \
 && SRC=/tmp/sky130/sky130A \
 && cp -a "${SRC}/libs.tech/combined/continuous/." /opt/sky130/continuous/ \
 && cp -a "${SRC}/libs.tech/ngspice" /opt/sky130/pdk/sky130A/libs.tech/ \
 && cp -a "${SRC}/libs.ref/sky130_fd_pr/spice" /opt/sky130/pdk/sky130A/libs.ref/sky130_fd_pr/

FROM ${BASE_IMAGE}

ARG IMAGE_VERSION=dev
ARG SKY130_COMMIT=e7a6777d157a9d94c7ac757457b9e4309e9e9000

COPY --from=sky130-models /opt/sky130 /opt/sky130

ENV SKY130_MODEL_LIB=/opt/sky130/continuous/sky130.lib.spice \
    SKY130_PDK_ROOT=/opt/sky130/pdk/sky130A

RUN test "$(command -v ngspice)" = /opt/ngspice/bin/ngspice \
 && ngspice --version | grep -F "ngspice-47" \
 && python3 -c 'import numpy' \
 && test ! -e /usr/local/bin/check_circuit.py \
 && test -f "${SKY130_MODEL_LIB}" \
 && test -f "${SKY130_PDK_ROOT}/libs.tech/ngspice/sky130.lib.spice" \
 && test -f "${SKY130_PDK_ROOT}/libs.tech/ngspice/corners/tt/specialized_cells.spice" \
 && test -f "${SKY130_PDK_ROOT}/libs.ref/sky130_fd_pr/spice/sky130_fd_pr__cap_var_hvt.model.spice" \
 && test -f "${SKY130_PDK_ROOT}/libs.tech/ngspice/sky130_fd_pr__model__inductors.model.spice" \
 && test -f "${SKY130_PDK_ROOT}/libs.ref/sky130_fd_pr/spice/sky130_fd_pr__cap_var_lvt.model.spice" \
 && test -f "${SKY130_PDK_ROOT}/libs.ref/sky130_fd_pr/spice/sky130_fd_pr__ind_03_90.model.spice" \
 && test -f "${SKY130_PDK_ROOT}/libs.ref/sky130_fd_pr/spice/sky130_fd_pr__ind_05_125.model.spice" \
 && test -f "${SKY130_PDK_ROOT}/libs.ref/sky130_fd_pr/spice/sky130_fd_pr__ind_05_220.model.spice" \
 && test -f "${SKY130_PDK_ROOT}/libs.ref/sky130_fd_pr/spice/sky130_fd_pr__cap_mim_m3_1.model.spice" \
 && test -f "${SKY130_PDK_ROOT}/libs.ref/sky130_fd_pr/spice/sky130_fd_pr__cap_vpp_04p4x04p6_m1m2_noshield.model.spice"

LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains" \
      org.opencontainers.image.description="Pinned ngspice and Sky130 runtime for Circuit-Bench tasks" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.circuit-bench.ngspice.version="47" \
      org.circuit-bench.sky130.commit="${SKY130_COMMIT}"

CMD ["bash"]
