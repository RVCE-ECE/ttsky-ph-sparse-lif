// diag_counters.v - the chip measures itself. Counters HOLD their value after a timestep ends
// and are restarted by the next one (no separate "last" copies -> saves flops).
//   RD_SEL 00: cycles[3:0]   01: cycles[5:4]   10: S (input spikes)   11: number of neurons that fired
`default_nettype none
module diag_counters (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       clr,
    input  wire       st_idle,
    input  wire       load,       // LATCH cycle: restart the counters
    input  wire       s_inc,
    input  wire [3:0] out_spikes,
    input  wire [1:0] rd_sel,
    output reg  [3:0] diag
);
  reg [5:0] cyc;
  reg [3:0] s_cnt;

  always @(posedge clk) begin
    if (!rst_n || clr) begin
      cyc <= 6'd0; s_cnt <= 4'd0;
    end else begin
      if (load)          cyc <= 6'd1;                 // the LATCH cycle itself is cycle 1
      else if (!st_idle) cyc <= cyc + 6'd1;
      if (load)          s_cnt <= 4'd0;
      else if (s_inc)    s_cnt <= s_cnt + 4'd1;
    end
  end

  wire [2:0] fired = {2'b00, out_spikes[0]} + {2'b00, out_spikes[1]}
                   + {2'b00, out_spikes[2]} + {2'b00, out_spikes[3]};

  always @* begin
    case (rd_sel)
      2'd0: diag = cyc[3:0];
      2'd1: diag = {2'b00, cyc[5:4]};
      2'd2: diag = s_cnt;
      default: diag = {1'b0, fired};
    endcase
  end
endmodule
