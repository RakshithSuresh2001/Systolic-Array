// SPDX-License-Identifier: Apache-2.0
// Systolic Array ML Accelerator — Caravel User Project Wrapper
// Author: Rakshith Suresh, USC Viterbi MS EE 2026

`default_nettype none

module systolic_array_user_project #(
    parameter BITS = 32
)(
`ifdef USE_POWER_PINS
    inout vccd1,
    inout vssd1,
`endif
    // Wishbone — unused but required by interface
    input  wb_clk_i,
    input  wb_rst_i,
    input  wbs_stb_i,
    input  wbs_cyc_i,
    input  wbs_we_i,
    input  [3:0]  wbs_sel_i,
    input  [31:0] wbs_dat_i,
    input  [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer — expose psum outputs for debug
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IO pads
    input  [37:0] io_in,
    output [37:0] io_out,
    output [37:0] io_oeb,    // output enable bar (0=output, 1=input)

    // IRQ
    output [2:0] irq
);

// ---------------------------------------------------------------------------
// Clock and reset from Caravel management SoC
// ---------------------------------------------------------------------------
wire clk   = wb_clk_i;
wire rst_n = ~wb_rst_i;

// ---------------------------------------------------------------------------
// SPI pin assignment
// io_in[8]  = spi_clk
// io_in[9]  = spi_cs_n
// io_in[10] = spi_mosi
// io_out[11] = spi_miso
// ---------------------------------------------------------------------------
wire spi_clk  = io_in[8];
wire spi_cs_n = io_in[9];
wire spi_mosi = io_in[10];
wire spi_miso;

// Set IO directions
assign io_oeb[8]  = 1'b1;   // input
assign io_oeb[9]  = 1'b1;   // input
assign io_oeb[10] = 1'b1;   // input
assign io_oeb[11] = 1'b0;   // output
assign io_out[11] = spi_miso;

// Tie off unused IOs
assign io_out[37:12] = 26'b0;
assign io_out[7:0]   = 8'b0;
assign io_oeb[37:12] = 26'b1;
assign io_oeb[7:0]   = 8'b1;

// Tie off wishbone outputs
assign wbs_ack_o = 1'b0;
assign wbs_dat_o = 32'b0;

// Tie off IRQ
assign irq = 3'b0;

// ---------------------------------------------------------------------------
// Internal wires between SPI slave and systolic array
// ---------------------------------------------------------------------------
wire        weight_load;
wire [2:0]  weight_row;
wire [63:0] weight_data_flat;
wire [63:0] act_in_flat;
wire        array_rst_n;
wire        spi_busy;
wire [255:0] psum_out_flat;

// ---------------------------------------------------------------------------
// SPI slave instantiation
// ---------------------------------------------------------------------------
spi_slave #(
    .ROWS   (8),
    .COLS   (8),
    .DATA_W (8),
    .ACC_W  (32)
) u_spi (
    .clk             (clk),
    .rst_n           (rst_n),
    .spi_clk         (spi_clk),
    .spi_cs_n        (spi_cs_n),
    .spi_mosi        (spi_mosi),
    .spi_miso        (spi_miso),
    .weight_load     (weight_load),
    .weight_row      (weight_row),
    .weight_data_flat(weight_data_flat),
    .act_in_flat     (act_in_flat),
    .array_rst_n     (array_rst_n),
    .psum_out_flat   (psum_out_flat),
    .busy            (spi_busy)
);

// ---------------------------------------------------------------------------
// Systolic array instantiation
// ---------------------------------------------------------------------------
systolic_array #(
    .ROWS   (8),
    .COLS   (8),
    .DATA_W (8),
    .ACC_W  (32)
) u_sa (
    .clk             (clk),
    .rst_n           (rst_n & array_rst_n),
    .weight_load     (weight_load),
    .weight_row      (weight_row),
    .weight_data_flat(weight_data_flat),
    .act_in_flat     (act_in_flat),
    .psum_out_flat   (psum_out_flat)
);

// ---------------------------------------------------------------------------
// Logic analyzer output — expose first 128 bits of psum for debug
// ---------------------------------------------------------------------------
assign la_data_out = psum_out_flat[127:0];

endmodule
`default_nettype wire
