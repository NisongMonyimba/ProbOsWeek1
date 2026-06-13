# ProbOS — Probabilistic Operating System

> **"Linux manages deterministic computation. ProbOS manages stochastic computation."**

A probabilistic execution runtime where **uncertainty is a first-class type**.
Every real-world system — a battery, a drug, a market, a hospital — compiles
into a stochastic program that can simulate futures, infer hidden states, and
choose optimal actions.

---

## The Vision

| Linux concept    | ProbOS concept                                          |
|------------------|---------------------------------------------------------|
| Process          | Stochastic program (a distribution over trajectories)  |
| Memory address   | A random variable node in the execution graph           |
| Scheduler        | Inference engine (particle filter / HMC)                |
| System call      | Probabilistic primitive: `sample`, `observe`, `condition` |
| Executable       | A compiled uncertain system                             |
| File             | A probability distribution                             |
| Kernel           | `StochasticSystem` C++20 concept + Monte Carlo engine   |

---

## Week 1 Status

**What is built this week:**
- `python/src/distributions.py` — the Distribution ABC with Normal, LogNormal,
  Uniform, Beta, and Empirical classes. The fundamental type of ProbOS.
- `python/tests/test_distributions.py` — 17 pytest tests verifying mathematical
  properties (not just "does it run").
- `python/examples/` — two runnable demos.
- `cpp/include/distributions/normal.hpp` — C++ Normal class.
- `cpp/src/distributions/normal.cpp` — implementation.
- `cpp/tests/test_normal.cpp` — 9 Google Test cases.
- `cpp/src/main.cpp` — C++ demo.
- `scripts/RunAll.sh` — runs everything: installs deps, runs Python tests,
  builds C++, runs C++ tests, runs all examples.
- `scripts/RunTests.sh` — test-only runner with clear PASS/FAIL output.

**All tests passing: 17 Python (pytest) + 9 C++ (Google Test) = 26 total.**

---

## Quick Start (one command)

```bash
chmod +x scripts/RunAll.sh
./scripts/RunAll.sh
```

This single script installs all Python dependencies, builds the C++ code,
runs all tests, and runs all examples. Every step prints a clear
SUCCESS or FAILURE message.

---

## Manual Setup

```bash
# Python setup
python3 -m venv .venv
source .venv/bin/activate        # Linux / macOS
# .venv\Scripts\Activate.ps1     # Windows PowerShell
pip install -r requirements.txt

# Run Python tests
pytest python/tests/ -v

# Run Python examples
python python/examples/week1_coin_flip.py
python python/examples/week1_normal_demo.py

# C++ build (requires GCC or Clang with C++17+, CMake 3.16+, Ninja)
mkdir -p build && cd build
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Debug
ninja
./probos_main
ctest --output-on-failure
```

---

## Repository Structure

```
probos-week1/
├── README.md                   This file
├── LICENSE                     Apache 2.0
├── .gitignore                  Files Git should ignore
├── pyproject.toml              Python project config (mypy, ruff, pytest)
├── requirements.txt            Python dependencies
├── CMakeLists.txt              Top-level CMake (delegates to cpp/)
│
├── python/
│   ├── src/
│   │   └── distributions.py   Distribution ABC + 5 concrete classes
│   ├── tests/
│   │   └── test_distributions.py   17 mathematical property tests
│   └── examples/
│       ├── week1_coin_flip.py      Law of Large Numbers demo
│       └── week1_normal_demo.py    Battery Ea_SEI sampling demo
│
├── cpp/
│   ├── CMakeLists.txt          C++ build configuration
│   ├── include/distributions/
│   │   └── normal.hpp          C++ Normal class declaration
│   ├── src/
│   │   ├── distributions/
│   │   │   └── normal.cpp      C++ Normal implementation
│   │   └── main.cpp            C++ demo program
│   └── tests/
│       └── test_normal.cpp     9 Google Test cases
│
├── docs/
│   └── architecture.md         System design document
│
└── scripts/
    ├── RunAll.sh               Master runner: install + build + test + demo
    └── RunTests.sh             Test-only runner with PASS/FAIL output
```

---

## Weekly Progress

| Week | What was added                                          |
|------|---------------------------------------------------------|
| 1    | Distribution ABC (Python + C++), CMake, 26 tests ✅     |
| 2    | Battery ODE model, CLT demo, Model ABC *(coming)*       |
| 3    | MonteCarloEngine, trajectory cloud *(coming)*           |
| 4    | Sobol' sensitivity, parameter priors, v0.1.0 *(coming)* |

---

## License

Apache 2.0 — see [LICENSE](LICENSE)
