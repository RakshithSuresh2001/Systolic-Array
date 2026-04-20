// =============================================================================
// pe.sv — Processing Element for 8x8 Weight-Stationary Systolic Array
// Author: Rakshith Suresh
// -----------------------------------------------------------------------------
// Implements a single MAC unit. The weight is loaded once via weight_load
// and held fixed (weight-stationary dataflow). Activations pass through
// horizontally to the next PE. Partial sums accumulate vertically.
//
// Operation each clock cycle (when not in reset):
//   psum_out = psum_in + (weight_reg * act_in)
//   act_out  = act_in   (registered 1-cycle pass-through)
//
// Parameters:
//   DATA_W — bit width of activations and weights (default 8)
//   ACC_W  — bit width of accumulator (default 32)
// =============================================================================

module pe #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32
)(
    input  logic                clk,
    input  logic                rst_n,      // active-low synchronous reset

    // Weight load interface
    input  logic                weight_load,        // pulse high to latch weight
    input  logic [DATA_W-1:0]   weight_in,

    // Activation dataflow (horizontal, left → right)
    input  logic [DATA_W-1:0]   act_in,
    output logic [DATA_W-1:0]   act_out,            // registered pass-through

    // Partial sum dataflow (vertical, top → bottom)
    input  logic [ACC_W-1:0]    psum_in,
    output logic [ACC_W-1:0]    psum_out
);

    logic [DATA_W-1:0] weight_reg;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            weight_reg <= '0;
            act_out    <= '0;
            psum_out   <= '0;
        end else begin
            // Latch weight when signalled — held fixed thereafter
            if (weight_load)
                weight_reg <= weight_in;

            // Pass activation to next PE (registered — 1 cycle latency)
            act_out <= act_in;

            // MAC: accumulate incoming partial sum
            psum_out <= psum_in + (weight_reg * act_in);
        end
    end

endmodule
