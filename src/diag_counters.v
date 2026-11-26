// diag_counters.v - the chip measures itself: cycles of last step, S, cumulative output spikes.
`default_nettype none
module diag_counters (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       clr,
    input  wire       st_idle,
    input  wire       s_clear,    // start of a timestep
    input  wire       s_inc,
    input  wire       osum_inc,
    input  wire       done,
    input  wire [1:0] rd_sel,
    output reg  [3:0] diag
);
  reg [5:0] cyc, cyc_last;
  reg [3:0] s_cnt, s_last, osum;

  always @(posedge clk) begin
    if (!rst_n || clr) begin
      cyc <= 6'd0; cyc_last <= 6'd0; s_last <= 4'd0; osum <= 4'd0;
    end else begin
      cyc <= st_idle ? 6'd0 : cyc + 6'd1;
      if (done) begin
        cyc_last <= cyc + 6'd1;
        s_last   <= s_cnt;
      end
      if (osum_inc && osum != 4'd15) osum <= osum + 4'd1;
    end
  end

  always @(posedge clk) begin
    if (!rst_n)       s_cnt <= 4'd0;
    else if (s_clear) s_cnt <= 4'd0;
    else if (s_inc)   s_cnt <= s_cnt + 4'd1;
  end

  always @* begin
    case (rd_sel)
      2'd0: diag = cyc_last[3:0];
      2'd1: diag = {2'b00, cyc_last[5:4]};
      2'd2: diag = s_last;
      default: diag = osum;
    endcase
  end
endmodule
