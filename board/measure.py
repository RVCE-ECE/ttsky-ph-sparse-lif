# MicroPython for the Tiny Tapeout demo board (RP2040).
# Uses the TT SDK:  from ttboard.demoboard import DemoBoard
# Adjust the project name to what your shuttle slot is called.
import time
from ttboard.demoboard import DemoBoard

K, THR = 2, 4
W = [[0] * 4 for _ in range(8)]          # W[i][n], -2..+1
W[0] = [1, 0, 0, -1]; W[1] = [1, 1, 0, 0]; W[2] = [0, 1, 1, 0]

CFG_EN, CFG_CLK, CFG_DATA, STEP, DENSE = 0, 1, 2, 3, 4   # uio bit numbers
tt = DemoBoard.get()
tt.shuttle.tt_um_sparse_lif.enable()
tt.clock_project_PWM(10_000_000)
tt.reset_project(True); time.sleep_ms(1); tt.reset_project(False)
# uio pins 0-6 must be driven as inputs, uio[7] (BUSY) read as output.
# The TT SDK normally does this from the project's pinout; set tt.mode / tt.uio_oe_pico if needed.

def uio(bit, val):
    tt.uio_in[bit] = val

def bits():
    b = []
    def push(v, w):
        for i in range(w - 1, -1, -1): b.append((v >> i) & 1)
    push(K, 3); push(THR, 8)
    for i in range(8):
        for n in range(4): push(W[i][n] & 3, 2)
    return b

def configure():
    uio(CFG_EN, 1)
    for bit in bits():
        uio(CFG_DATA, bit); time.sleep_us(5)
        uio(CFG_CLK, 1);   time.sleep_us(5)
        uio(CFG_CLK, 0);   time.sleep_us(5)
    uio(CFG_EN, 0); time.sleep_us(10)

def nibble(sel):
    tt.uio_in[5] = sel & 1; tt.uio_in[6] = sel >> 1
    time.sleep_us(5)
    return (int(tt.uo_out.value) >> 4) & 0xF

def step(spikes, dense):
    tt.ui_in.value = spikes
    uio(DENSE, dense); time.sleep_us(5)
    uio(STEP, 1); time.sleep_us(5); uio(STEP, 0)
    while tt.uio_out[7]: pass           # wait for BUSY to fall
    out = int(tt.uo_out.value) & 0xF
    cyc = nibble(0) | (nibble(1) & 3) << 4
    return out, cyc

configure()
print("S, sparse_cycles, dense_cycles   (expect 9+4S and 41)")
for S in range(9):
    sp = (1 << S) - 1
    _, cs = step(sp, 0)
    _, cd = step(sp, 1)
    print(S, cs, cd)
