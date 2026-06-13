# ProbOS — Architecture Document

## The Vision

ProbOS is a **probabilistic execution runtime** — a system where uncertainty
is a first-class type, and every real-world system can be compiled into a
stochastic program that:

1. **SIMULATES** futures — forward Monte Carlo
2. **INFERS** hidden states — particle filter, HMC
3. **CONTROLS** actions under uncertainty — stochastic MPC

## The Linux Analogy (Made Precise)

| Linux concept    | ProbOS concept                                           |
|------------------|----------------------------------------------------------|
| Process          | Stochastic program (distribution over trajectories)     |
| Memory address   | Random variable node in the execution graph              |
| Scheduler        | Inference engine (particle filter)                       |
| System call      | Probabilistic primitive: `sample`, `observe`, `condition` |
| Executable       | Compiled uncertain system                               |
| File             | Probability distribution                               |
| Kernel           | `StochasticSystem` C++20 concept + Monte Carlo engine   |
| Driver           | Domain plugin (battery, pharma, finance)                |
| Shell            | PDSL — the Probabilistic Domain-Specific Language       |

## The Seven Core Abstractions

### 1. Distribution (Week 1) ✅
The fundamental type. Every uncertain quantity is a Distribution instance.

```python
# Python
Ea_SEI = Normal(mu=1.35e5, sigma=5e3)  # J/mol
samples = Ea_SEI.sample(5000)

# C++
probos::distributions::Normal Ea_SEI(1.35e5, 5e3);
double x = Ea_SEI.sample(rng);
```

Classes: `Normal`, `LogNormal`, `Uniform`, `Beta`, `Empirical`
Methods: `sample()`, `pdf()`, `log_pdf()`, `ppf()`

### 2. StochasticSystem (Month 2)
C++20 concept. Any type satisfying:
```cpp
concept StochasticSystem = requires(S s, State x, Ctrl u) {
    { s.drift(x, u) }      -> std::same_as<State>;
    { s.diffusion(x, u) }  -> std::same_as<State>;
    { s.observe(x) }       -> std::same_as<Observation>;
};
```
Battery, drug, market, hospital — all satisfy this one concept.

### 3. ExecutionGraph (Month 3)
A directed acyclic graph (DAG) of random variable nodes.
Records what caused what. Enables causal attribution and regulatory audit trails.

### 4. MonteCarloEngine (Week 3 Python / Month 3 C++)
Vectorised forward simulation. N particles × T time steps.
```python
engine = MonteCarloEngine(model=battery, param_distributions=priors, n_samples=5000)
result = engine.run(t_max=3600, dt=0.5)
```

### 5. ParticleFilter (Month 2)
Sequential Bayesian inference. Observes noisy data, updates beliefs.
```python
pf = ParticleFilter(system=battery, n_particles=1000)
for temp_observation in arc_test_data:
    pf.update(observation=temp_observation)
posterior = pf.get_state_distribution()
```

### 6. SensitivityEngine (Week 4 / Month 3 C++)
Sobol' variance decomposition. Ranks inputs by their contribution to output variance.
```
Ea_SEI:    ST = 0.62  ← dominant (62% of propagation time variance)
A_SEI:     ST = 0.28
k_contact: ST = 0.08  ← negligible
```

### 7. PDSL Compiler (Month 4+)
Domain-specific language. Compiles system descriptions to ExecutionGraphs.
```pdsl
system BatterySafety {
    state  T1: kelvin ~ Normal(403.15, 2.0)
    state  c_SEI: fraction = 1.0
    param  Ea: joules_per_mol ~ Normal(1.35e5, 5e3)
    param  A:  per_second ~ LogNormal(34.05, 0.5)

    evolve T1 with:
        dT1/dt = heat_generation(T1, c_SEI, Ea, A) / thermal_mass
    evolve c_SEI with:
        dc_SEI/dt = -A * c_SEI * exp(-Ea / (R * T1))
}
```

## Repository Structure

```
probos-kernel/
├── python/      Python layer: fast iteration, examples, tests, bindings
│   ├── src/         Core library (distributions, engine, models)
│   ├── tests/       pytest test suite
│   ├── examples/    Runnable demos
│   ├── server/      FastAPI web server (Month 2)
│   ├── dashboard/   Plotly Dash UI (Month 3)
│   └── bindings/    pybind11 Python/C++ interface (Month 2)
├── cpp/         C++ kernel: performance-critical computation
│   ├── include/     Header files (the public API)
│   ├── src/         Implementation files
│   └── tests/       Google Test suite
└── docs/        Architecture and design documents
```

## Build System

| Layer | Tool | Command |
|-------|------|---------|
| Python packages | pip | `pip install -r requirements.txt` |
| Python tests | pytest | `pytest python/tests/ -v` |
| C++ build | CMake + Ninja | `cmake -G Ninja -B build && ninja -C build` |
| C++ tests | ctest | `ctest --output-on-failure` |
| C++ packages (Month 2) | vcpkg | automatic via CMake toolchain |

## Coding Standards

### Python
- All functions and methods have type annotations
- `mypy --strict` passes with zero errors
- `ruff check` passes with zero warnings
- Line length: 88 characters (matches Black)
- Test coverage: minimum 70% (rising to 80% by Month 3)
- Commit messages: Conventional Commits (`feat(scope): description`)

### C++
- Standard: C++20 (required for concepts, used from Month 2)
- Compilers: GCC 13 or Clang 17 (both tested in CI from Month 2)
- `-Wall -Wextra -Wpedantic` enabled
- AddressSanitizer + UBSan in Debug builds
- Google Test for all unit tests
- clang-format for consistent formatting (Month 2)
- Trailing underscore convention for private members: `mu_`, `sigma_`

## Weekly Progress Log

| Week | Files added | Tests | Key achievement |
|------|-------------|-------|-----------------|
| 1    | 14 files    | 26    | Distribution ABC in Python + C++ |
| 2    | TBD         | TBD   | Battery ODE model, CLT demo |
| 3    | TBD         | TBD   | MonteCarloEngine, trajectory cloud |
| 4    | TBD         | TBD   | Sobol' sensitivity, v0.1.0 release |
