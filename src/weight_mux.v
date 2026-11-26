// weight_mux.v - picks W[input][neuron] (3-bit two's complement) out of the weight store.
`default_nettype none
module weight_mux (
    input  wire [95:0] wts,
    input  wire [2:0]  in_idx,   // input number 0..7
    input  wire [1:0]  n,        // neuron number 0..3
    output wire [2:0]  w3
);
  wire [4:0] widx  = {in_idx, n};                       // 0..31
  wire [6:0] wbase = (7'd31 - {2'b00, widx}) * 7'd3;
  assign w3 = wts[wbase +: 3];
endmodule
