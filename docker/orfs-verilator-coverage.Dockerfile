# Full upstream ORFS is currently published only for linux/amd64. Pin both the
# tag and manifest digest so a rebuild cannot silently select a retagged base.
ARG ORFS_IMAGE=openroad/orfs:26Q3-273-g9768f0f54@sha256:eae643bb3ae0c6facc88fabee0e08760932504bedc3a719326536025183c5bd2
FROM ${ORFS_IMAGE}

ARG IMAGE_VERSION=1.0.0
ARG VERILATOR_VERSION=5.050
ARG VERILATOR_COMMIT=848d926ebd4addacacd294dc84e35d9d4ae8078c

LABEL org.opencontainers.image.title="Circuit-Bench full ORFS with Verilator coverage"
LABEL org.opencontainers.image.description="Pinned upstream ORFS RTL-to-GDS flow plus Verilator code and toggle coverage"
LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.revision="9768f0f5432c77b215be1ff3ce7a3417f2b27bcd"

# Build the released Verilator revision instead of accepting a distribution
# package whose version could change with the upstream ORFS base.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf \
        bison \
        build-essential \
        ca-certificates \
        flex \
        git \
        help2man \
        libfl-dev \
        make \
        perl \
        python3 \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git init /tmp/verilator \
    && git -C /tmp/verilator remote add origin https://github.com/verilator/verilator.git \
    && git -C /tmp/verilator fetch --depth 1 origin "${VERILATOR_COMMIT}" \
    && git -C /tmp/verilator checkout --detach FETCH_HEAD \
    && test "$(git -C /tmp/verilator rev-parse HEAD)" = "${VERILATOR_COMMIT}" \
    && cd /tmp/verilator \
    && autoconf \
    && ./configure --prefix=/opt/verilator \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/verilator

ENV ORFS_ROOT=/OpenROAD-flow-scripts
ENV FLOW_HOME=/OpenROAD-flow-scripts/flow
ENV OPENROAD=/OpenROAD-flow-scripts/tools/OpenROAD
ENV VERILATOR_ROOT=/opt/verilator/share/verilator
ENV PATH=/opt/verilator/bin:/OpenROAD-flow-scripts/tools/install/OpenROAD/bin:/OpenROAD-flow-scripts/tools/install/yosys/bin:${PATH}

RUN test -f "$FLOW_HOME/Makefile" \
    && test -d "$FLOW_HOME/scripts" \
    && test -d "$FLOW_HOME/util" \
    && test -d "$FLOW_HOME/designs" \
    && test -d "$FLOW_HOME/platforms" \
    && command -v openroad \
    && command -v yosys \
    && command -v klayout \
    && verilator --version | grep -F "${VERILATOR_VERSION}" \
    && verilator_coverage --version

WORKDIR /OpenROAD-flow-scripts/flow
CMD ["/bin/bash"]
