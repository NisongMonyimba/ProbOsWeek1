# ProbOS — A Probabilistic Execution Runtime

<div align="center">

![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white)
![C++](https://img.shields.io/badge/C++-20-00599C?style=for-the-badge&logo=cplusplus&logoColor=white)
![Tests](https://img.shields.io/badge/Tests-202%20Python%20%2B%2013%20C%2B%2B-brightgreen?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Week%203-Complete-blue?style=for-the-badge)

**Uncertainty is a first-class data type.**

*A probabilistic operating system kernel built one week at a time.*

[What is ProbOS?](#what-is-probos) •
[Quick Start](#quick-start) •
[Architecture](#architecture) •
[Week 3 Results](#week-3-results) •
[How to Run](#how-to-run) •
[Roadmap](#roadmap)

</div>

---

## What is ProbOS?

Most software treats uncertainty as an afterthought — a special case handled
after the real computation is done. **ProbOS treats uncertainty as the default.**

The analogy with a classical operating system is precise:

| Linux | ProbOS |
|-------|--------|
| Process | Stochastic program (distribution over trajectories) |
| Memory address | Random variable node in the execution graph |
| Scheduler | Inference engine (particle filter / HMC) |
| System call | `sample`, `observe`, `condition` |
| File | Probability distribution |
| Kernel | `StochasticSystem` C++20 concept + Monte Carlo engine |

### Why does this matter?

A deterministic battery simulation uses **one** value for activation energy.
ProbOS simulates **5,000 batteries simultaneously** and finds that the
worst-case (P05) battery decomposes **11.6x faster** than the mean.
That tail risk is completely invisible to deterministic models.

---

## Quick Start

### Prerequisites

| Tool | Minimum Version | Install command |
|------|----------------|----------------|
| Ubuntu / WSL | 22.04 | [WSL Install Guide](https://learn.microsoft.com/en-us/windows/wsl/install) |
| Python | 3.11 | `sudo apt-get install python3.11` |
| g++ | 11 | `sudo apt-get install build-essential` |
| CMake | 3.22 | `sudo apt-get install cmake` |
| Ninja | any | `sudo apt-get install ninja-build` |
| Google Test | any | `sudo apt-get install libgtest-dev` |

### Clone and run (Ubuntu / WSL)

```bash
git clone https://github.com/NisongMonyimba/ProbOs
cd ProbOs
python3 -m venv .venv && source .venv/bin/activate
pip install -e '.[dev]' && pip install SALib matplotlib scipy
bash RunTests.sh   # 202 Python + 13 C++ tests
bash RunAll.sh     # all examples end-to-end
```

### Run from Windows (PowerShell)

```
1. Open File Explorer
2. In the address bar type:
   \\wsl.localhost\Ubuntu-22.04\home\nison\ProbOs
3. Right-click RunProbOS.ps1
4. Click: Run with PowerShell
5. Choose: [1] RunAll.sh
```

### Expected output

```
Step 1: Check System Requirements     PASS
Step 2: Python Virtual Environment    PASS
Step 3: Install Python Dependencies   PASS
Step 4: Python Tests (44/44)          PASS
Step 5: Build C++ Code                PASS
Step 6: C++ Tests (13/13)             PASS
Step 7: Python Examples               PASS
Step 8: C++ Demo                      PASS

ALL 8 STEPS PASSED
```

---

## Architecture

### System Layers

```
+-------------------------------------------------------------+
|                        USER CODE                            |
|   Ea = Normal(mu=135080, sigma=5000)                        |
|   samples = Ea.sample(N=5000, rng=rng)                      |
+----------------------------+--------------------------------+
                             |
                             v
+-------------------------------------------------------------+
|              PROBOS TYPE SYSTEM  (Week 1)                   |
|                                                             |
|   Distribution  (Abstract Base Class)                       |
|   +-- sample(n, rng)   -> FloatArray                        |
|   +-- pdf(x)           -> FloatArray                        |
|   +-- log_pdf(x)       -> FloatArray  [analytical, stable]  |
|   +-- ppf(u)           -> FloatArray  [inverse CDF]         |
|                                                             |
|   Normal | LogNormal | Uniform | Beta | Empirical           |
+----------------------------+--------------------------------+
                             |
             +---------------+---------------+
             v                               v
+------------------+               +------------------+
|  Python Layer    |               |   C++ Layer      |
|  numpy + scipy   |               |  std::mt19937    |
|  PCG64 RNG       |               |  C++20 standard  |
|  44 pytest tests |               |  13 Google Tests |
+------------------+               +------------------+
```

### Class Hierarchy

```
                 Distribution (ABC)
                       |
       +---------------+---------------+---------------+
       |               |               |               |
    Normal         LogNormal        Uniform           Beta       Empirical
    N(mu,s)        LN(mu,s)         U(a,b)          B(a,b)      KDE(data)
    All of R        (0,+inf)          [a,b]           [0,1]     [min,max]
```

### Repository Structure

```
ProbOs/
|
+-- python/                           Python implementation
|   +-- src/
|   |   +-- distributions.py          Distribution ABC + 5 classes (750 lines)
|   +-- tests/
|   |   +-- test_distributions.py     44 pytest tests
|   +-- examples/
|       +-- week1_coin_flip.py         Law of Large Numbers demo
|       +-- week1_normal_demo.py       Battery Ea_SEI uncertainty demo
|
+-- cpp/                              C++ implementation
|   +-- include/distributions/
|   |   +-- normal.hpp                Normal class header
|   +-- src/
|   |   +-- distributions/normal.cpp  Normal class implementation
|   |   +-- main.cpp                  C++ demo
|   +-- tests/
|       +-- test_normal.cpp            13 Google Test cases
|
+-- scripts/                          Automation
|   +-- RunAll.sh                     run all examples
|   +-- RunTests.sh                   Tests only (~30 seconds)
|   +-- setup_and_run.sh              Interactive WSL launcher
|
+-- manuscript/                       Research paper (LaTeX)
|   +-- main.tex                      Full software paper
|   +-- main.pdf                      Compiled PDF (11 pages)
|   +-- references.bib                Bibliography
|
+-- CMakeLists.txt                    C++ build configuration
+-- RunProbOS.ps1                     Windows PowerShell launcher
+-- pyproject.toml                    Python project config
+-- requirements.txt                  Python dependencies
```

---

## Week 3 Results

### The Core Insight: Why `log_pdf` Must Be Analytical

The standard approach breaks at extreme values:

```python
# WRONG: underflows to 0.0 then log gives -inf
log_density = np.log(distribution.pdf(x))

# CORRECT: analytical form, always finite
log_density = distribution.log_pdf(x)
```

Concrete example at `x = mu + 50*sigma` (50 standard deviations from mean):

| Expression | Value | Status |
|-----------|-------|--------|
| `pdf(x)` | `0.0` | Underflow to zero |
| `np.log(pdf(x))` | `-inf` | **WRONG** |
| `log_pdf(x)` analytical | `-1259.44` | **Correct** |

> A single `-inf` in Bayesian inference collapses the entire posterior.
> This is why `log_pdf` is an *abstract method* — every distribution
> must implement it analytically or the system refuses to run.

### Week 3: Monte Carlo Engine

Running N=5,000 particles through `BatteryModel2Cell` simultaneously:

| Metric | Value |
|--------|-------|
| Particles | 5,000 |
| Steps | 300 (300 min) |
| P95 − P05 temperature spread | measured |
| sigma/sqrt(N) for T1 at N=5000 | 7.30 K |
| CLT log-log slope | −0.569 (theory −0.500) |

### Week 3: Sobol Sensitivity (N_saltelli=1024, 17,408 evaluations)

| Parameter | S1 | ST | Interpretation |
|-----------|----|----|----------------|
| **Ea_SEI** | **0.457** | **0.729** | Dominates — 46% of T1 variance |
| Ea_anode | 0.235 | 0.489 | Second — 24% direct effect |
| All others | <0.03 | <0.09 | Negligible |

### Week 3: Provenance — P05 Causal Audit

```
P05 Ea_SEI mean : 144,354 J/mol
Nominal Ea_SEI  : 135,080 J/mol
Interpretation  : P05 tail has HIGHER Ea_SEI -> slower decomposition
                  -> lower temperature at short timescales (correct physics)
````

### Battery Safety Application

Manufacturing variability in lithium-ion battery SEI activation energy:

```
Ea_SEI ~ Normal(mu = 135,080 J/mol,  sigma = 5,000 J/mol)
```

| Percentile | Ea (J/mol) | Rate vs mean | Risk level |
|-----------|-----------|-------------|-----------|
| P01 | 123,448 | 32.1x FASTER | Extreme |
| P05 | 126,856 | **11.6x FASTER** | High |
| P10 | 128,672 | 6.8x faster | Elevated |
| P50 | 135,080 | 1.0x baseline | Mean (what deterministic models use) |
| P95 | 143,304 | 0.09x slower | Low |
| P99 | 146,712 | 0.03x slower | Very low |

> The deterministic model sees only P50.
> ProbOS simulates all 5,000 batteries and finds the dangerous P05 tail.

### Test Suite

```
Python (pytest)                            C++ (Google Test)
------------------------------------------  ----------------------------
TestNormalConstruction      6/6    PASS     NormalConstructor    4/4  PASS
TestNormalSampling          5/5    PASS     NormalSampling       3/3  PASS
TestNormalDensity           5/5    PASS     NormalDensity        5/5  PASS
TestNormalPPF               2/2    PASS     NormalProperties     1/1  PASS
TestLogNormal               6/6    PASS     ----------------------------
TestUniform                 7/7    PASS     Total:              13/13  PASS
TestBeta                    5/5    PASS
TestEmpirical               5/5    PASS
TestDistributionABC         2/2    PASS
------------------------------------------
Total:                     44/44   PASS

mypy (strict):   0 errors
ruff:            0 warnings
```

---

## How to Run

### Full pipeline (first time or after code changes)

```bash
cd /home/nison/ProbOs
bash RunAll.sh
```

Runs all 8 steps: requirements check, venv setup, pip install,
pytest, cmake + ninja build, ctest, examples, C++ demo.

### Tests only (fast iteration during development)

```bash
cd /home/nison/ProbOs
bash RunTests.sh
# Runs: pytest + mypy + ruff + ctest in ~30 seconds
```

### Run a specific example

```bash
cd /home/nison/ProbOs

# Week 2: deterministic ODE
.venv/bin/python python/examples/week2_battery_ode.py

# Week 3: Monte Carlo fan plot (N=5000, 300 steps)
.venv/bin/python python/examples/week3_mc_battery.py

# Week 3: CLT convergence verification
.venv/bin/python python/examples/week3_clt_convergence.py

# Week 3: Sobol sensitivity (17,408 evaluations)
.venv/bin/python python/examples/week3_sobol_battery.py
```

### Use the library in your own Python code

```python
import sys
sys.path.insert(0, "/path/to/ProbOs")

from python.src.distributions import Normal, LogNormal, Beta, Uniform, Empirical
import numpy as np

# Create a distribution
Ea = Normal(mu=1.35e5, sigma=5e3)

# Sample 1000 values (reproducible with seed)
rng = np.random.default_rng(seed=42)
samples = Ea.sample(1000, rng=rng)

# Analytical operations
p05 = float(Ea.ppf(np.array([0.05]))[0])     # 5th percentile
log_d = Ea.log_pdf(samples)                   # log-density (never -inf)

print(f"P05: {p05:.0f} J/mol")
print(f"Mean: {Ea.mean():.0f} J/mol")
```

### Compile the research paper

```bash
cd /home/nison/ProbOs/manuscript
make
# Output: main.pdf (11 pages)
```

---

## The Five Distributions

| Class | Support | Typical use | Parameters |
|-------|---------|------------|-----------|
| `Normal(mu, sigma)` | All reals | Symmetric manufacturing variation | mean, std dev |
| `LogNormal(mu, sigma)` | (0, +inf) | Rates, lifetimes, multiplicative noise | log-mean, log-std |
| `Uniform(low, high)` | [low, high] | Unknown parameter within known bounds | lower, upper |
| `Beta(alpha, beta)` | [0, 1] | Proportions, probabilities, binding fractions | shape parameters |
| `Empirical(data)` | [min, max] | Real measured data, no assumed shape | array of observations |

Every distribution exposes the same four operations:

```python
d = Normal(0, 1)          # Standard normal

d.sample(n=1000)          # Draw 1000 independent samples
d.pdf(x)                  # Probability density at x
d.log_pdf(x)              # Analytical log-density (never -inf)
d.ppf(u)                  # Inverse CDF: x such that P(X <= x) = u
d.mean()                  # Analytical mean
d.variance()              # Analytical variance
d.support()               # (lower, upper) bounds
```

---

## Roadmap

```
Year 1 Build Plan
|
+-- Week 1  [COMPLETE]   Distribution ABC
|   +-- Normal, LogNormal, Uniform, Beta, Empirical
|   +-- 44 Python + 13 C++ tests
|   +-- mypy strict + ruff: zero issues
|   +-- Research paper: manuscript/main.pdf
|
+-- Week 2  [COMPLETE]   Model ABC + BatteryModel2Cell
|   +-- Model ABC: state_dim, param_dim, forward_batch
|   +-- BatteryModel2Cell: 8-state Arrhenius ODE, 15 params
|   +-- Kim 2007 ARC validation: onset temp within 5 C
|   +-- 67 new Python tests (111 total)
|
+-- Week 3  [COMPLETE]   Monte Carlo Engine + Sobol + Provenance
|   +-- MonteCarloEngine: P05/P50/P95, sigma/sqrt(N) certificate
|   +-- SobolSensitivity: S1=0.457 for Ea_SEI (dominates T1)
|   +-- ProvenanceTracker: causal DAG, P05 ancestor query
|   +-- 91 new Python tests (202 total)
|   +-- 13-page manuscript
|
+-- Week 4  [NEXT]       GPU/OpenMP + PDSL Compiler
|   +-- OpenMP CPU parallelisation of forward_batch (10x target)
|   +-- PDSL compiler v0.1 (Lark grammar -> AST -> Python codegen)
|   +-- arXiv submission
|   +-- Open-source release v0.1.0
|
+-- Month 2             FastAPI + Particle Filter
|   +-- /simulate, /sensitivity, /provenance endpoints
|   +-- Sequential Monte Carlo particle filter
|   +-- Docker container
|
+-- Month 3             C++ Kernel + pybind11
|   +-- StochasticSystem C++20 concept
|   +-- BatteryCell in C++ satisfying concept
|   +-- pybind11 bindings
|
+-- Month 4             PDSL Compiler + Full Release
|   +-- Probabilistic Domain-Specific Language
|   +-- Compile uncertain programs to Monte Carlo execution plans
|
+-- Year 2+             Full OS Kernel
    +-- Superconductor parameter estimation
    +-- Fusion plasma state tracking
    +-- Quantum gravity uncertainty propagation
```

---

## Research Paper

The Week 1 implementation is documented as a full software paper:

> **ProbOS: A Probabilistic Execution Runtime**
> *Week 1 — Distribution Library: Design, Implementation, and Verification*
> Nisong Monyimba, Reality Computing Corporation, 2026

| Section | Content |
|---------|---------|
| Introduction | Linux analogy, Year 1 roadmap, 5 contributions |
| Mathematical Background | Kolmogorov axioms, log-PDF stability proof (Proposition 1) |
| Architecture | Design principles, TikZ class hierarchy diagram |
| Implementation | Python + C++ listings with annotations |
| Verification | Full pytest + Google Test + mypy + ruff tables |
| Battery Application | Arrhenius equation, embedded figure, percentile table |
| LLN Demonstration | Convergence rate table |
| Reproducibility | One-command checklist |
| Week 2 Roadmap | Model ABC, BatteryModel2Cell plan |

Compile: `cd manuscript && pdflatex main.tex` → `manuscript/main.pdf` (13 pages)

---

## Project Information

| Item | Detail |
|------|--------|
| Author | [AUTHOR NAME] |
| Organisation | Reality Computing Corporation |
| Started | June 2026 |
| License | MIT |
| Languages | Python 3.11 + C++20 |
| Build system | CMake 3.22 + Ninja |
| Platform | Ubuntu 22.04 / WSL2 |
| Repository | https://github.com/NisongMonyimba/ProbOs |

---

## License

MIT License. See [LICENSE](LICENSE) for full terms.

---

<div align="center">

*"Uncertainty is not an obstacle to computation. It is the computation."*

**Reality Computing Corporation — 2026**

</div>
