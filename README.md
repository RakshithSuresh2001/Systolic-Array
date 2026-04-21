# 8×8 Weight-Stationary Systolic Array — RTL to GDS on SkyWater 130nm

**Author:** Rakshith Suresh  
**Affiliation:** MS Electrical Engineering (VLSI Design & Verification)  
University of Southern California, Viterbi School of Engineering  
**Email:** rsuresh@usc.edu | **GitHub:** [RakshithSuresh2001](https://github.com/RakshithSuresh2001)

---

## Overview

A fully custom, tapeout-ready **8×8 weight-stationary systolic array accelerator** designed and implemented from scratch in SystemVerilog, taken through a complete **RTL-to-GDS physical design flow** using open-source EDA tools on the SkyWater 130nm process design kit.

This architecture is the compute backbone of matrix-multiplication engines used in AI/ML inference accelerators (e.g., Google TPU). Each processing element (PE) performs a MAC operation every clock cycle, enabling highly parallel, pipelined matrix-vector multiplication with minimal data movement.

---

## Architecture

```
Activations (left edge, 1 per row)
        │       │       │       │       │       │       │       │
        ▼       ▼       ▼       ▼       ▼       ▼       ▼       ▼
     ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
     │PE00 │→│PE01 │→│PE02 │→│PE03 │→│PE04 │→│PE05 │→│PE06 │→│PE07 │→
     └──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘
        │       │       │       │       │       │       │       │
     ┌──▼──┐ ┌──▼──┐                               ...
     │PE10 │→│PE11 │→  ...
     └──┬──┘ └──┬──┘
        │       │         ...  (8 rows total)
        ▼       ▼       ▼       ▼       ▼       ▼       ▼       ▼
     psum[0] psum[1] psum[2] psum[3] psum[4] psum[5] psum[6] psum[7]
                    (Partial sum outputs, bottom edge)
```

### Processing Element (PE)
Each PE implements:
```
psum_out = psum_in + (weight_reg × act_in)   // MAC every cycle
act_out  = act_in                             // registered 1-cycle pass-through
```
- **Weight-stationary**: weight loaded once, held fixed during computation
- **8-bit** activations and weights, **32-bit** accumulator (no overflow)

### Pipeline Stages
| Stage | Description |
|-------|-------------|
| 1–2   | Input activation pipeline registers |
| 3–10  | 8 PE rows (1 register stage per row) |
| 11–12 | Output psum pipeline registers |

- First valid output at `col[0]`: **cycle 20** after activations begin
- Column skew: `col[k]` peaks **1 cycle after** `col[k-1]`

---

## Design Specifications

| Parameter | Value |
|-----------|-------|
| Array size | 8×8 (64 PEs) |
| Activation width | 8-bit |
| Weight width | 8-bit |
| Accumulator width | 32-bit |
| Clock target | 50 MHz (20ns period) |
| PDK | SkyWater 130nm (sky130hd) |
| Corner | TT, 025°C, 1.80V |
| Standard cells | 25,030 instances |
| Peak memory (routing) | ~2.47 GB |

---

## Tool Flow

```
SystemVerilog RTL
       │
       ▼
  ┌─────────┐
  │  Yosys  │  0.44+39 — Logic synthesis → sky130_fd_sc_hd standard cells
  │  Synth  │  Liberty frontend + ABC optimization
  └────┬────┘
       │  gate-level netlist (.v) + RTLIL
       ▼
  ┌──────────────────────────────────────────────────────┐
  │                   OpenROAD v2.0                      │
  │  ┌────────────┐  ┌─────────┐  ┌─────┐  ┌────────┐  │
  │  │ Floorplan  │→ │  Place  │→ │ CTS │→ │ Route  │  │
  │  │ (PDN, IOs) │  │ (GP+DP) │  │     │  │(GR+DR) │  │
  │  └────────────┘  └─────────┘  └─────┘  └────────┘  │
  └────┬─────────────────────────────────────────────────┘
       │  routed DEF + ODB
       ▼
  ┌─────────┐
  │ KLayout │  GDS merge → 6_final.gds
  └─────────┘
```

### Flow Steps & Runtime

| Step | Description | Time |
|------|-------------|------|
| 1_1 | Yosys canonicalize | 6s |
| 1_2 | Yosys synthesis | 33s |
| 2_x | Floorplan (core, PDN, tapcells) | ~28s |
| 3_x | Placement (global + detail) | ~83s |
| 4_1 | Clock Tree Synthesis (CTS) | 9s |
| 5_1 | Global routing | 193s |
| 5_2 | Detailed routing | 954s |
| 5_3 | Fill cells | 17s |
| 6_x | Signoff + GDS merge | ~71s |
| **Total** | | **~23 min** |

---

## File Structure

```
systolic_array/
├── src/
│   ├── pe.sv                    # PE module (SystemVerilog, simulation)
│   ├── pe_yosys.sv              # PE module (Verilog-2001, synthesis)
│   ├── systolic_array.sv        # Top-level array (SystemVerilog, simulation)
│   ├── systolic_array_yosys.sv  # Top-level array (Verilog-2001, synthesis)
│   └── systolic_array_tb.sv     # Self-checking testbench
├── flow/
│   ├── config.mk                # OpenROAD flow configuration
│   └── constraint.sdc           # Timing constraints (50 MHz clock)
├── results/
│   └── sky130hd/systolic_array/base/
│       ├── 6_final.gds          # Final GDS layout
│       ├── 6_final.def          # Final DEF
│       └── 6_final.v            # Final gate-level netlist
└── README.md
```

---

## Verification

The testbench (`systolic_array_tb.sv`) is fully self-checking:

- Loads `weight = 2` into all 64 PEs (8 rows × 8 cols)
- Feeds `act = 1` into all rows for 8 consecutive cycles
- Expected result per column: `8 × 2 × 1 = 16`
- Samples each column at its skew-corrected peak cycle (`col[k]` at cycle `20 + k`)
- Automatically reports **PASS/FAIL** per column and overall result

```
--- Loading weights ---
    weight=2 loaded into all 8 rows
--- Feeding activations ---
    act=1 fed for 8 cycles
--- Capturing column peaks (skew = 1 cycle per col) ---
    col[0] = 16 at cycle 20
    col[1] = 16 at cycle 21
    ...
    col[7] = 16 at cycle 27
--- PASS/FAIL ---
PASS col[0] = 16
PASS col[1] = 16
...
ALL PASS — 8x8 systolic array verified
```

---

## GDS Layout

The final placed-and-routed GDS layout viewed in KLayout:

> *(Add screenshot of KLayout layout here)*

- Dense standard cell rows visible across core area
- `psum_out_flat` output ports labeled on right edge
- `clk` port visible at bottom right
- Alternating row orientation (standard sky130hd cell placement pattern)
![GDS Layout](images/gds_layout.png)
---

## Key Challenges & Debugging

This project involved significant EDA toolchain debugging due to version mismatches between the OpenROAD flow scripts (written for newer releases) and the installed tool versions:

| Issue | Fix |
|-------|-----|
| Yosys Liberty `Missing function on GCLK` | Added `-ignore_miss_func` flag to `read_liberty` |
| `Unrecognized HDL frontend: verilog` | Disabled `SYNTH_HDL_FRONTEND` in config.mk |
| `repair_timing -sequence` unsupported | Removed flag from `util.tcl` |
| `all_pins_placed` command missing | Refactored conditional in `global_place_skip_io.tcl` |
| `report_fmax_metric` missing | Commented out `report_metrics` calls across all flow scripts |
| `kepler-formal` binary missing | Disabled `EQUIVALENCE_CHECK` and `LEC_CHECK` |
| OpenROAD not found at expected path | Created symlink to `/usr/bin/openroad` |

---

## How to Run

### Simulation (ModelSim/QuestaSim)
```bash
mkdir -p waves
vlog pe.sv systolic_array.sv systolic_array_tb.sv
vsim -c systolic_array_tb -do "run -all; quit"
```

### RTL-to-GDS Flow (OpenROAD)
```bash
cd OpenROAD-flow-scripts/flow
make DESIGN_CONFIG=./designs/sky130hd/systolic_array/config.mk
```

### View GDS Layout
```bash
klayout results/sky130hd/systolic_array/base/6_final.gds
```

---

## References

- [OpenROAD Project](https://github.com/The-OpenROAD-Project/OpenROAD)
- [OpenROAD Flow Scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts)
- [SkyWater 130nm PDK](https://github.com/google/skywater-pdk)
- [Yosys Open Synthesis Suite](https://github.com/YosysHQ/yosys)
- Norman P. Jouppi et al., "In-Datacenter Performance Analysis of a Tensor Processing Unit" (Google TPU paper)

---

*Completed as part of MS EE coursework and independent project work at USC Viterbi School of Engineering, 2026.*
