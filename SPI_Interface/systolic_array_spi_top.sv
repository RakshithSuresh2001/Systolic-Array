// =============================================================================
// systolic_array_spi_top.sv — Top-level: SPI Slave + 8x8 Systolic Array
// Author: Rakshith Suresh
// =============================================================================
module systolic_array_spi_top #(
    parameter ROWS   = 8,
    parameter COLS   = 8,
    parameter DATA_W = 8,
    parameter ACC_W  = 32
)(
    input  wire  clk,
    input  wire  rst_n,

    // SPI pins (connect to external master)
    input  wire  spi_clk,
    input  wire  spi_cs_n,
    input  wire  spi_mosi,
    output wire  spi_miso,

    // Status
    output wire  busy
);

// Internal wires
wire                        weight_load;
wire [2:0]                  weight_row;
wire [COLS*DATA_W-1:0]      weight_data_flat;
wire [ROWS*DATA_W-1:0]      act_in_flat;
wire [COLS*ACC_W-1:0]       psum_out_flat;
wire                        array_rst_n;

// SPI Slave
spi_slave #(
    .ROWS(ROWS), .COLS(COLS),
    .DATA_W(DATA_W), .ACC_W(ACC_W)
) u_spi (
    .clk              (clk),
    .rst_n            (rst_n),
    .spi_clk          (spi_clk),
    .spi_cs_n         (spi_cs_n),
    .spi_mosi         (spi_mosi),
    .spi_miso         (spi_miso),
    .weight_load      (weight_load),
    .weight_row       (weight_row),
    .weight_data_flat (weight_data_flat),
    .act_in_flat      (act_in_flat),
    .array_rst_n      (array_rst_n),
    .psum_out_flat    (psum_out_flat),
    .busy             (busy)
);

// Systolic Array
systolic_array #(
    .ROWS(ROWS), .COLS(COLS),
    .DATA_W(DATA_W), .ACC_W(ACC_W)
) u_array (
    .clk              (clk),
    .rst_n            (array_rst_n),
    .weight_load      (weight_load),
    .weight_row       (weight_row),
    .weight_data_flat (weight_data_flat),
    .act_in_flat      (act_in_flat),
    .psum_out_flat    (psum_out_flat)
);

endmodule
