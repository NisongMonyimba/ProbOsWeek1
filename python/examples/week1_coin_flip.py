"""
================================================================================
python/examples/week1_coin_flip.py
================================================================================
Week 1 Example 1: The Law of Large Numbers through coin flipping.

PURPOSE:
--------
This is the simplest possible probabilistic program. We use it to demonstrate
three foundational ideas that underpin ALL of ProbOS:

  1. RANDOMNESS IS QUANTIFIABLE
     We do not know whether a single coin flip is heads or tails.
     But we know the probability is exactly 0.5 for a fair coin.
     This is the Kolmogorov axiom: P(heads) + P(tails) = 1.

  2. THE LAW OF LARGE NUMBERS (LLN)
     With more samples, our estimate gets closer to the true probability.
     After 10 flips: estimate might be 0.3 or 0.7 (far from 0.5).
     After 1,000,000 flips: estimate will be extremely close to 0.5.
     This is WHY Monte Carlo simulation works: N samples → correct answer.

  3. REPRODUCIBILITY THROUGH SEEDS
     By passing seed=42 to the random number generator, we get the SAME
     sequence of coin flips every time. Same seed → same output. Always.
     This is essential for debugging, testing, and regulatory compliance.

HOW TO RUN:
-----------
  python python/examples/week1_coin_flip.py

WHAT YOU SHOULD SEE:
--------------------
  N=10:       maybe 40% or 60% heads (wide variation)
  N=100:      getting closer to 50%
  N=1,000:    very close to 50%
  N=10,000:   even closer
  N=100,000:  essentially 50.0%
  N=1,000,000: indistinguishable from 50.0%

The error shrinks like 1/sqrt(N) — this is the CONVERGENCE RATE of Monte Carlo.
To halve the error, you need 4x more samples. This drives the GPU acceleration
strategy in Month 3: more cores = more samples = better answer.
================================================================================
"""

# We only need numpy here — no ProbOS classes yet.
# The coin flip is so simple that using the Distribution ABC would be overkill.
import numpy as np


def run_coin_flip_experiment(
    n_flips: int,
    seed: int = 42,
    verbose: bool = True,
) -> float:
    """
    Simulate n_flips fair coin flips and return the empirical frequency of heads.

    Parameters
    ----------
    n_flips : int
        Number of coin flips to simulate. Try values from 10 to 1,000,000.
    seed : int
        Random number generator seed for reproducibility.
        Same seed + same n_flips = same result every time.
    verbose : bool
        If True, print a detailed report. If False, return quietly.

    Returns
    -------
    float
        The empirical frequency of heads (a value between 0 and 1).
        True probability for a fair coin = 0.5.
        The further from 0.5, the worse our estimate.
    """
    # Create a reproducible random number generator.
    # np.random.default_rng(seed) creates a PCG64 generator seeded at `seed`.
    # PCG64 is the modern, statistically superior replacement for Mersenne Twister.
    # NEVER use np.random.seed() (global state, not thread-safe, legacy API).
    rng = np.random.default_rng(seed)

    # Simulate n_flips coin flips.
    # rng.integers(0, 2, size=n_flips) generates integers in {0, 1}:
    #   0 = tails
    #   1 = heads
    # Each flip is independent (this is the "iid" property: independent and
    # identically distributed, fundamental to Monte Carlo theory).
    flips = rng.integers(0, 2, size=n_flips)

    # Count heads and compute frequency.
    n_heads       = int(flips.sum())     # sum of 0s and 1s = count of 1s
    freq_heads    = n_heads / n_flips    # fraction in [0, 1]
    error         = abs(freq_heads - 0.5)  # distance from true probability

    # The standard error of a sample proportion p from n trials is:
    # SE = sqrt(p * (1-p) / n)
    # For p = 0.5: SE = sqrt(0.25 / n) = 0.5 / sqrt(n)
    # The 2-sigma interval is: true_p ± 2 * SE = 0.5 ± 1/sqrt(n)
    standard_error = np.sqrt(0.5 * 0.5 / n_flips)

    if verbose:
        # Format n_flips with commas for readability: 1000000 → 1,000,000
        print(f"  N = {n_flips:>10,d} flips:")
        print(f"    Heads: {n_heads:>10,d} ({freq_heads:.6f})")
        print(f"    Tails: {n_flips - n_heads:>10,d} ({1-freq_heads:.6f})")
        print(f"    Error: {error:.6f}  (theoretical SE = {standard_error:.6f})")

        # Warn if the error is more than 3 standard errors.
        # This should happen less than 0.3% of the time by chance.
        if error > 3 * standard_error:
            print("    ⚠ Unusually large error (> 3 SE). Try a different seed.")
        else:
            print("    ✓ Error is within 3 standard errors (expected behaviour).")

    return float(freq_heads)


