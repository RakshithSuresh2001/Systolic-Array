# 8×8 Weight-Stationary Systolic Array

A fully verified 8×8 systolic array accelerator in SystemVerilog. Built to understand how hardware like Google's TPU handles matrix multiplication efficiently — specifically the memory access pattern that makes systolic arrays better than naive implementations for dense matrix math.

Simulated with Icarus Verilog. 8/8 output columns verified with a skew-aware self-checking testbench.

---

## What is a systolic array and why does it matter?

The short version: it's a grid of simple compute units that pass data through in a wave, like a heartbeat (hence the name — systole is the contracting phase of the heart). Each unit does a multiply-accumulate, and instead of everyone fighting over shared memory, data flows through naturally.

The reason this matters for AI inference is the memory wall problem. Modern processors are fast, but memory is slow. If you're doing matrix multiplication naively — the kind that runs inside every neural network layer — you end up reading the same weights from memory over and over, once for each activation vector. At scale that becomes the bottleneck, not the arithmetic.

Systolic arrays solve this differently. Weights get loaded into the processing elements once and stay there. Activations stream through horizontally, partial sums accumulate vertically, and by the time a value exits the array, it has touched every weight it needed to without a single extra memory read.

This is exactly the insight behind Google's TPU, and it's why companies like d-Matrix are building inference chips around in-memory compute architectures — the fundamental problem is getting weights and activations in the same place at the same time without paying the memory bandwidth tax repeatedly.

---

## Architecture

Each cell in the grid is a Processing Element (PE). In the weight-stationary configuration used here, the PE holds its weight fixed once loaded. Activations enter from the left and shift right one cell per clock. Partial sums enter from the top (zeros on the first row) and accumulate downward.

```
act[0] →  [PE00][PE01][PE02][PE03][PE04][PE05][PE06][PE07]  →
act[1] →  [PE10][PE11][PE12][PE13][PE14][PE15][PE16][PE17]  →
act[2] →  [PE20][PE21][PE22][PE23][PE24][PE25][PE26][PE27]  →
act[3] →  [PE30][PE31][PE32][PE33][PE34][PE35][PE36][PE37]  →
act[4] →  [PE40][PE41][PE42][PE43][PE44][PE45][PE46][PE47]  →
act[5] →  [PE50][PE51][PE52][PE53][PE54][PE55][PE56][PE57]  →
act[6] →  [PE60][PE61][PE62][PE63][PE64][PE65][PE66][PE67]  →
act[7] →  [PE70][PE71][PE72][PE73][PE74][PE75][PE76][PE77]  →
             ↓     ↓     ↓     ↓     ↓     ↓     ↓     ↓
          out[0] out[1] out[2] out[3] out[4] out[5] out[6] out[7]
```

Each PE does one thing per clock cycle:

```
psum_out = psum_in + (weight_reg × act_in)
act_out  = act_in   // registered pass-through to next PE
```

That's it. 64 of these, wired together correctly, and you get an 8×8 matrix multiplication engine.

---

## Pipeline

The array has 12 registered pipeline stages:

| Stage | What happens |
|-------|-------------|
| 1–2   | Input activation registers — boundary staging before the PE grid |
| 3–10  | 8 PE rows — each row adds one cycle of partial sum latency |
| 11–12 | Output registers — capture final partial sums from the bottom row |

First valid output at **col[0]: cycle 20** after activations start feeding in. Each subsequent column arrives one cycle later because activations take one extra clock to reach it — col[1] at cycle 21, col[2] at cycle 22, through col[7] at cycle 27.

This one-cycle-per-column offset is the skew, and it's not a bug. It's a direct consequence of activations propagating through the PE chain horizontally. The testbench accounts for this by sampling each column at its own peak cycle rather than checking all columns at once.

---

## Processing Element

The PE is the entire logic of the array, repeated 64 times:

