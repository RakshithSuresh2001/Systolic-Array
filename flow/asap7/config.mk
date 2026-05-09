export PLATFORM           = asap7
export DESIGN_NAME        = systolic_array
export VERILOG_FILES      = $(DESIGN_DIR)/systolic_array.sv \
                            $(DESIGN_DIR)/pe.sv
export SDC_FILE           = $(DESIGN_DIR)/constraint.sdc

export CORE_UTILIZATION   = 15
export CORE_ASPECT_RATIO  = 1
export CORE_MARGIN        = 2
export PLACE_DENSITY      = 0.55

export CLOCK_PERIOD       = 2000
export SYNTH_ABC_SCRIPT = $(PLATFORM_DIR)/abc_area.script
export ABC_AREA = 1
export LEC_ENABLE = 0
export LEC_CHECK = 0
export PDN_TCL = $(DESIGN_DIR)/pdn.tcl