def demonstrate_convergence_rate() -> None:
    """
    Show that the error shrinks like 1/sqrt(N).

    This is the CENTRAL fact about Monte Carlo simulation:
      - Double N → error shrinks by sqrt(2) ≈ 1.41
      - Quadruple N → error shrinks by 2
      - 100× N → error shrinks by 10

    In other words: to get one extra decimal place of accuracy, you need
    100 times more samples. This is why GPU acceleration matters.
    """
    print("\n" + "=" * 60)
    print("  CONVERGENCE RATE DEMONSTRATION")
    print("  Error should decrease proportional to 1/sqrt(N)")
    print("=" * 60)

    import math

    n_values = [10, 100, 1_000, 10_000, 100_000, 1_000_000]
    errors   = []

    # Use a single seed so the experiment is reproducible
    seed = 42

    for n in n_values:
        freq     = run_coin_flip_experiment(n, seed=seed, verbose=False)
        error    = abs(freq - 0.5)
        errors.append(error)
        theoretical_se = 1.0 / math.sqrt(n) * 0.5
        print(f"  N={n:>10,d}: error={error:.6f}  "
              f"(theoretical SE = {theoretical_se:.6f})")

    print()
    print("  Convergence check:")
    for i in range(1, len(n_values)):
        ratio_n      = n_values[i] / n_values[i-1]
        ratio_error  = errors[i-1] / (errors[i] + 1e-12)  # avoid division by 0
        expected_ratio = math.sqrt(ratio_n)
        print(f"  N increased {ratio_n:.0f}x → error decreased "
              f"{ratio_error:.2f}x (expected ≈ {expected_ratio:.2f}x)")


def main() -> None:
    """Main function — runs the full coin flip demonstration."""

    print()
    print("=" * 60)
    print("  ProbOS Week 1 — Example 1: Coin Flip")
    print("  Demonstrating the Law of Large Numbers")
    print("=" * 60)
    print()
    print("  A fair coin: P(heads) = P(tails) = 0.5 exactly.")
    print("  The LLN says: more flips → estimate closer to 0.5.")
    print()
    print("-" * 60)
    print("  Experiments with increasing N (seed = 42):")
    print("-" * 60)

    # Run experiments with increasing number of flips
    for n in [10, 100, 1_000, 10_000, 100_000, 1_000_000]:
        run_coin_flip_experiment(n, seed=42, verbose=True)
        print()

    # Show that different seeds give different results (for small N)
    print("-" * 60)
    print("  Same N=100, different seeds (illustrates randomness):")
    print("-" * 60)
    for seed in [1, 2, 3, 4, 5]:
        freq = run_coin_flip_experiment(100, seed=seed, verbose=False)
        print(f"  Seed {seed}: heads frequency = {freq:.4f}")

    # Demonstrate the 1/sqrt(N) convergence rate
    demonstrate_convergence_rate()

    print()
    print("=" * 60)
    print("  KEY INSIGHT:")
    print("  This 1/sqrt(N) convergence rate applies to EVERY")
    print("  Monte Carlo simulation in ProbOS:")
    print("  - Battery thermal runaway propagation time")
    print("  - Drug Phase III probability of success")
    print("  - Option model risk capital")
    print("  - Hospital ED left-without-being-seen rate")
    print("  More particles = better answer. GPU gives us more particles.")
    print("=" * 60)
    print()


# Python convention: only run main() when this file is executed directly,
# not when it is imported as a module by another file.
if __name__ == "__main__":
    main()
