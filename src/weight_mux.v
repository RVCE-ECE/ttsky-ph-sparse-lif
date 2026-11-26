// weight_mux.v - picks W[input][neuron] (2-bit two's complement) out of the weight store.
`default_nettype none
module weight_mux (
    input  wire [63:0] wts,
    input  wire [2:0]  in_idx,   // input number 0..7
    input  wire [1:0]  n,        // neuron number 0..3
    output wire [1:0]  w2
);
  wire [4:0] widx = {in_idx, n};                  // 0..31
  wire [1:0] w [0:31];
  genvar j;
  generate
    for (j = 0; j < 32; j = j + 1) begin : g_w
      assign w[j] = wts[(31 - j) * 2 +: 2];       // W[0][0] sits in the top bits
    end
  endgenerate
  assign w2 = w[widx];
endmodule
