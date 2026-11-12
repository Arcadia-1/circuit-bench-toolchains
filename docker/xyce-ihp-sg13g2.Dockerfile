# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE
ARG SOURCE_FETCH_IMAGE=debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

# Same IHP-Open-PDK commit as circuit-bench-ihp-sg13g2-ngspice.
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
      /ihp-sg13g2/libs.tech/xyce/ /ihp-sg13g2/libs.tech/verilog-a/ \
 && git checkout --quiet "${IHP_COMMIT}" \
 && test "$(git rev-parse HEAD)" = "${IHP_COMMIT}" \
 && mkdir -p /opt/ihp/pdk \
 && cp -a ihp-sg13g2 /opt/ihp/pdk/ \
 && cp LICENSE /opt/ihp/pdk/ihp-sg13g2/LICENSE

# Build the PSP103 and R3_CMC Verilog-A models into Xyce plugins. Each model is
# built in a copy of its own directory because admsXml resolves `include
# files relative to the working directory. The mosvar varactor model does not
# get through Xyce/ADMS and is left out.
FROM ${BASE_IMAGE} AS ihp-plugins

COPY --from=ihp-src /opt/ihp /opt/ihp

RUN set -e; \
    plugins=/opt/ihp/pdk/ihp-sg13g2/libs.tech/xyce/plugins; \
    mkdir -p "${plugins}"; \
    for model in psp103 r3_cmc; do \
      rm -rf "/tmp/build-${model}"; \
      cp -a "/opt/ihp/pdk/ihp-sg13g2/libs.tech/verilog-a/${model}" "/tmp/build-${model}"; \
      cd "/tmp/build-${model}"; \
      buildxyceplugin "/tmp/build-${model}/${model}.va" "/tmp/build-${model}" \
        || { cat buildxyceplugin.log; exit 1; }; \
      cp -a /tmp/build-${model}/*.so "${plugins}/"; \
    done; \
    ls -l "${plugins}"

FROM ${BASE_IMAGE}

ARG IMAGE_VERSION=dev
ARG IHP_COMMIT=0dedf265f0cad6ef81aeb64b9ddd17eef88c0460

COPY --from=ihp-plugins /opt/ihp /opt/ihp

ENV PDK_ROOT=/opt/ihp/pdk \
    PDK=ihp-sg13g2 \
    IHP_PDK_ROOT=/opt/ihp/pdk/ihp-sg13g2 \
    IHP_XYCE_PLUGINS=/opt/ihp/pdk/ihp-sg13g2/libs.tech/xyce/plugins/libXyce_Plugin_PSP103_VA.so,/opt/ihp/pdk/ihp-sg13g2/libs.tech/xyce/plugins/libXyce_Plugin_r3_cmc.so

RUN Xyce -v | grep -F "Xyce Release 7.10.0" \
 && test ! -e /usr/local/bin/check_circuit.py \
 && for plugin in $(echo "${IHP_XYCE_PLUGINS}" | tr , ' '); do test -s "${plugin}" || exit 1; done \
 && for lib in cornerMOSlv.lib cornerMOShv.lib cornerRES.lib cornerCAP.lib cornerHBT.lib cornerDIO.lib; do \
      test -s "${IHP_PDK_ROOT}/libs.tech/xyce/models/${lib}" || exit 1; \
    done

LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains" \
      org.opencontainers.image.description="Pinned Xyce and IHP SG13G2 runtime for Circuit-Bench tasks" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.circuit-bench.xyce.version="7.10.0" \
      org.circuit-bench.ihp-sg13g2.commit="${IHP_COMMIT}"

CMD ["bash"]