```systemverilog
always_ff @(posedge clk) begin
    if (!rst_n) begin
        weight_reg <= '0;
        act_out    <= '0;
        psum_out   <= '0;
    end else begin
        if (weight_load)
            weight_reg <= weight_in;   // latch weight, hold it fixed
        act_out  <= act_in;            // pass activation to next PE
        psum_out <= psum_in + (weight_reg * act_in);  // MAC
    end
end
```

Active-low synchronous reset. Weight loading is gated by `weight_load && (weight_row == row)` at the array level so you can load one row at a time without disturbing the others.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ROWS`    | 8       | Number of PE rows |
| `COLS`    | 8       | Number of PE columns |
| `DATA_W`  | 8       | Activation and weight bit width |
| `ACC_W`   | 32      | Accumulator bit width |

The accumulator is 32-bit to prevent overflow when accumulating 8-bit products across 8 rows. The maximum possible value is 255 × 255 × 8 = 520,200, which fits in 20 bits — 32-bit gives comfortable headroom.

---

## Simulation Results

### PE unit test

```
PASS [36000] Cycle1: 3*2+0: psum_out = 6
PASS [46000] Cycle2: 3*4+6: psum_out = 18
PASS [56000] Cycle3: 3*0+18: psum_out = 18
PASS act_out pass-through: 7
--- Done: 0 error(s) ---
```

### 8×8 array test

Test: `weight = 2` in all PEs, `act = 1` fed into all rows for 8 cycles.
Expected per column: `8 rows × 2 × 1 = 16`

```
--- Loading weights ---
    weight=2 loaded into all 8 rows
--- Feeding activations ---
    act=1 fed for 8 cycles
--- Capturing column peaks (skew = 1 cycle per col) ---
    col[0] = 16 at cycle 20
    col[1] = 16 at cycle 21
    col[2] = 16 at cycle 22
    col[3] = 16 at cycle 23
    col[4] = 16 at cycle 24
    col[5] = 16 at cycle 25
    col[6] = 16 at cycle 26
    col[7] = 16 at cycle 27
--- PASS/FAIL ---
PASS col[0] = 16
PASS col[1] = 16
PASS col[2] = 16
PASS col[3] = 16
PASS col[4] = 16
PASS col[5] = 16
PASS col[6] = 16
PASS col[7] = 16
--- 8/8 columns passed ---
ALL PASS — 8x8 systolic array verified
```

The one-cycle offset between columns confirms the systolic dataflow is working correctly.

---

## Project Structure

```
systolic_array/
├── rtl/
│   ├── pe.sv                  # Processing Element
│   └── systolic_array.sv      # 8×8 array with 12 pipeline stages
├── tb/
│   ├── pe_tb.sv               # PE unit testbench (4 directed tests)
│   └── systolic_array_tb.sv   # Array testbench (skew-aware, 8/8 check)
├── sim/                       # Compiled simulation binaries
├── waves/                     # VCD waveform dumps (GTKWave)
└── scripts/                   # OpenROAD flow (in progress)
```

---

## How to Run

**Prerequisite:** `sudo apt install iverilog`

```bash
# PE unit test
cd systolic_array
iverilog -g2012 -o sim/pe_tb tb/pe_tb.sv rtl/pe.sv && vvp sim/pe_tb

# 8×8 array test
iverilog -g2012 -o sim/sa_tb tb/systolic_array_tb.sv rtl/systolic_array.sv rtl/pe.sv && vvp sim/sa_tb

# View waveforms
gtkwave waves/sa_tb.vcd
```

---

## What's next

- RTL-to-GDS flow on SkyWater 130nm via OpenROAD
- Timing closure and power analysis
- Parameterized test for arbitrary weight/activation matrices
- Accumulator overflow handling for large inputs

---

## Tools

| Tool | Purpose |
|------|---------|
| Icarus Verilog 12.0 | RTL simulation |
| GTKWave | Waveform analysis |
| OpenROAD | RTL-to-GDS (in progress) |
| SkyWater 130nm PDK | Target process node |

---

*Author: Rakshith Suresh — MS Electrical Engineering, USC Viterbi*
