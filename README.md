![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Sparse Event-Driven LIF Neurons - Tiny Tapeout

4 leaky integrate-and-fire neurons, 8 spike inputs, one shared saturating adder.
**Sparse mode** only processes inputs that spiked (`9 + 4*S` cycles); **dense mode** always takes 41.
The chip reports its own cycle count, so the speed-up is measurable on silicon.

- [Datasheet / usage](docs/info.md)

## Layout
```
info.yaml            Tiny Tapeout project config (top module, pinout, tiles)
src/project.v        TOP module tt_um_pranavhegdee_sparse_lif (wires the blocks together)
src/input_sync.v     2-flop synchronisers + edge detect (CFG_CLK, STEP)
src/config_store.v   107-bit config shift register: K, THR, 32 weights
src/weight_mux.v     selects W[input][neuron] from the weight store
src/prio_encoder.v   lowest-pending-input encoder
src/spike_latch.v    spike snapshot + pending mask (sparse/dense)
src/membrane_file.v  4 x 8-bit membrane potentials
src/neuron_alu.v     the ONE shared saturating adder (leak + integrate)
src/threshold_cmp.v  comparator V >= THR
src/control_fsm.v    IDLE/LATCH/LEAK/INT/FIRE sequencer + neuron counter
src/output_reg.v     4 output spike flops
src/diag_counters.v  cycle counter, S counter, output-spike counter, diag mux
src/config.json      default LibreLane config (untouched)
test/tb.v            cocotb wrapper testbench
test/test.py         cocotb tests (RTL vs bit-exact model; also run at gate level by CI)
test/lif_model.py    Python reference model ("answer key")
test/Makefile        cocotb + Icarus
docs/info.md         datasheet text
board/measure.py     RP2040 measurement script (cycles vs S)
board/plot.py        plot cycles vs sparsity
vivado/              plain-Verilog self-checking testbench for Vivado xsim
.github/workflows/   CI: test, gds (+precheck, gate-level test), docs, fpga
```

## Run locally
```
cd test && make clean && make && python -m cocotb_tools.check_results results.xml
```
