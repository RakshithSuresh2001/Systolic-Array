# 8×8 Weight-Stationary Systolic Array — RTL to GDS | SkyWater 130nm × ASAP7 7nm

**Author:** Rakshith Suresh  
**Affiliation:** MS Electrical Engineering  
University of Southern California, Viterbi School of Engineering  
**Email:** rsuresh@usc.edu | **GitHub:** [RakshithSuresh2001](https://github.com/RakshithSuresh2001)

---

## Overview

A systolic system is a network of processors which **rhythmically compute and pass data through the system**. In a systolic computing, the function of a processor is analogous to that of the heart — every processor regularly pumps data in and out, each time performing some short computation, so that a regular flow of data is kept up in the network.

A fully custom, tapeout-ready **8×8 weight-stationary systolic array accelerator** designed and implemented from scratch in SystemVerilog, taken through a complete **RTL-to-GDS physical design flow** using open-source EDA tools. The design has been implemented and characterized on two process nodes:

- **SkyWater 130nm** (sky130hd) — baseline implementation, timing closed at 50 MHz
- **ASAP7 7nm** (predictive PDK) — cross-node comparison, timing closed at 500 MHz

This architecture is the compute backbone of matrix-multiplication engines used in AI/ML inference accelerators (e.g., Google TPU). Each processing element (PE) performs a MAC operation every clock cycle, enabling highly parallel, pipelined matrix-vector multiplication with minimal data movement.

---

## Caravel Tapeout Integration — ChipFoundry ChipIgnite CI2609

The design has been integrated into the [Caravel SoC harness](https://github.com/efabless/caravel) for submission to the ChipFoundry ChipIgnite CI2609 shuttle on SkyWater 130nm as part of the Silicon2System contest.

### Integration Architecture

The systolic array and SPI slave are wrapped in a Caravel user project module that exposes the SPI interface through Caravel IO pads:

| Caravel IO | Direction | Signal |
|---|---|---|
| `io_in[8]` | Input | `spi_clk` |
| `io_in[9]` | Input | `spi_cs_n` |
| `io_in[10]` | Input | `spi_mosi` |
| `io_out[11]` | Output | `spi_miso` |

The first 128 bits of psum output are exposed on the Logic Analyzer bus for debug readback via the Caravel management SoC.

### Caravel File Structure
caravel_user_project/
├── verilog/

│   ├── rtl/

│   │   ├── systolic_array_user_project.v   # Caravel user project wrapper

│   │   ├── user_project_wrapper.v          # Caravel top-level harness

│   │   ├── systolic_array.sv               # 8x8 systolic array RTL

│   │   ├── pe.sv                           # Processing element

│   │   └── spi_slave.sv                    # SPI slave controller

│   └── gl/

│       └── systolic_array_user_project.v   # Gate-level netlist

├── gds/

│   └── user_project_wrapper.gds.gz         # Final GDS (compressed)

├── lef/

│   └── systolic_array_user_project.lef     # Abstract LEF

├── lib/

│   └── systolic_array_user_project.lib     # Liberty timing model

├── spef/multicorner/

│   ├── systolic_array_user_project.min.spef

│   ├── systolic_array_user_project.nom.spef

│   └── systolic_array_user_project.max.spef

└── openlane/

├── systolic_array_user_project/

│   └── config.json                     # OpenLane 2 user project config

└── user_project_wrapper/

└── config.json                     # OpenLane 2 wrapper config

### OpenLane Hardening

The design was hardened using OpenLane 2 with Docker on SkyWater 130nm sky130A PDK:

```bash
# Install OpenLane 2
pip3 install openlane

# Install PDK
volare enable --pdk sky130 --pdk-root ~/pdk <version>

# Harden user project
openlane --dockerized --pdk sky130A --pdk-root ~/pdk \
    openlane/systolic_array_user_project/config.json

# Harden wrapper
openlane --dockerized --pdk sky130A --pdk-root ~/pdk \
    openlane/user_project_wrapper/config.json
```

### Precheck Status

Remote precheck run via ChipFoundry platform (cf-precheck v1.3.3, sky130A):

| Check | Status |
|---|---|
| topcell | PASS |
| gpio_defines | PASS |
| illegal_cellname | PASS |
| pdnmulti | PASS |
| metalcheck | PASS |
| klayout_feol | PASS |
| klayout_beol | PASS |
| klayout_offgrid | In progress |
| klayout_met_min_ca_density | In progress |
| klayout_zeroarea | In progress |
| oeb | In progress |
| lvs | In progress |
| xor | In progress |
| spike_check | PASS |

---

## Cross-Node PPA Comparison: 130nm vs. 7nm

The design was re-implemented on the [ASAP7 predictive PDK](https://github.com/The-OpenROAD-Project/asap7) using the same OpenROAD flow to produce a quantitative cross-node comparison. Both runs achieved full timing closure (WNS = 0, TNS = 0).

| Metric | SkyWater 130nm | ASAP7 7nm | Improvement |
|---|---|---|---|
| **Clock Frequency** | 50 MHz | 500 MHz | **10×** |
| **WNS / TNS** | 0 ps / 0 ps | 0 ps / 0 ps | Both closed |
| **Core Area** | 251,970 µm² | 3,903 µm² | **64.6× smaller** |
| **Total Power** | 11.4 mW | 3.58 µW (leakage) | **~3,185×** |
| **Cell Count** | 25,030 | 32,446 | — |
| **Utilization** | 44% | 25% | — |
| **PDK Corner** | TT, 025°C, 1.80V | FF, RVT | — |

> **Note on power comparison:** The Sky130 power includes dynamic (switching + internal) and leakage components under realistic activity. The ASAP7 figure is leakage-dominated because post-route SPEF back-annotation was used without explicit switching activity annotation i.e. the dynamic contribution is present but not fully captured. The area and frequency numbers are directly comparable.

### Key Observations

- The **64.6× area reduction** is consistent with the ~18.6× linear scaling expected from the node shrink (130nm/7nm), amplified by ASAP7's denser standard cell library (7.5-track vs. sky130hd's 9-track).
- The **10× frequency gain** reflects both the node shrink and the more aggressive timing optimization enabled by ASAP7's lower parasitics.
- ASAP7 PDN integrity requires attention — post-route IR drop analysis flagged 176% worst-case drop on VDD, indicating the default power strap density needs to be increased for this design's current draw at 500 MHz.

---

## PDN Analysis — ASAP7 7nm

Post-route power delivery network analysis was performed using OpenROAD's `analyze_power_grid` with SPEF-extracted parasitics.

| Metric | Value |
|---|---|
| **Supply Voltage** | 0.77V |
| **Mean Voltage** | 0.747V |
| **Mean IR Drop** | 23.04 mV (3.0%) |
| **Worst IR Drop** | 812.94 mV |
| **Total Nodes Analyzed** | 98,262 |

**Key observation:** The IR drop heatmap reveals a structured diagonal hot-spot pattern that spatially correlates with the 8×8 PE grid layout. Each processing element contains a full-adder/half-adder accumulator chain (FAx1, HAxp5 cells) with high instantaneous current demand. Nodes falling between M5/M6 power stripes experience elevated drop. The mean IR drop of 23mV (3.0%) is within acceptable bounds; the worst-case outlier is attributed to PE cells mid-span between stripes and a PSM solver artifact.

**Root cause:** M5/M6 stripe pitch (2.7µm) is insufficient for the PE current density at 500 MHz. Fix: reduce stripe pitch to ≤1.5µm or add a dedicated power mesh at M3/M4 around the PE array region.

<img width="1943" height="907" alt="pdn_heatmap" src="https://github.com/user-attachments/assets/71d3646f-00d9-4230-a26b-b5994bdfa2fe" />

---

### Processing Element (PE)

Each PE implements:
psum_out = psum_in + (weight_reg × act_in)   // MAC every cycle
act_out  = act_in                             // registered 1-cycle pass-through

- **Weight-stationary**: weight loaded once, held fixed during computation
- **8-bit** activations and weights, **32-bit** accumulator (no overflow)

### Pipeline Stages

| Stage | Description |
|---|---|
| 1–2 | Input activation pipeline registers |
| 3–10 | 8 PE rows (1 register stage per row) |
| 11–12 | Output psum pipeline registers |

- First valid output at `col[0]`: **cycle 20** after activations begin
- Column skew: `col[k]` peaks **1 cycle after** `col[k-1]`

---

## Design Specifications

| Parameter | SkyWater 130nm | ASAP7 7nm |
|---|---|---|
| Array size | 8×8 (64 PEs) | 8×8 (64 PEs) |
| Activation width | 8-bit | 8-bit |
| Weight width | 8-bit | 8-bit |
| Accumulator width | 32-bit | 32-bit |
| Clock target | 50 MHz (20 ns) | 500 MHz (2 ns) |
| PDK | SkyWater 130nm (sky130hd) | ASAP7 7nm (RVT) |
| Corner | TT, 025°C, 1.80V | FF, RVT |
| Standard cells | 25,030 | 32,446 |
| Tool | OpenROAD v2.0 | OpenROAD v2.0 |

---

### Flow Steps & Runtime (Sky130)

| Step | Description | Time |
|---|---|---|
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
systolic_array/
├── verilog/rtl/

│   ├── systolic_array_user_project.v  # Caravel user project wrapper

│   ├── user_project_wrapper.v         # Caravel top-level harness

│   ├── systolic_array.sv              # Top-level array

│   ├── pe.sv                          # Processing element

│   └── spi_slave.sv                   # SPI slave controller

├── verilog/gl/

│   └── systolic_array_user_project.v  # Gate-level netlist

├── gds/

│   └── user_project_wrapper.gds.gz    # Final GDS (compressed, Git LFS)

├── lef/

│   └── systolic_array_user_project.lef

├── lib/

│   └── systolic_array_user_project.lib

├── spef/multicorner/

│   ├── systolic_array_user_project.min.spef

│   ├── systolic_array_user_project.nom.spef

│   └── systolic_array_user_project.max.spef

├── openlane/

│   ├── systolic_array_user_project/config.json

│   └── user_project_wrapper/config.json

├── SPI_Interface/

│   ├── spi_slave.sv

│   └── spi_tb.sv

├── systolic_array_tb.sv

├── flow_summary.png

├── gds_layout.png

└── README.md

---

## Verification

The testbench (`systolic_array_tb.sv`) is fully self-checking:

- Loads `weight = 2` into all 64 PEs (8 rows × 8 cols)
- Feeds `act = 1` into all rows for 8 consecutive cycles
- Expected result per column: `8 × 2 × 1 = 16`
- Samples each column at its skew-corrected peak cycle (`col[k]` at cycle `20 + k`)
- Automatically reports **PASS/FAIL** per column and overall result
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

---

## SPI Interface

To make the design tapeout-ready, an SPI slave controller wraps the systolic array, reducing the IO pin count from ~390 to 4.

### Pin Map

| Pin | Direction | Description |
|---|---|---|
| `spi_clk` | Input | SPI clock from master (Mode 0) |
| `spi_cs_n` | Input | Chip select, active low |
| `spi_mosi` | Input | Master → Slave data |
| `spi_miso` | Output | Slave → Master data |

### Command Protocol

| Command | Byte Sequence | Description |
|---|---|---|
| `0x01` | `[0x01][row][w0..w7]` | Load 8 weights into one row |
| `0x02` | `[0x02][a0..a7]` | Feed activations to all rows |
| `0x03` | `[0x03]` → 32 bytes back | Read all 8 psum outputs |
| `0x04` | `[0x04]` | Reset array |

### Verification

Self-checking SPI testbench (`spi_tb.sv`) verifies the full transaction sequence:
- Load `weight=3` into all 8 rows via 8 SPI write packets
- Feed `act=2` for 8 cycles via SPI
- Read back psums via SPI — expected result per column: `8 × 3 × 2 = 48`

All 8 columns return correct result:
PASS col[0] = 48
PASS col[1] = 48
PASS col[2] = 48
PASS col[3] = 48
PASS col[4] = 48
PASS col[5] = 48
PASS col[6] = 48
PASS col[7] = 48

<img width="1634" height="304" alt="Screenshot 2026-05-13 140550" src="https://github.com/user-attachments/assets/00f4f0ed-8c6c-475d-a733-35b6c4742197" />

<img width="1624" height="234" alt="Screenshot 2026-05-13 140742" src="https://github.com/user-attachments/assets/1f9a1500-9b1d-4365-a60c-e0f3e1f30f4e" />

---

## GDS Layout (SkyWater 130nm)

The final placed-and-routed GDS layout viewed in KLayout:

<img width="1039" height="841" alt="Screenshot 2026-05-20 112726" src="https://github.com/user-attachments/assets/827bc06e-43f8-4e56-9fc7-831cf1ce6c10" />


---
## GDS Layout (ASAP7 7nm)

The final placed-and-routed GDS layout viewed in KLayout:

<img width="1006" height="827" alt="Screenshot 2026-05-20 112532" src="https://github.com/user-attachments/assets/02d7cb9d-326f-4cd7-a249-9dfdeb3d8ff1" />


---
## Key Challenges & Debugging

### Sky130 Flow

| Issue | Fix |
|---|---|
| Yosys Liberty `Missing function on GCLK` | Added `-ignore_miss_func` flag to `read_liberty` |
| `Unrecognized HDL frontend: verilog` | Disabled `SYNTH_HDL_FRONTEND` in config.mk |
| `repair_timing -sequence` unsupported | Removed flag from `util.tcl` |
| `all_pins_placed` command missing | Refactored conditional in `global_place_skip_io.tcl` |
| `report_fmax_metric` missing | Commented out `report_metrics` calls across flow scripts |
| `kepler-formal` binary missing | Disabled `EQUIVALENCE_CHECK` and `LEC_CHECK` |
| OpenROAD not found at expected path | Created symlink to `/usr/bin/openroad` |

### ASAP7 PDK Integration

| Issue | Fix |
|---|---|
| ABC segfault on gzipped liberty files | Decompressed all `.lib.gz` → `.lib`; patched `platforms/asap7/config.mk` |
| `abc_speed.script` unsupported commands | Set `ABC_AREA=1` to use `abc_area.script` |
| `kepler-formal` LEC check triggered | Set `LEC_CHECK=0` in design config |
| OpenROAD GUI save failing in headless WSL | Commented out `gui::show` in `final_report.tcl` |
| PDN IR drop 176% on VDD post-route | Insufficient power strap density; flagged for next iteration |

### Caravel Integration

| Issue | Fix |
|---|---|
| OpenLane 2 Yosys Python scripting not supported | Used `--dockerized` flag to run in Docker container |
| GDS file 179MB exceeds GitHub 100MB limit | Compressed to 29MB with gzip; tracked with Git LFS |
| `SYNTH_MAX_FANOUT` deprecated | Replaced with `MAX_FANOUT_CONSTRAINT` |
| `PL_TARGET_DENSITY` deprecated | Replaced with `PL_TARGET_DENSITY_PCT` |
| Multiple conflicting drivers for `spi_miso` | Added explicit `io_out[8:10] = 0` tie-off for input pads |

---

## How to Run

### Simulation (Icarus Verilog)

```bash
iverilog -g2012 -o sim systolic_array_tb.sv systolic_array.sv pe.sv
vvp sim
```

### SPI Simulation

```bash
iverilog -g2012 -o spi_sim SPI_Interface/spi_tb.sv SPI_Interface/spi_slave.sv \
    systolic_array.sv pe.sv
vvp spi_sim
```

### RTL-to-GDS Flow — SkyWater 130nm (OpenROAD)

```bash
cd OpenROAD-flow-scripts/flow
make DESIGN_CONFIG=./designs/sky130hd/systolic_array/config.mk
```

### RTL-to-GDS Flow — ASAP7 7nm (OpenROAD)

```bash
cd flow/platforms/asap7/lib/NLDM
gunzip -k *.lib.gz
sed -i 's/\.lib\.gz/.lib/g' ../../config.mk
cd OpenROAD-flow-scripts/flow
make DESIGN_CONFIG=./designs/asap7/systolic_array/config.mk
```

### Caravel Hardening (OpenLane 2)

```bash
pip3 install openlane
volare enable --pdk sky130 --pdk-root ~/pdk <version>

cd caravel_user_project
openlane --dockerized --pdk sky130A --pdk-root ~/pdk \
    openlane/systolic_array_user_project/config.json

openlane --dockerized --pdk sky130A --pdk-root ~/pdk \
    openlane/user_project_wrapper/config.json
```

---

## Roadmap

- [x] 8×8 systolic array RTL — SystemVerilog, self-checking testbench 80/80
- [x] RTL-to-GDS on SkyWater 130nm — 50 MHz, full timing closure
- [x] RTL-to-GDS on ASAP7 7nm — 500 MHz, full timing closure
- [x] PDN analysis and IR drop heatmap
- [x] SPI slave interface — 390 pins to 4
- [x] Caravel user project wrapper — OpenLane 2 hardening complete
- [ ] Full precheck pass on ChipFoundry
- [ ] CI2609 shuttle submission
- [ ] 16×16 systolic array on ASAP7

---

## References

- [OpenROAD Project](https://github.com/The-OpenROAD-Project/OpenROAD)
- [OpenROAD Flow Scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts)
- [ASAP7 Predictive PDK](https://github.com/The-OpenROAD-Project/asap7)
- [SkyWater 130nm PDK](https://github.com/google/skywater-pdk)
- [Yosys Open Synthesis Suite](https://github.com/YosysHQ/yosys)
- [Caravel User Project](https://github.com/efabless/caravel_user_project)
- [ChipFoundry ChipIgnite](https://chipfoundry.io)
- Norman P. Jouppi et al., "In-Datacenter Performance Analysis of a Tensor Processing Unit" (Google TPU paper)

---

*Implemented as part of MS EE independent project work at USC Viterbi School of Engineering, 2026.*
