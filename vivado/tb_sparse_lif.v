`timescale 1ns / 1ps
// Self-checking testbench for tt_um_sparse_lif (Vivado xsim / any Verilog-2001+ simulator).
// Contains its own behavioural reference model, so no Python/cocotb is needed.
module tb_sparse_lif;

  localparam CFG_EN = 0, CFG_CLK = 1, CFG_DATA = 2, STEP = 3, DENSE = 4;

  reg        clk = 0, rst_n = 0, ena = 1;
  reg  [7:0] ui_in = 0, uio_in = 0;
  wire [7:0] uo_out, uio_out, uio_oe;

  tt_um_pranavhegdee_sparse_lif dut (.ui_in(ui_in), .uo_out(uo_out), .uio_in(uio_in),
                        .uio_out(uio_out), .uio_oe(uio_oe), .ena(ena),
                        .clk(clk), .rst_n(rst_n));

  always #5 clk = ~clk;                       // 100 MHz

  // ---------------- reference model state ----------------
  reg [2:0]  m_k;
  reg [7:0]  m_thr;
  reg [95:0] m_w;                             // W[0][0] in the top bits (same as frame order)
  reg [7:0]  m_v [0:3];
  integer    m_osum;
  integer    errors = 0, checks = 0, seed = 32'h1234_5678;

  function integer wt(input integer i, input integer n);
    reg [2:0] b;
    begin
      b  = m_w[(31 - (i * 4 + n)) * 3 +: 3];
      wt = b[2] ? (b - 8) : b;                // 3-bit two's complement -> integer
    end
  endfunction

  function [7:0] sat8(input integer x);
    begin sat8 = (x < 0) ? 8'd0 : (x > 255) ? 8'd255 : x[7:0]; end
  endfunction

  // model one timestep; returns spikes in m_out, cycles in m_cyc, S in m_S
  reg [3:0] m_out;
  integer   m_cyc, m_S;
  task model_step(input [7:0] sp, input dn);
    integer i, n;
    begin
      m_S = 0;
      for (i = 0; i < 8; i = i + 1) m_S = m_S + sp[i];
      for (n = 0; n < 4; n = n + 1) m_v[n] = sat8($signed({24'd0, m_v[n]}) - $signed({24'd0, m_v[n] >> m_k}));
      for (i = 0; i < 8; i = i + 1)
        if (sp[i])
          for (n = 0; n < 4; n = n + 1) m_v[n] = sat8($signed({24'd0, m_v[n]}) + wt(i, n));
      m_out = 0;
      for (n = 0; n < 4; n = n + 1)
        if (m_v[n] >= m_thr) begin
          m_out[n] = 1; m_v[n] = 0;
          if (m_osum < 15) m_osum = m_osum + 1;
        end
      m_cyc = dn ? 41 : 9 + 4 * m_S;
    end
  endtask

  // ---------------- "RP2040" tasks ----------------
  task wait_clk(input integer n); begin repeat (n) @(posedge clk); #1; end endtask

  task do_reset;
    begin
      rst_n = 0; uio_in = 0; ui_in = 0; wait_clk(5);
      rst_n = 1; wait_clk(5);
    end
  endtask

  task configure(input [2:0] k, input [7:0] thr, input [95:0] w);
    integer b;
    reg [106:0] frame;
    integer n;
    begin
      frame = {k, thr, w};
      m_k = k; m_thr = thr; m_w = w; m_osum = 0;
      for (n = 0; n < 4; n = n + 1) m_v[n] = 0;
      uio_in[CFG_EN] = 1; wait_clk(4);
      for (b = 106; b >= 0; b = b - 1) begin
        uio_in[CFG_DATA] = frame[b]; wait_clk(4);
        uio_in[CFG_CLK]  = 1;        wait_clk(4);
        uio_in[CFG_CLK]  = 0;        wait_clk(4);
      end
      uio_in[CFG_DATA] = 0; uio_in[CFG_EN] = 0; wait_clk(6);
    end
  endtask

  task read_diag(input [1:0] sel, output [3:0] val);
    begin
      uio_in[6:5] = sel; wait_clk(2); val = uo_out[7:4];
    end
  endtask

  // run one timestep on the DUT, compare with model; returns DUT cycles
  integer last_cycles;
  task step(input [7:0] sp, input dn);
    reg [3:0] lo, hi, s, tot;
    reg [3:0] out;
    integer cyc, guard;
    begin
      ui_in = sp; uio_in[DENSE] = dn; wait_clk(2);
      uio_in[STEP] = 1; wait_clk(4); uio_in[STEP] = 0;
      guard = 0;
      while (uio_out[7] && guard < 100) begin wait_clk(1); guard = guard + 1; end
      if (guard >= 100) begin errors = errors + 1; $display("ERROR: BUSY stuck"); end
      wait_clk(1);
      out = uo_out[3:0];
      read_diag(0, lo); read_diag(1, hi); read_diag(2, s); read_diag(3, tot);
      cyc = {hi[1:0], lo};
      model_step(sp, dn);
      checks = checks + 1;
      if (out !== m_out || cyc !== m_cyc || s !== m_S || tot !== m_osum) begin
        errors = errors + 1;
        $display("MISMATCH t=%0t sp=%b dense=%b | DUT out=%b cyc=%0d S=%0d tot=%0d | MODEL out=%b cyc=%0d S=%0d tot=%0d",
                 $time, sp, dn, out, cyc, s, tot, m_out, m_cyc, m_S, m_osum);
      end
      last_cycles = cyc;
    end
  endtask

  // ---------------- test sequence ----------------
  integer t, trial, S, cs, cd;
  reg [95:0] rw;
  reg [7:0]  rsp;
  integer    rk, rthr, i;
  reg [95:0] wex;

  initial begin
    $dumpfile("tb_sparse_lif.vcd"); $dumpvars(0, tb_sparse_lif);
    do_reset;

    // ---- Test 1: worked example from the notes (K=2, THR=6) ----
    // W[0]={+3,0,0,-1} W[1]={+2,+1,0,0} W[2]={0,+3,+2,0}
    wex = 96'd0;
    // 3-bit two's complement, index j=i*4+n, stored at bits [(31-j)*3 +: 3]
    wex[(31-0)*3  +: 3] = 3'd3;  wex[(31-3)*3  +: 3] = 3'b111;   // W[0][0]=+3, W[0][3]=-1
    wex[(31-4)*3  +: 3] = 3'd2;  wex[(31-5)*3  +: 3] = 3'd1;     // W[1][0]=+2, W[1][1]=+1
    wex[(31-9)*3  +: 3] = 3'd3;  wex[(31-10)*3 +: 3] = 3'd2;     // W[2][1]=+3, W[2][2]=+2
    configure(3'd2, 8'd6, wex);
    step(8'b011, 0); $display("worked ex step1: out=%b cycles=%0d (expect 0000, 17)", uo_out[3:0], last_cycles);
    step(8'b011, 0); $display("worked ex step2: out=%b cycles=%0d (expect 0001, 17)", uo_out[3:0], last_cycles);
    step(8'b000, 0); $display("worked ex step3: out=%b cycles=%0d (expect 0000, 9)",  uo_out[3:0], last_cycles);
    step(8'b100, 0); $display("worked ex step4: out=%b cycles=%0d (expect 0000, 13)", uo_out[3:0], last_cycles);
    step(8'b100, 0); $display("worked ex step5: out=%b cycles=%0d (expect 0010, 13)", uo_out[3:0], last_cycles);

    // ---- Test 2: cycles vs sparsity table ----
    rw = 0;
    for (i = 0; i < 32; i = i + 1) rw[i*3 +: 3] = $random(seed);
    configure(3'd3, 8'd20, rw);
    $display("\n  S | sparse | dense");
    for (S = 0; S < 9; S = S + 1) begin
      step((1 << S) - 1, 0); cs = last_cycles;
      step((1 << S) - 1, 1); cd = last_cycles;
      $display(" %2d | %6d | %5d", S, cs, cd);
      if (cs !== 9 + 4 * S || cd !== 41) begin errors = errors + 1; $display("ERROR: cycle formula"); end
    end

    // ---- Test 3: random configs and spike trains, sparse and dense ----
    for (trial = 0; trial < 25; trial = trial + 1) begin
      for (i = 0; i < 32; i = i + 1) rw[i*3 +: 3] = $random(seed);
      rk   = $random(seed) & 7;
      rthr = 1 + (($random(seed) & 32'h7FFF_FFFF) % 60);
      configure(rk[2:0], rthr[7:0], rw);
      for (t = 0; t < 60; t = t + 1) begin
        rsp = $random(seed);
        if (($random(seed) & 3) != 0) rsp = rsp & $random(seed);   // mostly sparse
        step(rsp, $random(seed) & 1);
      end
    end

    $display("\n=====================================");
    $display(" checks = %0d   errors = %0d", checks, errors);
    if (errors == 0) $display(" RESULT: PASS");
    else             $display(" RESULT: FAIL");
    $display("=====================================");
    $finish;
  end
endmodule
