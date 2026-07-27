# This is an amd64 image because the pinned OpenROAD base is published for
# linux/amd64.
ARG BASE_IMAGE=ghcr.io/arcadia-1/circuit-bench-openroad-asap7@sha256:82463d5abf9dc0c8f4f402f78f544ba193a4ecea62b0397a5b193388062d3f92
FROM ${BASE_IMAGE}

ARG IMAGE_VERSION=1.0.0

LABEL org.opencontainers.image.title="RTL-Forge OpenROAD ASAP7 runtime"
LABEL org.opencontainers.image.description="Public RTL-Forge-compatible OpenROAD, ASAP7, Yosys, and Icarus toolchain contract"
LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"

ENV OPENROAD_EXE="/opt/openroad/bin/openroad"
ENV ASAP7_PLATFORM_DIR="/opt/orfs/flow/platforms/asap7"
ENV LD_LIBRARY_PATH="/opt/openroad/lib:/opt/cudd/lib:${LD_LIBRARY_PATH}"
ENV PATH="/opt/openroad/bin:/opt/oss-cad-suite/bin:${PATH}"
ENV RTL_FORGE_OSS_CAD_SUITE_RELEASE="2026-06-20"
ENV RTL_FORGE_OPENROAD_SOURCE_DATE="2026-06-15"
ENV RTL_FORGE_ASAP7_SOURCE_DATE="2026-06-17"
ENV RTL_FORGE_OPENROAD_IMAGE_VERSION="${IMAGE_VERSION}"

RUN test -x "$OPENROAD_EXE" \
    && test -x /opt/oss-cad-suite/bin/yosys \
    && test -x /opt/oss-cad-suite/bin/iverilog \
    && test -f "$ASAP7_PLATFORM_DIR/lef/asap7_tech_1x_201209.lef" \
    && test -f "$ASAP7_PLATFORM_DIR/lib/NLDM/asap7sc7p5t_SEQ_RVT_FF_nldm_220123.lib" \
    && "$OPENROAD_EXE" -version \
    && yosys -V \
    && iverilog -V >/tmp/iverilog-version.txt \
    && python3 --version \
    && ! ldd "$OPENROAD_EXE" 2>&1 | grep -F "not found" \
    && rm -f /tmp/iverilog-version.txt

WORKDIR /app
CMD ["/bin/bash"]
