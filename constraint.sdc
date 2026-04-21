# ==============================================================================
# constraint.sdc — Timing Constraints: 8x8 Weight-Stationary Systolic Array
# ------------------------------------------------------------------------------
# Author      : Rakshith Suresh
# Affiliation : MS Electrical Engineering (VLSI Design & Verification)
#               University of Southern California, Viterbi School of Engineering
# Email       : rsuresh@usc.edu
# ------------------------------------------------------------------------------
# Clock: 20ns period (50 MHz) on SkyWater 130nm sky130hd TT corner
# ==============================================================================

create_clock [get_ports clk] -name clk -period 20.0

set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_transition  0.1 [get_clocks clk]

set_input_delay  2.0 -clock clk [all_inputs]
set_output_delay 2.0 -clock clk [all_outputs]
