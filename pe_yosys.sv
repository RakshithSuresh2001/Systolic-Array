// =============================================================================
// pe_yosys.sv — Processing Element (Yosys-Compatible, SkyWater 130nm)
// -----------------------------------------------------------------------------
// Author      : Rakshith Suresh
// Affiliation : MS Electrical Engineering 
//               University of Southern California, Viterbi School of Engineering
// Email       : rsuresh@usc.edu
// GitHub      : https://github.com/RakshithSuresh2001
// -----------------------------------------------------------------------------
// Description:
//   Yosys-compatible version of pe.sv for RTL-to-GDS synthesis.
//   Uses Verilog-2001 style (wire/reg, always) instead of SystemVerilog
//   constructs (logic, always_ff) for maximum tool compatibility.
//
//   Functionally identical to pe.sv — implements a weight-stationary MAC:
//     psum_out = psum_in + (weight_reg * act_in)
//     act_out  = act_in  (registered 1-cycle pass-through)
//
// Tool Flow:
//   Synthesis  : Yosys 0.44 → SkyWater sky130_fd_sc_hd (TT, 025C, 1V80)
//   P&R        : OpenROAD v2.0 — place, CTS, global/detail route
//   PDK        : SkyWater 130nm (sky130hd)
//   GDS Output : KLayout merge → 6_final.gds
// =============================================================================

module pe #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 weight_load,
    input  wire [DATA_W-1:0]    weight_in,
    input  wire [DATA_W-1:0]    act_in,
    output reg  [DATA_W-1:0]    act_out,
    input  wire [ACC_W-1:0]     psum_in,
    output reg  [ACC_W-1:0]     psum_out
);

    reg [DATA_W-1:0] weight_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            weight_reg <= {DATA_W{1'b0}};
            act_out    <= {DATA_W{1'b0}};
            psum_out   <= {ACC_W{1'b0}};
        end else begin
            if (weight_load)
                weight_reg <= weight_in;
            act_out  <= act_in;
            psum_out <= psum_in + (weight_reg * act_in);
        end
    end

endmodule
