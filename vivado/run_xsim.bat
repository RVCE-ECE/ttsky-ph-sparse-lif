@echo off
REM Run from the vivado folder in a Vivado command prompt
xvlog ..\src\project.v ..\src\input_sync.v ..\src\config_store.v ..\src\weight_mux.v ..\src\prio_encoder.v ..\src\spike_latch.v ..\src\membrane_file.v ..\src\neuron_alu.v ..\src\threshold_cmp.v ..\src\control_fsm.v ..\src\output_reg.v ..\src\diag_counters.v tb_sparse_lif.v
xelab -debug typical tb_sparse_lif -s sim_snap
xsim sim_snap -runall
