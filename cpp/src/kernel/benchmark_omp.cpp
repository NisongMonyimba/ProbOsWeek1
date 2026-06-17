// =============================================================================
// cpp/src/kernel/benchmark_omp.cpp
// ProbOS Week 4 -- OpenMP vs Serial benchmark
//
// Measures wall time for N particles x n_steps forward steps.
// Prints speedup table: Python baseline vs C++ serial vs C++ OpenMP.
//
// Usage: ./benchmark_omp
// =============================================================================

#include <iostream>
#include <iomanip>
#include <vector>
#include <chrono>
#include "kernel/monte_carlo_omp.hpp"

#ifdef _OPENMP
#include <omp.h>
#endif

using namespace probos::kernel;

int main() {
    std::cout << std::string(70, '=') << "\n";
    std::cout << "  ProbOS Week 4 -- OpenMP Monte Carlo Benchmark\n";

#ifdef _OPENMP
    std::cout << "  OpenMP: ENABLED  max_threads=" << omp_get_max_threads() << "\n";
#else
    std::cout << "  OpenMP: DISABLED (serial fallback)\n";
#endif
    std::cout << std::string(70, '=') << "\n\n";

    struct BenchCase {
        int    N;
        int    n_steps;
        double python_ms;   // measured Python time
    };

    std::vector<BenchCase> cases = {
        {   5000,  300,  390.0},   // standard Week 3 run
        {  10000,  300,  780.0},   // 2x particles
        {  50000,  300, 3900.0},   // 10x particles
        { 100000,  300, 7800.0},   // 20x particles
    };

    // Header
    std::cout << std::left
              << std::setw(10) << "N"
              << std::setw(10) << "n_steps"
              << std::setw(14) << "C++ 1-thread"
              << std::setw(14) << "C++ OpenMP"
              << std::setw(12) << "OMP vs 1T"
              << std::setw(14) << "vs Python"
              << "\n";
    std::cout << std::string(74, '-') << "\n";

    for (const auto& c : cases) {

        // Serial (1 thread)
        MonteCarloEngineOMP serial_eng(c.N, c.n_steps, 1.0, 1);
        MCResult serial_res = serial_eng.run(42);

        // OpenMP (all threads)
        MonteCarloEngineOMP omp_eng(c.N, c.n_steps, 1.0, 0);
        // warm-up
        omp_eng.run(42);
        // timed run
        MCResult omp_res = omp_eng.run(42);

        double serial_ms  = serial_res.wall_time_ms;
        double omp_ms     = omp_res.wall_time_ms;
        double speedup_omp_vs_serial  = serial_ms / omp_ms;
        double speedup_vs_python      = c.python_ms / omp_ms;

        std::cout << std::left
                  << std::setw(10) << c.N
                  << std::setw(10) << c.n_steps
                  << std::setw(14) << std::fixed << std::setprecision(1)
                  << serial_ms
                  << std::setw(14) << omp_ms
                  << std::setw(12) << std::setprecision(2)
                  << speedup_omp_vs_serial << "x"
                  << std::setw(14) << std::setprecision(1)
                  << speedup_vs_python << "x (vs Python)"
                  << "\n";
    }

    std::cout << std::string(74, '=') << "\n";
    std::cout << "  Times in milliseconds. Python baseline measured at N=5000, n_steps=300.\n";
    std::cout << std::string(74, '=') << "\n";

    return 0;
}
