# The ASAP7 runtime contract with a current toolchain and a simulator.
#
# circuit-bench-orfs-verilator-coverage carries OpenROAD 26Q3 and Verilator
# 5.050 but no simulator at all -- no Icarus Verilog, no cocotb. The digital
# task corpus puts half its scoring weight on cocotb hidden suites and mapped
# gate-level simulation, and every one of its 57 packages invokes `iverilog`
# and one of the two Python environments below, so that image cannot run them.
#
# circuit-bench-openroad-asap7 runs them, and defines the runtime contract those
# tasks were written against -- /opt/orfs, /opt/oss-cad-suite and the
# /opt/circuit-bench-digital-venv layout are referenced by absolute path in over
# eight hundred files -- but its OpenROAD and Verilator are a release behind.
#
# So this image keeps the ASAP7 runtime exactly as published and grafts the
# newer OpenROAD and Verilator onto it with their dependencies confined.
#
# Pin both bases by manifest digest: a retagged base must not change what this
# builds.
ARG ASAP7_IMAGE=ghcr.io/arcadia-1/circuit-bench-openroad-asap7:1.0.0@sha256:82463d5abf9dc0c8f4f402f78f544ba193a4ecea62b0397a5b193388062d3f92
ARG ORFS_IMAGE=ghcr.io/arcadia-1/circuit-bench-orfs-verilator-coverage:1.0.0@sha256:3046cb6ea2fa3273d24e853a4a1a9d87a9670d46554d55e66ef79dc465072c5a

FROM ${ORFS_IMAGE} AS newtools

FROM ${ASAP7_IMAGE}

ARG IMAGE_VERSION=1.0.0

LABEL org.opencontainers.image.title="Circuit-Bench ASAP7 runtime with current ORFS tools and cocotb"
LABEL org.opencontainers.image.description="The published ASAP7 runtime contract plus OpenROAD 26Q3 and Verilator 5.050, keeping Icarus Verilog and both cocotb environments"
LABEL org.opencontainers.image.source="https://github.com/Arcadia-1/circuit-bench-toolchains"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"

# Verilator 5.050 is self-contained under its own prefix.
COPY --from=newtools /opt/verilator /opt/verilator

# OpenROAD 26Q3, the OR-Tools it links against, and its ORFS Yosys. The Yosys
# matters: the synthesis numbers this image must reproduce were measured against
# the ORFS build, not against the one inside oss-cad-suite.
COPY --from=newtools /OpenROAD-flow-scripts/tools/install/OpenROAD /opt/openroad-26q3
COPY --from=newtools /OpenROAD-flow-scripts/tools/install/yosys /opt/yosys-orfs
COPY --from=newtools /opt/or-tools /opt/or-tools

# The twenty-one system libraries the ASAP7 base does not carry, computed by
# diffing the OpenROAD binary's resolved ldd output between the two images
# rather than guessed. libpython3.10 is among them: OpenROAD embeds Python 3.10
# while this base ships 3.12, which is also why they cannot simply be installed
# over the base.
COPY --from=newtools \
  /lib/x86_64-linux-gnu/libGL.so.1 /lib/x86_64-linux-gnu/libGLX.so.0 \
  /lib/x86_64-linux-gnu/libGLdispatch.so.0 /lib/x86_64-linux-gnu/libQt5Charts.so.5 \
  /lib/x86_64-linux-gnu/libQt5Core.so.5 /lib/x86_64-linux-gnu/libQt5Gui.so.5 \
  /lib/x86_64-linux-gnu/libQt5Widgets.so.5 /lib/x86_64-linux-gnu/libdouble-conversion.so.3 \
  /lib/x86_64-linux-gnu/libfreetype.so.6 /lib/x86_64-linux-gnu/libglib-2.0.so.0 \
  /lib/x86_64-linux-gnu/libgraphite2.so.3 /lib/x86_64-linux-gnu/libharfbuzz.so.0 \
  /lib/x86_64-linux-gnu/libicudata.so.70 /lib/x86_64-linux-gnu/libicui18n.so.70 \
  /lib/x86_64-linux-gnu/libicuuc.so.70 /lib/x86_64-linux-gnu/libmd4c.so.0 \
  /lib/x86_64-linux-gnu/libpcre.so.3 /lib/x86_64-linux-gnu/libpcre2-16.so.0 \
  /lib/x86_64-linux-gnu/libpng16.so.16 /lib/x86_64-linux-gnu/libpython3.10.so.1.0 \
  /lib/x86_64-linux-gnu/libyaml-cpp.so.0.7 \
  /opt/openroad-26q3/extralib/

# Those libraries are reached only from here. Several of them -- libpng,
# libfreetype, libglib, libpython3.10 -- would shadow the base's own if
# LD_LIBRARY_PATH were set globally, and the simulation stack depends on the
# base's versions.
COPY docker/asap7-cocotb-openroad /opt/cb-unified/bin/openroad
RUN chmod 755 /opt/cb-unified/bin/openroad

# The base PATH begins with /opt/openroad/bin, so a prefix is required for the
# new binaries to win. Everything after it is inherited unchanged: iverilog,
# vvp and both Python environments keep resolving exactly where the task corpus
# expects them.
ENV PATH=/opt/cb-unified/bin:/opt/verilator/bin:/opt/yosys-orfs/bin:$PATH
ENV VERILATOR_ROOT=/opt/verilator/share/verilator

# Fail the build rather than publish an image whose tools resolve to the wrong
# copies. An earlier attempt at this graft silently downgraded Icarus Verilog
# from 14.0 to 13.0 by putting a directory first without checking what was
# already in it.
RUN set -eu; \
    openroad -version | grep -q '^26Q3-'; \
    verilator --version | grep -q 'Verilator 5.050'; \
    yosys -V | grep -q '0.68'; \
    iverilog -V | head -1 | grep -q 'version 14'; \
    test "$(command -v iverilog)" = /opt/oss-cad-suite/bin/iverilog; \
    /opt/oss-cad-suite/py3bin/python3.11 -c 'import cocotb; assert cocotb.__version__.startswith("2.1")'; \
    /opt/circuit-bench-digital-venv/bin/python3 -c 'import sys, cocotb, numpy, scipy; assert sys.version.startswith("3.12"); assert cocotb.__version__ == "2.0.1"'; \
    test -d /opt/orfs/flow/platforms/asap7
