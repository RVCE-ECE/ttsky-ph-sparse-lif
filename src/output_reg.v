// output_reg.v - 4 output flops, one per neuron ("who fired in the last timestep").
`default_nettype none
module output_reg (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       clr,
    input  wire       we,
    input  wire [1:0] n,
    input  wire       bitval,
    output reg  [3:0] out
);
  always @(posedge clk) begin
    if (!rst_n || clr) out <= 4'd0;
    else if (we)       out[n] <= bitval;
  end
endmodule
