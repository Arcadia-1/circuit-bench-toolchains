# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE
ARG SOURCE_FETCH_IMAGE=debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

# Same IHP-Open-PDK commit as the other IHP images. VACASK 0.3.4's converter
# needs exactly this generation of the model files.
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
      /ihp-sg13g2/libs.tech/ngspice/ /ihp-sg13g2/libs.tech/verilog-a/ /ihp-sg13g2/libs.tech/xschem/ \
      /ihp-sg13g2/libs.ref/sg13g2_stdcell/spice/ /ihp-sg13g2/libs.ref/sg13g2_io/spice/ \
 && git checkout --quiet "${IHP_COMMIT}" \
 && test "$(git rev-parse HEAD)" = "${IHP_COMMIT}" \
 && mkdir -p /opt/ihp/pdk \
 && cp -a ihp-sg13g2 /opt/ihp/pdk/ \
 && cp LICENSE /opt/ihp/pdk/ihp-sg13g2/LICENSE

# Convert with VACASK's own sg13g2tovc: it translates the ngspice models and
# standard cells and compiles the PDK's Verilog-A models to OSDI (generic
# x86-64). Its last step patches xschem symbols, which needs a directory the
# repository does not ship; an empty one lets it finish.
FROM ${BASE_IMAGE} AS ihp-vacask

COPY --from=ihp-src /opt/ihp /opt/ihp

RUN mkdir -p /opt/ihp/pdk/ihp-sg13g2/libs.tech/xschem/sg13g2_stdcells \
 && cd /opt/ihp/pdk \
 && PDK_ROOT=/opt/ihp/pdk PDK=ihp-sg13g2 PYTHONPATH=/usr/lib/vacask/python \
      python3 -m sg13g2tovc --openvaf-options --target_cpu generic > /tmp/sg13g2tovc.log 2>&1 \
 || { cat /tmp/sg13g2tovc.log; exit 1; }

FROM ${BASE_IMAGE}

ARG IMAGE_VERSION=dev
ARG IHP_COMMIT=0dedf265f0cad6ef81aeb64b9ddd17eef88c0460

COPY --from=ihp-vacask /opt/ihp/pdk/ihp-sg13g2/LICENSE /opt/ihp/pdk/ihp-sg13g2/LICENSE
COPY --from=ihp-vacask /opt/ihp/pdk/ihp-sg13g2/libs.tech/vacask /opt/ihp/pdk/ihp-sg13g2/libs.tech/vacask
COPY --from=ihp-vacask /opt/ihp/pdk/ihp-sg13g2/libs.tech/verilog-a /opt/ihp/pdk/ihp-sg13g2/libs.tech/verilog-a
COPY --from=ihp-vacask /opt/ihp/pdk/ihp-sg13g2/libs.ref/sg13g2_stdcell/vacask /opt/ihp/pdk/ihp-sg13g2/libs.ref/sg13g2_stdcell/vacask
COPY --from=ihp-vacask /opt/ihp/pdk/ihp-sg13g2/libs.ref/sg13g2_io/vacask /opt/ihp/pdk/ihp-sg13g2/libs.ref/sg13g2_io/vacask

# The converter's .vacaskrc.toml refers to $(PDK_ROOT)/$(PDK).
ENV PDK_ROOT=/opt/ihp/pdk \
    PDK=ihp-sg13g2 \
    IHP_PDK_ROOT=/opt/ihp/pdk/ihp-sg13g2

RUN { vacask -v 2>&1 || true; } | grep -F "This is vacask 0.3.4" \
 && test ! -e /usr/local/bin/check_circuit.py \
 && test -s "${IHP_PDK_ROOT}/libs.tech/vacask/.vacaskrc.toml" \
 && test -s "${IHP_PDK_ROOT}/libs.tech/vacask/models/sg13g2_vacask_common.lib" \
 && for model in psp103 psp103_nqs r3_cmc mosvar; do \
      test -s "${IHP_PDK_ROOT}/libs.tech/vacask/osdi/${model}.osdi" || exit 1; \
    done

LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains" \
      org.opencontainers.image.description="Pinned VACASK and IHP SG13G2 runtime for Circuit-Bench tasks" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.circuit-bench.vacask.version="0.3.4" \
      org.circuit-bench.ihp-sg13g2.commit="${IHP_COMMIT}"

CMD ["bash"]
