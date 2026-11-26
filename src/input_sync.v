// input_sync.v - 2-flop synchronisers for the control pins + edge detectors.
// CFG_DATA is NOT synchronised: it is sampled on the CFG_CLK edge pulse, so the host must
// hold CFG_DATA stable for >= 4 clk cycles around each CFG_CLK edge.
`default_nettype none
module input_sync (
    input  wire clk,
    input  wire rst_n,
    input  wire cfg_en_in,
    input  wire cfg_clk_in,
    input  wire step_in,
    output wire cfg_en,      // synchronised level
    output wire cfg_rise,    // 1-cycle pulse on CFG_CLK rising edge
    output wire step_rise    // 1-cycle pulse on STEP rising edge
);
  reg [1:0] cfg_en_s;
  reg [2:0] cfg_clk_s, step_s;

  always @(posedge clk) begin
    if (!rst_n) begin
      cfg_en_s <= 2'b0; cfg_clk_s <= 3'b0; step_s <= 3'b0;
    end else begin
      cfg_en_s  <= {cfg_en_s[0],     cfg_en_in};
      cfg_clk_s <= {cfg_clk_s[1:0],  cfg_clk_in};
      step_s    <= {step_s[1:0],     step_in};
    end
  end

  assign cfg_en    = cfg_en_s[1];
  assign cfg_rise  = cfg_clk_s[1] & ~cfg_clk_s[2];
  assign step_rise = step_s[1] & ~step_s[2];
  wire _unused = &{cfg_clk_s[0], step_s[0], 1'b0};
endmodule
