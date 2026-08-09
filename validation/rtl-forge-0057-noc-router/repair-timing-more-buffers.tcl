rename repair_timing_helper repair_timing_helper_default

proc repair_timing_helper {args} {
  uplevel 1 [list repair_timing_helper_default -max_buffer_percent 50 {*}$args]
}
