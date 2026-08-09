# Preserve the RTL-Forge task's public 1 GHz timing contract.
source /rtlforge/constraints/noc_router_asap7.sdc

# The public task stops at mapped synthesis and does not constrain the
# high-fanout asynchronous reset tree. Full P&R needs a physical fanout target
# so reset slew remains legal after routed parasitic extraction.
set_max_fanout 20 [current_design]
