// config_store.v - 107-bit config shift register = K, THR and the 32 weights ("the program").
// Frame, MSB first: K[2:0], THR[7:0], W[0][0] .. W[7][3] (3 bits each).
`default_nettype none
module config_store (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        cfg_en,
    input  wire        cfg_rise,
    input  wire        cfg_data,
    output reg  [2:0]  kreg,    // leak shift
    output reg  [7:0]  thr,     // firing threshold
    output reg  [95:0] wts      // W[0][0] in the top bits (not reset: loaded by config)
);
  always @(posedge clk) begin
    if (!rst_n) begin
      kreg <= 3'd2;
      thr  <= 8'd6;
    end else if (cfg_en && cfg_rise) begin
      {kreg, thr, wts} <= {kreg[1:0], thr, wts, cfg_data};
    end
  end
endmodule
