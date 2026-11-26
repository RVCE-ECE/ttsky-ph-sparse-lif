# cocotb testbench: RTL vs bit-exact Python model.
# SPDX-FileCopyrightText: © 2026
# SPDX-License-Identifier: Apache-2.0
import os, random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from lif_model import SparseLIF

GATE_LEVEL = os.environ.get("GATES") == "yes"   # gate-level sim is slow: fewer random trials

CFG_EN, CFG_CLK, CFG_DATA, STEP, DENSE = 1 << 0, 1 << 1, 1 << 2, 1 << 3, 1 << 4


class Host:
    """Plays the role of the RP2040."""

    def __init__(self, dut):
        self.dut, self.ctl = dut, 0

    def _set(self, mask, on):
        self.ctl = (self.ctl | mask) if on else (self.ctl & ~mask)
        self.dut.uio_in.value = self.ctl

    async def reset(self):
        d = self.dut
        d.ena.value, d.ui_in.value, d.uio_in.value, d.rst_n.value = 1, 0, 0, 0
        self.ctl = 0
        await ClockCycles(d.clk, 5)
        d.rst_n.value = 1
        await ClockCycles(d.clk, 5)

    async def configure(self, model):
        d = self.dut
        self._set(CFG_EN, 1)
        await ClockCycles(d.clk, 4)
        for b in model.frame_bits():
            self._set(CFG_DATA, b)
            await ClockCycles(d.clk, 4)       # data settles before clock edge
            self._set(CFG_CLK, 1)
            await ClockCycles(d.clk, 4)
            self._set(CFG_CLK, 0)
            await ClockCycles(d.clk, 4)
        self._set(CFG_DATA, 0)
        self._set(CFG_EN, 0)
        await ClockCycles(d.clk, 6)

    def busy(self):
        return (int(self.dut.uio_out.value) >> 7) & 1

    def diag(self, sel):
        self.ctl = (self.ctl & ~0x60) | (sel << 5)
        self.dut.uio_in.value = self.ctl

    async def step(self, spikes, dense):
        d = self.dut
        d.ui_in.value = spikes
        self._set(DENSE, dense)
        await ClockCycles(d.clk, 2)
        self._set(STEP, 1)
        await ClockCycles(d.clk, 4)           # BUSY is high by now
        self._set(STEP, 0)
        n = 0
        while self.busy():
            await ClockCycles(d.clk, 1)
            n += 1
            assert n < 100, "BUSY stuck high"
        await ClockCycles(d.clk, 1)
        out = int(d.uo_out.value) & 0xF
        self.diag(0); await ClockCycles(d.clk, 1)
        lo = (int(d.uo_out.value) >> 4) & 0xF
        self.diag(1); await ClockCycles(d.clk, 1)
        hi = (int(d.uo_out.value) >> 4) & 0x3
        self.diag(2); await ClockCycles(d.clk, 1)
        S = (int(d.uo_out.value) >> 4) & 0xF
        self.diag(3); await ClockCycles(d.clk, 1)
        tot = (int(d.uo_out.value) >> 4) & 0xF
        return out, (hi << 4) | lo, S, tot


async def start(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    h = Host(dut)
    await h.reset()
    return h


@cocotb.test()
async def test_worked_example(dut):
    """The hand-worked example from the design notes."""
    h = await start(dut)
    w = [[0] * 4 for _ in range(8)]
    w[0], w[1], w[2] = [3, 0, 0, -1], [2, 1, 0, 0], [0, 3, 2, 0]
    m = SparseLIF(k=2, thr=6, weights=w)
    await h.configure(m)
    expect = [(0b0000, 17), (0b0001, 17), (0b0000, 9), (0b0000, 13), (0b0010, 13)]
    for sp, (eo, ec) in zip((0b11, 0b11, 0, 0b100, 0b100), expect):
        out, cyc, S, tot = await h.step(sp, 0)
        mo, mc, mS = m.step(sp)
        assert (out, cyc) == (eo, ec) == (mo, mc), (out, cyc, eo, ec)
        assert S == mS and tot == m.out_total


@cocotb.test()
async def test_cycles_vs_sparsity(dut):
    """Sparse: 9+4S ; dense: 41 for every S = 0..8. Prints the table."""
    h = await start(dut)
    m = SparseLIF(k=3, thr=20, weights=SparseLIF.random_weights(random.Random(1)))
    await h.configure(m)
    dut._log.info("  S | sparse | dense")
    for S in range(9):
        sp = (1 << S) - 1
        _, cs, _, _ = await h.step(sp, 0)
        _, cd, _, _ = await h.step(sp, 1)
        dut._log.info(f"  {S} | {cs:6d} | {cd:5d}")
        assert cs == 9 + 4 * S and cd == 41


@cocotb.test()
async def test_random_vs_model(dut):
    """Random weights/K/THR/spikes, sparse AND dense, every timestep compared."""
    h = await start(dut)
    rng = random.Random(2024)
    for trial in range(5 if GATE_LEVEL else 25):
        m = SparseLIF(k=rng.randint(0, 7), thr=rng.randint(1, 60),
                      weights=SparseLIF.random_weights(rng))
        await h.configure(m)
        for t in range(60):
            dense = rng.random() < 0.5
            sp = rng.getrandbits(8) & rng.getrandbits(8) if rng.random() < .7 else rng.getrandbits(8)
            out, cyc, S, tot = await h.step(sp, int(dense))
            mo, mc, mS = m.step(sp, dense)
            assert (out, cyc, S, tot) == (mo, mc, mS, m.out_total), \
                f"trial {trial} t {t} sp={sp:08b} dense={dense} rtl={(out,cyc,S,tot)} model={(mo,mc,mS,m.out_total)}"


@cocotb.test()
async def test_sparse_equals_dense(dut):
    """Same chip, same stimulus: sparse and dense give identical spikes."""
    rng = random.Random(7)
    h = await start(dut)
    w = SparseLIF.random_weights(rng)
    seq = [rng.getrandbits(8) for _ in range(80)]
    res = []
    for dense in (0, 1):
        m = SparseLIF(k=2, thr=10, weights=w)
        await h.configure(m)
        res.append([(await h.step(sp, dense))[0] for sp in seq])
    assert res[0] == res[1]
