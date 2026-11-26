"""Bit-exact Python reference ("answer key") for the sparse LIF chip.

Rules (must match src/project.v exactly):
  * V is an unsigned 8-bit value per neuron, saturating at 0 and 255.
  * LEAK      : V = V - (V >> K)           (K = 0..7)
  * INTEGRATE : for every input i that spiked, V[n] += W[i][n]   (W signed 2-bit, -2..+1)
                inputs are visited lowest index first (order matters only through saturation).
  * FIRE      : if V >= THR: out=1 and V=0, else out=0
  * cycles    : sparse = 9 + 4*S ; dense = 41
"""
import random


def sat(x):
    return 0 if x < 0 else 255 if x > 255 else x


class SparseLIF:
    N_IN, N_NEU = 8, 4

    def __init__(self, k=2, thr=6, weights=None):
        self.k, self.thr = k, thr
        self.w = weights or [[0] * self.N_NEU for _ in range(self.N_IN)]  # w[i][n]
        self.reset()

    def reset(self):
        self.v = [0] * self.N_NEU

    def frame_bits(self):
        """Config frame, MSB first: K(3) THR(8) W[0][0]..W[7][3] (2 bits each) = 75 bits."""
        bits = []

        def push(val, width):
            for b in range(width - 1, -1, -1):
                bits.append((val >> b) & 1)

        push(self.k, 3)
        push(self.thr, 8)
        for i in range(self.N_IN):
            for n in range(self.N_NEU):
                push(self.w[i][n] & 3, 2)
        assert len(bits) == 75
        return bits

    def step(self, spikes, dense=False):
        """spikes: 8-bit int. Returns (out_nibble, cycles, S)."""
        spikes &= 0xFF
        S = bin(spikes).count("1")
        self.v = [sat(x - (x >> self.k)) for x in self.v]
        for i in range(self.N_IN):
            if spikes >> i & 1:                 # dense mode visits the rest but adds 0
                for n in range(self.N_NEU):
                    self.v[n] = sat(self.v[n] + self.w[i][n])
        out = 0
        for n in range(self.N_NEU):
            if self.v[n] >= self.thr:
                out |= 1 << n
                self.v[n] = 0
        cycles = 41 if dense else 9 + 4 * S
        return out, cycles, S

    @staticmethod
    def random_weights(rng=random):
        return [[rng.randint(-2, 1) for _ in range(4)] for _ in range(8)]


if __name__ == "__main__":
    w = [[0] * 4 for _ in range(8)]
    w[0] = [1, 0, 0, -1]
    w[1] = [1, 1, 0, 0]
    w[2] = [0, 1, 1, 0]
    m = SparseLIF(k=2, thr=4, weights=w)
    for sp in (0b011, 0b011, 0, 0b100, 0b100):
        out, cyc, S = m.step(sp)
        print(f"spikes={sp:08b} out={out:04b} V={m.v} cycles={cyc}")
