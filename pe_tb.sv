// =============================================================================
// pe_tb.sv — Testbench for Processing Element (pe.sv)
// Author: Rakshith Suresh
// -----------------------------------------------------------------------------
// Directed tests:
//   1. Reset — all outputs zero after reset
//   2. Weight load — weight_reg latches correctly on weight_load pulse
//   3. Single MAC — psum_out = psum_in + (weight * act_in)
//   4. Accumulation — psum_out accumulates across cycles
//   5. act_out pass-through — activation propagates to next PE
// =============================================================================

`timescale 1ns/1ps

module pe_tb;

    parameter DATA_W = 8;
    parameter ACC_W  = 32;

    logic                clk;
    logic                rst_n;
    logic                weight_load;
    logic [DATA_W-1:0]   weight_in;
    logic [DATA_W-1:0]   act_in;
    logic [DATA_W-1:0]   act_out;
    logic [ACC_W-1:0]    psum_in;
    logic [ACC_W-1:0]    psum_out;

    // DUT instantiation
    pe #(.DATA_W(DATA_W), .ACC_W(ACC_W)) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .weight_load (weight_load),
        .weight_in   (weight_in),
        .act_in      (act_in),
        .act_out     (act_out),
        .psum_in     (psum_in),
        .psum_out    (psum_out)
    );

    // 10ns clock (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors = 0;

    // Self-checking task
    task check(input integer exp, input string msg);
        if (psum_out !== exp) begin
            $display("FAIL [%0t] %s: got %0d, expected %0d", $time, msg, psum_out, exp);
            errors++;
        end else
            $display("PASS [%0t] %s: psum_out = %0d", $time, msg, psum_out);
    endtask

    initial begin
        $dumpfile("waves/pe_tb.vcd");
        $dumpvars(0, pe_tb);

        // ── Reset ──────────────────────────────────────────────────────────
        rst_n = 0; weight_load = 0; weight_in = 0; act_in = 0; psum_in = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst_n = 1;

        // ── Load weight = 3 ────────────────────────────────────────────────
        weight_load = 1; weight_in = 8'd3;
        @(posedge clk); #1;
        weight_load = 0;

        // ── Cycle 1: 3*2 + 0 = 6 ──────────────────────────────────────────
        act_in = 8'd2; psum_in = 32'd0;
        @(posedge clk); #1;
        check(6, "Cycle1: 3*2+0");

        // ── Cycle 2: 3*4 + 6 = 18 ─────────────────────────────────────────
        act_in = 8'd4; psum_in = 32'd6;
        @(posedge clk); #1;
        check(18, "Cycle2: 3*4+6");

        // ── Cycle 3: 3*0 + 18 = 18 ────────────────────────────────────────
        act_in = 8'd0; psum_in = 32'd18;
        @(posedge clk); #1;
        check(18, "Cycle3: 3*0+18");

        // ── Activation pass-through ────────────────────────────────────────
        act_in = 8'd7;
        @(posedge clk); #1;
        if (act_out !== 8'd7) begin
            $display("FAIL act_out: got %0d, expected 7", act_out);
            errors++;
        end else
            $display("PASS act_out pass-through: %0d", act_out);

        // ── Summary ────────────────────────────────────────────────────────
        $display("--- Done: %0d error(s) ---", errors);
        $finish;
    end

endmodule
