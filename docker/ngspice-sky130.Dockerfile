# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE
ARG MODEL_FETCH_IMAGE=debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

FROM ${MODEL_FETCH_IMAGE} AS sky130-models

ARG DEBIAN_FRONTEND=noninteractive
ARG SKY130_COMMIT=c6d73a35f524070e85faff4a6a9eef49553ebc2b
ARG SKY130_COMMON_SHA256=8a7f06212c6d9fa5a1da6145f559f48a903434a5c5b6cd5352363700b6cadb94
ARG SKY130_FD_PR_SHA256=dcb49c7450dfb55c91ce315d258563895df1ed75d4a9090064aade8290030a87

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl zstd \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/sky130 /opt/sky130/continuous \
      /opt/sky130/pdk/sky130A/libs.tech \
      /opt/sky130/pdk/sky130A/libs.ref/sky130_fd_pr \
 && curl --fail --location --retry 5 --retry-all-errors \
      --output /tmp/sky130-common.tar.zst \
      "https://github.com/chipfoundry/volare/releases/download/sky130-${SKY130_COMMIT}/common.tar.zst" \
 && curl --fail --location --retry 5 --retry-all-errors \
      --output /tmp/sky130-fd-pr.tar.zst \
      "https://github.com/chipfoundry/volare/releases/download/sky130-${SKY130_COMMIT}/sky130_fd_pr.tar.zst" \
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
ARG SKY130_COMMIT=c6d73a35f524070e85faff4a6a9eef49553ebc2b

COPY --from=sky130-models /opt/sky130 /opt/sky130
COPY tools/netlist_checker/check_circuit.py /usr/local/bin/check_circuit.py
COPY tools/netlist_checker/sky130_pdk_subcircuits.txt /opt/circuit-bench/sky130_pdk_subcircuits.txt

ENV SKY130_MODEL_LIB=/opt/sky130/continuous/sky130.lib.spice \
    SKY130_PDK_ROOT=/opt/sky130/pdk/sky130A \
    SKY130_PDK_SUBCIRCUITS=/opt/circuit-bench/sky130_pdk_subcircuits.txt

RUN chmod 0755 /usr/local/bin/check_circuit.py \
 && test "$(command -v ngspice)" = /opt/ngspice/bin/ngspice \
 && ngspice --version | grep -F "ngspice-46" \
 && python3 -c 'import numpy' \
 && test -x /usr/local/bin/check_circuit.py \
 && test -s "${SKY130_PDK_SUBCIRCUITS}" \
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
      org.circuit-bench.ngspice.version="46" \
      org.circuit-bench.sky130.commit="${SKY130_COMMIT}"

CMD ["bash"]
