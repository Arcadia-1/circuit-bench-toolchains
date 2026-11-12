# syntax=docker/dockerfile:1.7

# Policy-free Xyce base: serial Xyce 7.10.0 on Trilinos 14.4, built with
# Verilog-A plugin support (Xyce/ADMS). The compiler, admsXml and
# buildxyceplugin stay in the image so PDK layers can build model plugins.
ARG BUILD_IMAGE=debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

FROM ${BUILD_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG JOBS=4
ARG IMAGE_VERSION=dev
ARG TRILINOS_TAG=trilinos-release-14-4-0
ARG TRILINOS_SHA256=8e7d881cf6677aa062f7bfea8baa1e52e8956aa575d6a4f90f2b6f032632d4c6
ARG XYCE_TAG=Release-7.10.0
ARG XYCE_SHA256=b5a883196f0a2b3972fd13c541fecf04735bfabc7d124d7c7e17de707204f4e2

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl cmake make g++ gfortran bison flex libfl-dev bc \
      libblas-dev liblapack-dev libsuitesparse-dev libfftw3-dev adms \
      python3 python3-numpy \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN curl --fail --location --retry 5 --retry-all-errors -o trilinos.tar.gz \
      "https://github.com/trilinos/Trilinos/archive/refs/tags/${TRILINOS_TAG}.tar.gz" \
 && echo "${TRILINOS_SHA256}  trilinos.tar.gz" | sha256sum -c - \
 && curl --fail --location --retry 5 --retry-all-errors -o xyce.tar.gz \
      "https://github.com/Xyce/Xyce/archive/refs/tags/${XYCE_TAG}.tar.gz" \
 && echo "${XYCE_SHA256}  xyce.tar.gz" | sha256sum -c - \
 && tar xzf trilinos.tar.gz && tar xzf xyce.tar.gz && rm -f trilinos.tar.gz xyce.tar.gz

# Trilinos with the option set Xyce ships for a serial build.
RUN mkdir tri-build && cd tri-build \
 && cmake -C "/build/Xyce-${XYCE_TAG}/cmake/trilinos/trilinos-base.cmake" \
      -D CMAKE_INSTALL_PREFIX=/opt/trilinos \
      -D AMD_INCLUDE_DIRS=/usr/include/suitesparse \
      "/build/Trilinos-${TRILINOS_TAG}" > /build/trilinos-configure.log \
 && cmake --build . -j "${JOBS}" -t install > /build/trilinos-build.log 2>&1 \
 && cd .. && rm -rf tri-build "Trilinos-${TRILINOS_TAG}"

RUN mkdir xyce-build && cd xyce-build \
 && cmake -D CMAKE_INSTALL_PREFIX=/opt/xyce -D Trilinos_ROOT=/opt/trilinos \
      -D Xyce_PLUGIN_SUPPORT=ON -D BUILD_SHARED_LIBS=ON \
      "/build/Xyce-${XYCE_TAG}" > /build/xyce-configure.log \
 && cmake --build . -j "${JOBS}" -t install > /build/xyce-build.log 2>&1 \
 && cd / && rm -rf /build \
 && ln -s buildxyceplugin.sh /opt/xyce/bin/buildxyceplugin

ENV PATH=/opt/xyce/bin:${PATH} \
    LD_LIBRARY_PATH=/opt/xyce/lib:/opt/trilinos/lib

RUN Xyce -v | grep -F "Xyce Release 7.10.0" \
 && test -x /opt/xyce/bin/admsXml \
 && test -x /opt/xyce/bin/buildxyceplugin \
 && python3 -c 'import numpy' \
 && test ! -e /usr/local/bin/check_circuit.py

WORKDIR /work

LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains" \
      org.opencontainers.image.description="Pinned Xyce 7.10.0 (serial, Verilog-A plugin support) for Circuit-Bench tasks" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.circuit-bench.xyce.version="7.10.0" \
      org.circuit-bench.trilinos.version="14.4.0"

CMD ["bash"]
