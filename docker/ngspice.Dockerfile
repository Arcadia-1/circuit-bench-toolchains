# syntax=docker/dockerfile:1.7

ARG DEBIAN_BASE=debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

FROM ${DEBIAN_BASE} AS ngspice-builder

ARG DEBIAN_FRONTEND=noninteractive
ARG NGSPICE_VERSION=46
ARG NGSPICE_SHA256=a0d1699af1940b06649276dcd6ff5a566c8c0cad01b2f7b5e99dedbb4d64c19b

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      autoconf \
      automake \
      bison \
      build-essential \
      ca-certificates \
      curl \
      flex \
      gperf \
      libfftw3-dev \
      libreadline-dev \
      libsuitesparse-dev \
      libtool \
 && rm -rf /var/lib/apt/lists/*

RUN curl --fail --location --retry 5 --retry-all-errors \
      --output /tmp/ngspice.tar.gz \
      "https://sourceforge.net/projects/ngspice/files/ng-spice-rework/${NGSPICE_VERSION}/ngspice-${NGSPICE_VERSION}.tar.gz/download" \
 && echo "${NGSPICE_SHA256}  /tmp/ngspice.tar.gz" | sha256sum -c - \
 && mkdir -p /tmp/ngspice-src /tmp/ngspice-build \
 && tar -xzf /tmp/ngspice.tar.gz --strip-components=1 -C /tmp/ngspice-src \
 && cd /tmp/ngspice-build \
 && /tmp/ngspice-src/configure \
      --prefix=/opt/ngspice \
      --disable-dependency-tracking \
      --with-x=no \
      --with-readline=yes \
      --with-fftw3=yes \
      CFLAGS="-O2" \
 && make -j"$(nproc)" \
 && make install \
 && /opt/ngspice/bin/ngspice --version | grep -F "ngspice-${NGSPICE_VERSION}"

FROM ${DEBIAN_BASE}

ARG DEBIAN_FRONTEND=noninteractive
ARG NGSPICE_VERSION=46
ARG IMAGE_VERSION=dev

RUN apt-get update \
 && apt-get purge -y ngspice ngspice-doc \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      git \
      libfftw3-double3 \
      libklu1 \
      libreadline8 \
      python3 \
      python3-numpy \
 && rm -rf /var/lib/apt/lists/*

COPY --from=ngspice-builder /opt/ngspice /opt/ngspice

ENV PATH=/opt/ngspice/bin:${PATH}

RUN test "$(command -v ngspice)" = /opt/ngspice/bin/ngspice \
 && ngspice --version | grep -F "ngspice-${NGSPICE_VERSION}" \
 && python3 -c 'import numpy'

LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains" \
      org.opencontainers.image.description="Pinned ngspice runtime for Circuit-Bench tasks" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.circuit-bench.ngspice.version="${NGSPICE_VERSION}"

CMD ["bash"]
