# Run on a PC: plots cycles vs S (paste the measured values, or the model's, below).
import matplotlib.pyplot as plt
S = list(range(9))
sparse = [9 + 4 * s for s in S]     # replace with measured values from measure.py
dense = [41] * 9
plt.plot(S, sparse, "o-", label="sparse (9+4S)")
plt.plot(S, dense, "s-", label="dense (41)")
plt.xlabel("input spikes S"); plt.ylabel("cycles per timestep"); plt.legend(); plt.grid(True)
plt.savefig("cycles_vs_sparsity.png", dpi=150)
