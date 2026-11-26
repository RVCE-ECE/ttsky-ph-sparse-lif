/*
 * project.v - TOP MODULE: Sparse event-driven LIF neuron core (Tiny Tapeout)
 *
 * 8 spike inputs, 4 leaky integrate-and-fire neurons, ONE shared adder.
 * Sparse mode visits only inputs that spiked: cycles = 9 + 4*S.  Dense mode: 41.
 *
 * Pin map
 *   ui_in[7:0]   spike inputs (hold stable from before STEP until BUSY falls)
 *   uo_out[3:0]  neuron spikes of the last timestep
 *   uo_out[7:4]  diagnostic nibble selected by RD_SEL
 *   uio[0] CFG_EN  | uio[1] CFG_CLK | uio[2] CFG_DATA | uio[3] STEP | uio[4] DENSE
 *   uio[5] RD_SEL[0] | uio[6] RD_SEL[1] | uio[7] BUSY (output)
 *   RD_SEL: 00 cycles[3:0] | 01 cycles[5:4] | 10 S | 11 number of neurons that fired
 *
 * Sub-modules (one file each, all in src/):
 *   input_sync, config_store, weight_mux, prio_encoder, spike_latch, membrane_file,
 *   neuron_alu, threshold_cmp, control_fsm, output_reg, diag_counters
 */
`default_nettype none

module tt_um_pranavhegdee_sparse_lif (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
  // ---- pin decode ----
  wire       dense  = uio_in[4];
  wire [1:0] rd_sel = uio_in[6:5];

  // ---- internal wires ----
  wire        cfg_en, cfg_rise, step_rise;
  wire        cfg_data = uio_in[2];   // sampled on the cfg_rise pulse (host holds it stable)
  wire [2:0]  kreg;
  wire [7:0]  thr;
  wire [63:0] wts;
  wire [2:0]  cur_i;
  wire [1:0]  w2;
  wire        cur_spiked, any_pending, last_pending;
  wire [1:0]  n;
  wire        st_idle, is_leak, load, retire, v_wr, v_zero, out_we, s_inc;
  wire [7:0]  vn, alu_out;
  wire        fire_cond;
  wire [3:0]  out_spikes, diag;

  input_sync u_sync (
      .clk(clk), .rst_n(rst_n),
      .cfg_en_in(uio_in[0]), .cfg_clk_in(uio_in[1]), .step_in(uio_in[3]),
      .cfg_en(cfg_en), .cfg_rise(cfg_rise), .step_rise(step_rise));

  config_store u_cfg (
      .clk(clk), .rst_n(rst_n), .cfg_en(cfg_en), .cfg_rise(cfg_rise), .cfg_data(cfg_data),
      .kreg(kreg), .thr(thr), .wts(wts));

  control_fsm u_fsm (
      .clk(clk), .rst_n(rst_n), .cfg_en(cfg_en), .step_rise(step_rise),
      .any_pending(any_pending), .last_pending(last_pending),
      .cur_spiked(cur_spiked), .fire_cond(fire_cond),
      .n(n), .st_idle(st_idle), .is_leak(is_leak), .load(load), .retire(retire),
      .v_wr(v_wr), .v_zero(v_zero), .out_we(out_we), .s_inc(s_inc));

  spike_latch u_spk (
      .clk(clk), .rst_n(rst_n), .load(load), .retire(retire), .dense(dense), .ui_in(ui_in),
      .cur_i(cur_i), .cur_spiked(cur_spiked), .any_pending(any_pending), .last_pending(last_pending));

  weight_mux u_wmux (.wts(wts), .in_idx(cur_i), .n(n), .w2(w2));

  membrane_file u_mem (
      .clk(clk), .rst_n(rst_n), .clr(cfg_en), .wr_en(v_wr), .n(n),
      .wdata(v_zero ? 8'd0 : alu_out), .vn(vn));

  neuron_alu u_alu (.vn(vn), .kreg(kreg), .w2(w2), .is_leak(is_leak), .result(alu_out));

  threshold_cmp u_cmp (.vn(vn), .thr(thr), .fire(fire_cond));

  output_reg u_out (
      .clk(clk), .rst_n(rst_n), .clr(cfg_en), .we(out_we), .n(n), .bitval(fire_cond),
      .out(out_spikes));

  diag_counters u_diag (
      .clk(clk), .rst_n(rst_n), .clr(cfg_en), .st_idle(st_idle), .load(load),
      .s_inc(s_inc), .out_spikes(out_spikes), .rd_sel(rd_sel), .diag(diag));

  // ---- outputs ----
  wire busy = ~st_idle | step_rise;
  assign uo_out  = {diag, out_spikes};
  assign uio_out = {busy, 7'b0};
  assign uio_oe  = 8'b1000_0000;

  wire _unused = &{ena, uio_in[7], 1'b0};
endmodule
