// spike_latch.v - spike snapshot + pending mask (sparse: = spikes, dense: all ones)
// + priority encoder that walks through the pending inputs.
`default_nettype none
module spike_latch (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       load,          // snapshot ui_in, build pending mask
    input  wire       retire,        // current input finished: clear it from pending
    input  wire       dense,
    input  wire [7:0] ui_in,
    output wire [2:0] cur_i,         // lowest pending input
    output wire       cur_spiked,    // did the current input really spike?
    output wire       any_pending,
    output wire       last_pending   // current input is the only one left
);
  reg [7:0] spikes, pending;

  prio_encoder u_pe (.req(pending), .idx(cur_i));

  wire [7:0] onehot       = 8'd1 << cur_i;
  wire [7:0] pending_next = pending & ~onehot;

  always @(posedge clk) begin
    if (!rst_n) begin
      spikes <= 8'd0; pending <= 8'd0;
    end else if (load) begin
      spikes  <= ui_in;
      pending <= dense ? 8'hFF : ui_in;
    end else if (retire) begin
      pending <= pending_next;
    end
  end

  assign cur_spiked   = spikes[cur_i];
  assign any_pending  = |pending;
  assign last_pending = (pending_next == 8'd0);
endmodule
