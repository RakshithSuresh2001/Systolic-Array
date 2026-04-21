# ==============================================================================
# config.mk — OpenROAD Flow Configuration: 8x8 Weight-Stationary Systolic Array
# ------------------------------------------------------------------------------
# Author      : Rakshith Suresh
# Affiliation : MS Electrical Engineering (VLSI Design & Verification)
#               University of Southern California, Viterbi School of Engineering
# Email       : rsuresh@usc.edu
# GitHub      : https://github.com/RakshithSuresh2001
# ------------------------------------------------------------------------------
# PDK         : SkyWater 130nm (sky130hd)
# Corner      : TT (Typical-Typical), 025C, 1V80
# Tool        : OpenROAD v2.0, Yosys 0.44
# Clock       : 20ns period (50 MHz target)
# ==============================================================================

export DESIGN_NAME   = systolic_array
export PLATFORM      = sky130hd

# RTL source files
export VERILOG_FILES = $(DESIGN_DIR)/src/pe_yosys.sv \
                       $(DESIGN_DIR)/src/systolic_array_yosys.sv

# Timing constraints
export SDC_FILE      = $(DESIGN_DIR)/constraint.sdc

# Clock period in ps (20ns = 50 MHz)
export CLOCK_PERIOD  = 20000

# Placement density
export PLACE_DENSITY = 0.65

# Disable features not supported by installed tool versions
#export SYNTH_HDL_FRONTEND = verilog   # disabled — use default read_verilog
export EQUIVALENCE_CHECK  = 0
export LEC_CHECK          = 0
export SKIP_DETAILED_ROUTE = 0
