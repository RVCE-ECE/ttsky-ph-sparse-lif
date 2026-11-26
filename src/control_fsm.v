// control_fsm.v - the conductor: IDLE -> LATCH -> LEAK -> INT(per pending input) -> FIRE -> IDLE.
// n counts neurons 0..3 inside every phase. All strobes are masked while cfg_en is high.
`default_nettype none
module control_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       cfg_en,
    input  wire       step_rise,
    input  wire       any_pending,
    input  wire       last_pending,
    input  wire       cur_spiked,
    input  wire       fire_cond,
    output wire [1:0] n,
    output wire       st_idle,
    output wire       is_leak,
    output wire       load,       // LATCH cycle
    output wire       retire,     // last neuron of an INT group
    output wire       v_wr,       // write a membrane potential
    output wire       v_zero,     // ... with zero (fire/reset) instead of ALU result
    output wire       out_we,     // FIRE cycle: update output flop n
    output wire       s_inc,      // count one input spike
    output wire       osum_inc,   // count one output spike
    output wire       done        // last cycle of the timestep
);
  localparam S_IDLE = 3'd0, S_LATCH = 3'd1, S_LEAK = 3'd2, S_INT = 3'd3, S_FIRE = 3'd4;

  reg [2:0] state;
  reg [1:0] n_r;
  assign n = n_r;

  always @(posedge clk) begin
    if (!rst_n) begin
      state <= S_IDLE; n_r <= 2'd0;
    end else if (cfg_en) begin
      state <= S_IDLE; n_r <= 2'd0;
    end else begin
      case (state)
        S_IDLE: begin
          n_r <= 2'd0;
          if (step_rise) state <= S_LATCH;
        end
        S_LATCH: begin
          n_r   <= 2'd0;
          state <= S_LEAK;
        end
        S_LEAK: begin
          n_r <= n_r + 2'd1;
          if (n_r == 2'd3) state <= any_pending ? S_INT : S_FIRE;
        end
        S_INT: begin
          n_r <= n_r + 2'd1;
          if (n_r == 2'd3 && last_pending) state <= S_FIRE;
        end
        S_FIRE: begin
          n_r <= n_r + 2'd1;
          if (n_r == 2'd3) state <= S_IDLE;
        end
        default: state <= S_IDLE;
      endcase
    end
  end

  wire en       = ~cfg_en;
  wire st_latch = (state == S_LATCH);
  wire st_leak  = (state == S_LEAK);
  wire st_int   = (state == S_INT);
  wire st_fire  = (state == S_FIRE);
  wire n_is_3   = (n_r == 2'd3);

  assign st_idle  = (state == S_IDLE);
  assign is_leak  = st_leak;
  assign load     = st_latch & en;
  assign retire   = st_int & n_is_3 & en;
  assign v_wr     = en & (st_leak | (st_int & cur_spiked) | (st_fire & fire_cond));
  assign v_zero   = st_fire;
  assign out_we   = st_fire & en;
  assign s_inc    = st_int & cur_spiked & (n_r == 2'd0) & en;
  assign osum_inc = st_fire & fire_cond & en;
  assign done     = st_fire & n_is_3 & en;
endmodule
