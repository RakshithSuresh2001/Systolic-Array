`timescale 1ns/1ps
module spi_tb;

parameter CLK_PERIOD = 2;
parameter SPI_PERIOD = 20;

reg  clk, rst_n;
reg  spi_clk, spi_cs_n, spi_mosi;
wire spi_miso, busy;

systolic_array_spi_top dut (
    .clk(clk), .rst_n(rst_n),
    .spi_clk(spi_clk), .spi_cs_n(spi_cs_n),
    .spi_mosi(spi_mosi), .spi_miso(spi_miso),
    .busy(busy)
);

always #(CLK_PERIOD/2) clk = ~clk;

task spi_send_byte(input [7:0] data);
    integer i;
    for (i = 7; i >= 0; i--) begin
        spi_mosi = data[i];
        #(SPI_PERIOD/2);
        spi_clk = 1;
        #(SPI_PERIOD/2);
        spi_clk = 0;
    end
endtask

task spi_recv_byte(output [7:0] data);
    integer i;
    for (i = 7; i >= 0; i--) begin
        spi_mosi = 0;
        #(SPI_PERIOD/2);
        spi_clk = 1;
        #2;    // Small Delay after the rising edge
        data[i] = spi_miso;
        #(SPI_PERIOD/2);
        spi_clk = 0;
    end
endtask

task spi_start; spi_cs_n = 0; #(SPI_PERIOD); endtask
task spi_stop;  spi_cs_n = 1; #(SPI_PERIOD); endtask

integer i, j;
reg [31:0] psum[7:0];

initial begin
    $dumpfile("spi_wave.vcd");
    $dumpvars(0, spi_tb);

    clk = 0; rst_n = 0;
    spi_clk = 0; spi_cs_n = 1; spi_mosi = 0;
    #20; rst_n = 1; #20;

    // Load weights
    $display("=== Loading weights (weight=3) ===");
    for (i = 0; i < 8; i++) begin
        spi_start;
        spi_send_byte(8'h01);
        spi_send_byte(i[7:0]);
        for (j = 0; j < 8; j++)
            spi_send_byte(8'd3);
        spi_stop;
        #200;
    end

    // Feed activations
    $display("=== Feeding activations (act=2 x 8 cycles) ===");
    repeat(8) begin
        spi_start;
        spi_send_byte(8'h02);
        for (j = 0; j < 8; j++)
            spi_send_byte(8'd2);
        spi_stop;
        #200;
    end

    // Wait for pipeline
    #5000;

    // Debug
    $display("DEBUG col0 = %0d", dut.u_array.psum_out_flat[255:224]);
    $display("DEBUG col1 = %0d", dut.u_array.psum_out_flat[223:192]);

    // Read psums
    $display("=== Reading psums via SPI ===");
    spi_start;
    spi_send_byte(8'h03);
    #(SPI_PERIOD*4);

    for (i = 0; i < 8; i++) begin
        spi_recv_byte(psum[i][31:24]);
        spi_recv_byte(psum[i][23:16]);
        spi_recv_byte(psum[i][15:8]);
        spi_recv_byte(psum[i][7:0]);
        $display("DEBUG SPI col[%0d] = %h", i, psum[i]);
    end
    spi_stop;

    $display("=== Results ===");
    for (i = 0; i < 8; i++) begin
        if (psum[i] == 32'd48)
            $display("PASS col[%0d] = %0d", i, psum[i]);
        else
            $display("FAIL col[%0d] = %0d (expected 48)", i, psum[i]);
    end

    $finish;
end
endmodule
