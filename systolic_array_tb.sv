// =============================================================================
// systolic_array_tb.sv — Testbench for 8x8 Weight-Stationary Systolic Array
// -----------------------------------------------------------------------------
// Author      : Rakshith Suresh
// Affiliation : MS Electrical Engineering (VLSI Design & Verification)
//               University of Southern California, Viterbi School of Engineering
// Email       : rsuresh@usc.edu
// GitHub      : https://github.com/RakshithSuresh2001
// -----------------------------------------------------------------------------
// Description:
//   Self-checking testbench with automated PASS/FAIL verification.
//   Validates correct MAC accumulation and skew-aware output sampling.
//
// Test Configuration:
//   weight = 2 loaded into every PE across all 8 rows
//   act    = 1 fed into all rows for 8 consecutive cycles
//
// Expected Result:
//   Each column accumulates: 8 rows × weight(2) × act(1) = 16
//
// Sampling Strategy (skew-aware):
//   Due to horizontal activation propagation, col[k] peaks exactly 1 cycle
//   after col[k-1]. col[0] peaks at cycle 20; col[7] peaks at cycle 27.
//   Each column is sampled at its individual peak cycle.
//
// Simulation:
//   Clock     : 10ns period (100 MHz)
//   VCD output: waves/sa_tb.vcd (for GTKWave / ModelSim viewing)
// =============================================================================

`timescale 1ns/1ps

module systolic_array_tb;

    parameter ROWS        = 8;
    parameter COLS        = 8;
    parameter DATA_W      = 8;
    parameter ACC_W       = 32;
    parameter PEAK_CYCLE  = 20;   // cycle at which col[0] reaches peak
    parameter EXPECTED    = 16;   // 8 rows * weight(2) * act(1)

    logic                          clk;
    logic                          rst_n;
    logic                          weight_load;
    logic [2:0]                    weight_row;
    logic [COLS-1:0][DATA_W-1:0]   weight_data;
    logic [ROWS-1:0][DATA_W-1:0]   act_in;
    logic [COLS-1:0][ACC_W-1:0]    psum_out;
    logic [COLS-1:0][ACC_W-1:0]    captured;   // snapshot at each col's peak

    // ── DUT instantiation ────────────────────────────────────────────────────
    systolic_array #(
        .ROWS(ROWS), .COLS(COLS), .DATA_W(DATA_W), .ACC_W(ACC_W)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .weight_load(weight_load), .weight_row(weight_row),
        .weight_data(weight_data),
        .act_in(act_in), .psum_out(psum_out)
    );

    // ── 10ns clock (100 MHz) ─────────────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    integer i, cycle_count, errors;

    initial begin
        $dumpfile("waves/sa_tb.vcd");
        $dumpvars(0, systolic_array_tb);

        errors = 0; cycle_count = 0; captured = '0;
        rst_n = 0; weight_load = 0; weight_data = '0; act_in = '0;

        // ── Reset ──────────────────────────────────────────────────────────
        repeat(4) @(posedge clk); #1;
        rst_n = 1;

        // ── Load weight=2 into every row ───────────────────────────────────
        $display("--- Loading weights ---");
        for (i = 0; i < ROWS; i++) begin
            weight_load = 1;
            weight_row  = i[2:0];
            for (int c = 0; c < COLS; c++)
                weight_data[c] = 8'd2;
            @(posedge clk); #1;
            cycle_count++;
        end
        weight_load = 0;
        $display("    weight=2 loaded into all %0d rows", ROWS);

        // ── Feed act=1 into all rows for ROWS cycles ───────────────────────
        $display("--- Feeding activations ---");
        for (i = 0; i < ROWS; i++) begin
            for (int r = 0; r < ROWS; r++)
                act_in[r] = 8'd1;
            @(posedge clk); #1;
            cycle_count++;
        end
        act_in = '0;
        $display("    act=1 fed for %0d cycles", ROWS);

        // ── Capture each column at its peak cycle ──────────────────────────
        // col[k] peaks at PEAK_CYCLE+k due to 1-cycle horizontal skew
        $display("--- Capturing column peaks (skew = 1 cycle per col) ---");
        for (i = 0; i < COLS; i++) begin
            while (cycle_count < PEAK_CYCLE + i) begin
                @(posedge clk); #1;
                cycle_count++;
            end
            captured[i] = psum_out[i];
            $display("    col[%0d] = %0d at cycle %0d",
                     i, captured[i], cycle_count);
        end

        // ── PASS/FAIL check ────────────────────────────────────────────────
        $display("--- PASS/FAIL ---");
        for (i = 0; i < COLS; i++) begin
            if (captured[i] === EXPECTED)
                $display("PASS col[%0d] = %0d", i, captured[i]);
            else begin
                $display("FAIL col[%0d] = %0d (expected %0d)",
                         i, captured[i], EXPECTED);
                errors++;
            end
        end

        $display("--- %0d/%0d columns passed ---", COLS - errors, COLS);
        if (errors == 0)
            $display("ALL PASS — 8x8 systolic array verified");
        else
            $display("FAILED — %0d error(s)", errors);

        $finish;
    end

endmodule
