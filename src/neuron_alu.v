// neuron_alu.v - THE one shared adder. Leak: V - (V>>K).  Integrate: V + W.  Saturates to 0..255.
`default_nettype none
module neuron_alu (
    input  wire [7:0] vn,
    input  wire [2:0] kreg,
    input  wire [1:0] w2,        // signed 2-bit weight (-2..+1)
    input  wire       is_leak,
    output wire [7:0] result
);
  wire [7:0] leak_amt = vn >> kreg;
  wire [9:0] opb = is_leak ? (~{2'b00, leak_amt} + 10'd1) : {{8{w2[1]}}, w2};
  wire [9:0] sum = {2'b00, vn} + opb;
  assign result = sum[9] ? 8'd0 : (sum[8] ? 8'd255 : sum[7:0]);
endmodule
