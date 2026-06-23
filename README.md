# 8x8 Weight-Stationary Systolic Array — RTL to GDS to Tapeout

**Author:** Rakshith Suresh
**Affiliation:** MS Electrical Engineering, University of Southern California, Viterbi School of Engineering
**Email:** rsuresh@usc.edu | **GitHub:** [RakshithSuresh2001](https://github.com/RakshithSuresh2001)

---

## Overview

A fully custom, tapeout-ready 8x8 weight-stationary systolic array ML accelerator, designed in SystemVerilog and taken through a complete RTL-to-GDS physical design flow on two process nodes using open-source EDA tools. The design was submitted to the ChipFoundry CI2609 shuttle via the Caravel SoC harness as part of the Silicon2System contest.

This architecture is the compute backbone of matrix-multiplication engines used in AI/ML inference (the same dataflow as Google's TPU). Each of the 64 processing elements runs one MAC per clock cycle, enabling highly parallel, pipelined matrix-vector multiplication with minimal data movement.

---

## Key Results

| Metric | SkyWater 130nm | ASAP7 7nm |
|--------|---------------|-----------|
| Clock Frequency | 50 MHz | 500 MHz |
| WNS / TNS | 0 ps / 0 ps | 0 ps / 0 ps |
| Core Area | 240,799 um2 | 3,903 um2 |
| Total Power | 12.75 mW (SPEF) | 5.05 W (VCD-annotated) |
| Cell Count | 24,711 | 32,446 |
| Utilization | 44% | 25% |
| DRC Violations | 0 | 0 |
| Flow Runtime | ~23 min | ~41 min |

Cross-node comparison: 10x frequency gain, 61.7x area reduction, from 130nm to 7nm.

ASAP7 power is VCD-annotated from functional simulation at 500 MHz: 3.87 W internal, 1.18 W switching, 3.58 uW leakage. Clock tree accounts for 1.92 W (38%) of total.

## Hardware vs. GPU: Matrix Multiply Efficiency

The same 8x8 matrix multiply workload was benchmarked on an NVIDIA RTX 4060 Laptop GPU (Ampere, CC 8.9) using naive CUDA and cuBLAS kernels in both FP32 and INT8, across matrix sizes N = 8 to 4096. The full methodology, Nsight Compute profiling, and roofline analysis are written up in a paper targeting GLSVLSI 2027 (see Paper below).

Key Results at N=8 (the array's native size)

MetricGPU (FP32)GPU (INT8)Hardware (sky130hd)AdvantageTotal system latency (kernel + PCIe transfer)51 us30 us46 ns650x - 1,100xEnergy per inference1,785 nJ1,050 nJ0.59 nJ1,780x - 3,025x

At N=8, PCIe transfer alone (21-31 us) exceeds the GPU's kernel execution time. The hardware array, integrated on-die with no transfer step, finishes the entire operation in 46 ns at 500 MHz.

Memory Traffic (Nsight Compute, N=256)

MetricNaive CUDAcuBLASL1/Tex Memory Traffic274.95 GB8.66 GBSM Throughput (% peak)98.26%74.14%Throughput796.89 GFLOPS2,726 GFLOPS

The naive kernel moves 274.95 GB through cache for a problem that needs 768 KB of data, a 358,000x amplification, despite near-perfect SM utilization. cuBLAS reduces this 32x through shared-memory tiling but is still 32x over the theoretical minimum. The hardware array hits that minimum by construction: weights never leave the PE registers.

## Where the GPU Wins

cuBLAS INT8 reaches 28,325 GFLOPS at N=4096 using Tensor Cores, 3.1x faster than cuBLAS FP32 at the same size. The crossover between hardware and GPU efficiency falls between N=64 and N=256. Below that range, the hardware wins on latency, energy, and determinism simultaneously. Above it, GPU throughput takes over and the comparison runs the other way.

## Roofline Position

On the RTX 4060 Laptop GPU's roofline (ridge point ~44 FLOPS/byte), naive CUDA sits at AI = 1.2e-4 and cuBLAS at AI = 3.9e-3, both deep in the memory-bound region. The hardware array sits at AI = 128, 2.9x past the ridge point, in the compute-bound regime.

<img width="744" height="444" alt="Screenshot 2026-06-14 145208" src="https://github.com/user-attachments/assets/4dbca801-e480-4013-83b3-4565f7316fe2" />

---

## Architecture

```
Activations (left edge, 1 per row)
        |       |       |       |       |       |       |       |
        v       v       v       v       v       v       v       v
     [PE00]->[PE01]->[PE02]->[PE03]->[PE04]->[PE05]->[PE06]->[PE07]->
        |       |       |       |       |       |       |       |
     [PE10]->[PE11]->  ...
        |       |
       ...    (8 rows total)
        |       |       |       |       |       |       |       |
        v       v       v       v       v       v       v       v
     psum[0] psum[1] psum[2] psum[3] psum[4] psum[5] psum[6] psum[7]
```

### Processing Element

Each PE implements one MAC per cycle:

```
psum_out = psum_in + (weight_reg x act_in)
act_out  = act_in   // registered 1-cycle pass-through
```

Weights are stationary: loaded once before inference, held fixed during computation. Activations flow left to right. Partial sums accumulate downward. First valid output appears at cycle 20 after activations begin, with a 1-cycle skew per column.

---

## Tapeout — ChipFoundry CI2609

The design was hardened for Sky130 tapeout using OpenLane 2 with a Caravel user project wrapper and submitted to the ChipFoundry CI2609 shuttle as part of the Silicon2System contest.

**Precheck results:** 8/13 checks passing. The remaining failures are infrastructure false positives (3 checks report total=0 but still fail due to a server-side issue) and BEOL spacing violations in the Caravel wrapper power ring, not the user project area. Manual review was requested.

**Caravel wrapper:** SPI signals exposed through io_in[8:10] and io_out[11]. The first 128 bits of partial sum output are also readable via the Caravel Logic Analyzer bus.

---

## SPI Slave Interface

A custom SPI slave reduces the IO pin count from 390 to 4 (spi_clk, spi_cs_n, spi_mosi, spi_miso), making the design fit within Caravel IO pad constraints. The interface supports three commands:

| Command | Description |
|---------|-------------|
| 0x01 | Load weights into selected row |
| 0x02 | Load activation vector |
| 0x03 | Trigger inference, stream 256-bit partial sum result |

---

## GDS_Layout
# SKYWATER 130nm GDS

<img width="1107" height="947" alt="Sky130nm_GDS" src="https://github.com/user-attachments/assets/382ca647-98b7-4d11-91be-ee97af186f60" />

# ASAP7 7nm GDS

<img width="1001" height="838" alt="ASAP7_GDS" src="https://github.com/user-attachments/assets/ddba2866-a6c0-49c9-84ec-0be05a99452d" />

---

## PDN Analysis (ASAP7)

Post-route PDN analysis ran across 98,262 nodes using analyze_power_grid with SPEF-extracted parasitics.

| Metric | SkyWater 130nm | ASAP7 7nm |
|--------|---------------|-----------|
| Supply Voltage | 1.80 V | 0.77 V |
| Mean IR Drop | 4.18 uV (0.00%) | 23.04 mV (3.0%) |
| Worst-Case Drop | 63.9 uV | 812.94 mV |
| Nodes Analyzed | N/A | 98,262 |

The heatmap shows a structured diagonal hot-spot pattern mapping onto the 8x8 PE grid. Root cause: 2.7 um M5/M6 stripe pitch too coarse for the current density 64 simultaneous MACs generate at 500 MHz. Proposed fix: reduce pitch to 1.5 um or add a dedicated M3/M4 mesh over the PE array.

---

## Verification

The self-checking testbench loads weight=2 into all 64 PEs, feeds act=1 for 8 cycles, and checks that each column output equals 16 (= 8 x 2 x 1). All 80/80 tests passing.

A UVM verification environment is in progress with constrained-random stimulus, functional coverage groups targeting all 64 PE outputs, and a self-checking scoreboard against a cycle-accurate reference model.

---
## Waveforms
Functional simulation — systolic array output columns showing correct accumulation and 1-cycle column skew:

<img width="1634" height="304" alt="Screenshot 2026-05-13 140550" src="https://github.com/user-attachments/assets/fffcb640-974c-41b3-b2ad-14b0bbc66020" />


Key signals: clk, rst_n, act_in_flat, psum_out_flat[31:0] through psum_out_flat[255:224]. col[0] produces the first valid output at cycle 20, with each subsequent column delayed by one cycle.

SPI transaction — complete weight load (0x01) followed by inference trigger and 256-bit readback (0x03):

<img width="1624" height="234" alt="Screenshot 2026-05-13 140742" src="https://github.com/user-attachments/assets/6d1525d9-d7d2-465c-8ed7-b3225d7b86bd" />


Key signals: spi_clk, spi_cs_n, spi_mosi, spi_miso. The 32-byte partial sum result streams out MSB-first on spi_miso after the 0x03 command byte is received.
## Tool Flow

```
SystemVerilog RTL
       |
       v
  [Yosys 0.44]  -- Logic synthesis to sky130hd / ASAP7 standard cells
       |
       v
  [OpenROAD v2.0]
    Floorplan -> PDN -> Placement -> CTS -> Global Route -> Detail Route
       |
       v
  [KLayout]  -- GDS merge and DRC
```

### Flow Runtime (SkyWater 130nm)

| Step | Description | Time |
|------|-------------|------|
| 1_1 | Yosys canonicalize | 6s |
| 1_2 | Yosys synthesis | 33s |
| 2_x | Floorplan (core, PDN, tapcells) | ~28s |
| 3_x | Placement (global + detail) | ~83s |
| 4_1 | Clock Tree Synthesis | 9s |
| 5_1 | Global routing | 193s |
| 5_2 | Detailed routing | 954s |
| 5_3 | Fill cells | 17s |
| 6_x | Signoff + GDS merge | ~71s |
| **Total** | | **~23 min** |

---

## Repository Structure

```
Systolic-Array/
├── pe.sv                    # PE module (SystemVerilog)
├── pe_yosys.sv              # PE module (Verilog-2001, synthesis)
├── systolic_array.sv        # Top-level array
├── systolic_array_tb.sv     # Self-checking testbench
├── config.mk                # OpenROAD flow configuration
├── constraint.sdc           # Timing constraints
├── gds_layout.png           # KLayout GDS screenshot (Sky130)
└── flow_summary.png         # OpenROAD flow summary
```

---

## How to Run

### Simulation

```bash
# Icarus Verilog
iverilog -g2012 -o sim pe.sv systolic_array.sv systolic_array_tb.sv
./sim

# Verilator
verilator --binary -sv systolic_array.sv systolic_array_tb.sv --top systolic_array_tb
./obj_dir/Vsystolic_array_tb
```

### RTL-to-GDS (SkyWater 130nm)

```bash
cd OpenROAD-flow-scripts/flow
make DESIGN_CONFIG=./designs/sky130hd/systolic_array/config.mk
```

### RTL-to-GDS (ASAP7 7nm)

```bash
make DESIGN_CONFIG=./designs/asap7/systolic_array/config.mk
```

### View GDS

```bash
klayout results/sky130hd/systolic_array/base/6_final.gds
```

---

## Related

- [PicoRISCV-SoC](https://github.com/RakshithSuresh2001/PicoRISCV-SoC) — full RISC-V SoC integrating this systolic array with a PicoRV32 CPU, AXI-Lite MMIO, and SPI slave. ASAP7 PD: 47,051 cells, 5,431 um2, 500 MHz, 0 DRC violations.

---

## References

- N. P. Jouppi et al., "In-Datacenter Performance Analysis of a Tensor Processing Unit," ISCA 2017.
- L. T. Clark et al., "ASAP7: A 7-nm FinFET Predictive Process Design Kit," Microelectronics Journal, 2016.
- T. Ajayi et al., "OpenROAD: Toward a Self-Driving, Open-Source Digital Layout Tool Chain," GOMACTECH 2019.
- H. T. Kung, "Why Systolic Architectures?" IEEE Computer, vol. 15, no. 1, 1982.
- efabless Corporation, "Caravel SoC Harness," github.com/efabless/caravel_user_project
