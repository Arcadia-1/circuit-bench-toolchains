export PLATFORM = asap7

export DESIGN_NAME = noc_router
export DESIGN_NICKNAME = rtl_forge_0057_noc_router

# The RTL-Forge source and public constraint are mounted read-only at /rtlforge.
export VERILOG_FILES = /rtlforge/rtl/noc_router.sv
export VERILOG_INCLUDE_DIRS = /rtlforge/rtl
export SDC_FILE = /config/noc-router-full-pnr.sdc

export CORE_UTILIZATION = 40
export CORE_ASPECT_RATIO = 1
export CORE_MARGIN = 2
export PLACE_DENSITY = 0.60
export TNS_END_PERCENT = 100

# Over-repair hold by 10 ps before detailed routing so post-route extracted
# parasitics do not turn a barely-positive global-route path negative.
export HOLD_SLACK_MARGIN = 10

# This task was originally calibrated only for synthesis-stage setup STA. Full
# P&R exposes many short min-delay paths after CTS, so allow repair_timing more
# headroom than OpenROAD's default 20% hold-buffer cap.
export PRE_CTS_TCL = /config/repair-timing-more-buffers.tcl
export PRE_GLOBAL_ROUTE_TCL = /config/repair-timing-more-buffers.tcl

export SYNTH_USE_SYN = 1
