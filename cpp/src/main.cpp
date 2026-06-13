// =============================================================================
// cpp/src/main.cpp — ProbOS Week 1 Demo Program
// =============================================================================
//
// This is the entry point of the C++ demo. Every C++ program must have
// exactly one function named main(). The operating system calls main() when
// you run the executable.
//
// WHAT THIS FILE DOES:
//   Demonstrates the C++ Normal distribution class by simulating the
//   uncertainty in a lithium-ion battery's SEI activation energy, a key
//   parameter that determines when thermal runaway begins.
//
// THIS FILE GROWS EVERY WEEK:
//   Week 1: Normal distribution demo (this file)
//   Week 2: Add BatteryCell ODE simulation
//   Week 3: Add MonteCarloEngine demo
//   Week 4: Add sensitivity analysis demo
//
// HOW TO BUILD AND RUN:
//   cd build
//   cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Debug
//   ninja
//   ./probos_main
// =============================================================================

// Standard library includes — these are always available without installation.
#include <iostream>    // std::cout, std::endl — for printing to the terminal
#include <iomanip>     // std::fixed, std::setprecision — for number formatting
#include <random>      // std::mt19937_64, std::random_device
#include <vector>      // std::vector<double>
#include <numeric>     // std::accumulate (sum of elements)
#include <cmath>       // std::sqrt, std::abs
#include <algorithm>   // std::sort (for computing percentiles)
#include <string>      // std::string

// Our own library — the Normal distribution from this project.
// The path is relative to the include directory set in cpp/CMakeLists.txt.
#include "distributions/normal.hpp"

// =============================================================================
// HELPER FUNCTION: compute_statistics
// =============================================================================
// Computes basic summary statistics from a vector of doubles.
//
// In C++, it is good practice to put helper functions BEFORE main(), or
// to declare them before main() and define them after (using a declaration).
// We put it before main() for simplicity here.

struct Statistics {
    // A struct is a simple container for related values.
    // Unlike a class, all members of a struct are public by default.
    double mean;
    double std_dev;
    double p05;    // 5th percentile (5% of samples are below this value)
    double p50;    // 50th percentile (median)
    double p95;    // 95th percentile (95% of samples are below this value)
    double minimum;
    double maximum;
};

Statistics compute_statistics(std::vector<double> samples) {
    // NOTE: 'samples' is passed BY VALUE (a copy is made).
    // This is intentional because we will sort it to find percentiles,
    // and we do not want to modify the caller's vector.

    const int n = static_cast<int>(samples.size());
    if (n == 0) {
        return {0, 0, 0, 0, 0, 0, 0};
    }

    // Compute mean using std::accumulate.
    // std::accumulate(begin, end, initial_value) sums all elements.
    double sum  = std::accumulate(samples.begin(), samples.end(), 0.0);
    double mean = sum / n;

    // Compute variance: E[(X - mu)^2] using Bessel's correction (n-1).
    // Bessel's correction (dividing by n-1 instead of n) makes the sample
    // variance an unbiased estimator of the population variance.
    double var = 0.0;
    for (double x : samples) {
        double diff = x - mean;
        var += diff * diff;
    }
    var /= (n - 1);

    // Sort in place to compute percentiles.
    // After sorting: samples[0] is the minimum, samples[n-1] is the maximum.
    std::sort(samples.begin(), samples.end());

    // Compute percentiles by indexing into the sorted array.
    // For the 5th percentile: we want the value at position 5% of the way
    // through the sorted array. static_cast<size_t>(...) converts double
    // index to integer index (truncating, not rounding).
    return {
        mean,
        std::sqrt(var),
        samples[static_cast<size_t>(0.05 * n)],   // P05
        samples[static_cast<size_t>(0.50 * n)],   // P50 (median)
        samples[static_cast<size_t>(0.95 * n)],   // P95
        samples.front(),                            // minimum
        samples.back(),                             // maximum
    };
}

// =============================================================================
// HELPER FUNCTION: print_separator
// =============================================================================
void print_separator(char c = '=', int width = 60) {
    std::cout << std::string(width, c) << "\n";
}

// =============================================================================
// main() — the program entry point
// =============================================================================
int main() {
    // std::fixed and std::setprecision(4) set the number format for std::cout.
    // After this line, all floating-point numbers are printed with 4 decimal
    // places in fixed-point notation (not scientific notation like 1.35e+05).
    std::cout << std::fixed << std::setprecision(4);

    print_separator('=');
    std::cout << "  ProbOS Kernel v0.0.1 — Week 1 Demo\n";
    std::cout << "  C++ Normal Distribution: Battery Parameter Sampling\n";
    print_separator('=');
    std::cout << "\n";

    // =========================================================================
    // DEMO 1: The SEI activation energy
    // =========================================================================
    // The SEI (solid-electrolyte interphase) decomposition activation energy
    // Ea_SEI governs how fast the battery's protective layer breaks down.
    // It is the DOMINANT source of uncertainty in thermal runaway propagation
    // time (Sobol' total-effect index ST ≈ 0.62, from Kim 2007).
    //
    // Value from Kim et al. (2007), J. Electrochem. Soc. 154(12), A1029:
    //   Mean Ea_SEI = 135,080 J/mol
    //   Std Ea_SEI  =   5,000 J/mol (±3.7% coefficient of variation)
    //
    // This uncertainty comes from manufacturing variability: different
    // electrode coating processes produce slightly different SEI layers.

    using probos::distributions::Normal;  // avoid typing the full namespace

    Normal Ea_SEI(1.3508e5, 5.0e3);

    std::cout << "Battery SEI activation energy:\n";
    std::cout << "  Distribution: Normal(mu = " << Ea_SEI.mu()
              << ", sigma = " << Ea_SEI.sigma() << ") J/mol\n";
    std::cout << "  Mean:         " << Ea_SEI.mean() << " J/mol\n";
    std::cout << "  Variance:     " << Ea_SEI.var()  << " J^2/mol^2\n";
    std::cout << "  Std dev:      " << Ea_SEI.std()  << " J/mol\n\n";

    // =========================================================================
    // DEMO 2: Monte Carlo sampling — simulating a manufacturing batch
    // =========================================================================
    // We draw N = 10,000 samples to simulate the activation energies of
    // 10,000 batteries coming off a manufacturing line.
    //
    // The RNG is seeded with 42. Using a fixed seed makes the output
    // REPRODUCIBLE — running this program again gives exactly the same numbers.
    // This is critical for scientific reproducibility and debugging.

    std::mt19937_64 rng(42);   // seed = 42

    const int N = 10'000;      // C++14 digit separator: 10'000 = 10000

    std::cout << "Simulating " << N << " batteries...\n";
    std::vector<double> samples(N);
    for (int i = 0; i < N; ++i) {
        samples[i] = Ea_SEI.sample(rng);
    }
    std::cout << "Done.\n\n";

    // Compute and display statistics
    Statistics s = compute_statistics(samples);

    print_separator('-');
    std::cout << "  Empirical statistics (N = " << N << ")\n";
    print_separator('-');
    std::cout << "  Mean:         " << s.mean
              << "  (true: " << Ea_SEI.mean() << ")\n";
    std::cout << "  Std dev:      " << s.std_dev
              << "  (true: " << Ea_SEI.std()  << ")\n";
    std::cout << "  Minimum:      " << s.minimum << "\n";
    std::cout << "  5th pctile:   " << s.p05     << "  (batteries with LOW Ea)\n";
    std::cout << "  Median:       " << s.p50     << "\n";
    std::cout << "  95th pctile:  " << s.p95     << "  (batteries with HIGH Ea)\n";
    std::cout << "  Maximum:      " << s.maximum  << "\n\n";

    // =========================================================================
    // DEMO 3: Density evaluation
    // =========================================================================
    // Demonstrate pdf() and log_pdf() at a few key points.

    print_separator('-');
    std::cout << "  Density evaluation\n";
    print_separator('-');

    struct DensityPoint { double offset_sigma; std::string label; };
    std::vector<DensityPoint> points = {
        {-3.0, "mu - 3*sigma"},
        {-1.0, "mu - 1*sigma"},
        { 0.0, "mu (mean)   "},
        {+1.0, "mu + 1*sigma"},
        {+3.0, "mu + 3*sigma"},
    };

    std::cout << "  Point              pdf(x)        log_pdf(x)\n";
    for (const auto& pt : points) {
        double x = Ea_SEI.mu() + pt.offset_sigma * Ea_SEI.sigma();
        std::cout << "  " << pt.label
                  << "  " << std::setw(12) << Ea_SEI.pdf(x)
                  << "  " << std::setw(12) << Ea_SEI.log_pdf(x) << "\n";
    }
    std::cout << "\n";

    // =========================================================================
    // DEMO 4: Numerical stability of log_pdf at extreme values
    // =========================================================================
    // This demonstrates WHY log_pdf must be analytical, not log(pdf(x)).

    print_separator('-');
    std::cout << "  log_pdf stability at extreme values\n";
    print_separator('-');

    double x_extreme = Ea_SEI.mu() + 50.0 * Ea_SEI.sigma();  // 50 sigma away!

    double pdf_val    = Ea_SEI.pdf(x_extreme);
    double logpdf_val = Ea_SEI.log_pdf(x_extreme);
    double log_of_pdf = (pdf_val > 0.0) ? std::log(pdf_val) : -std::numeric_limits<double>::infinity();

    std::cout << "  x = mu + 50*sigma = " << x_extreme << " J/mol\n";
    std::cout << "\n";
    std::cout << "  pdf(x):          " << pdf_val    << "  (UNDERFLOWS TO 0)\n";
    std::cout << "  log(pdf(x)):     " << log_of_pdf << "  (WRONG: -infinity!)\n";
    std::cout << "  log_pdf(x):      " << logpdf_val << "  (CORRECT: finite)\n";
    std::cout << "\n";
    std::cout << "  Conclusion: ALWAYS use log_pdf in Bayesian inference.\n";
    std::cout << "  Using log(pdf(x)) would crash any inference algorithm.\n\n";

    // =========================================================================
    // DEMO 5: The physical insight
    // =========================================================================

    print_separator('-');
    std::cout << "  Physical insight: why ProbOS exists\n";
    print_separator('-');
    std::cout << "\n";
    std::cout << "  The 5th-percentile battery has Ea_SEI = " << s.p05 << " J/mol\n";
    std::cout << "  The mean battery has            Ea_SEI = " << s.p50 << " J/mol\n";
    std::cout << "  Difference: " << s.p50 - s.p05 << " J/mol\n\n";
    std::cout << "  A battery with LOW Ea_SEI decomposes FASTER.\n";
    std::cout << "  The Arrhenius rate: k = A * exp(-Ea / (R*T))\n";
    std::cout << "  Lower Ea = higher k = faster heat generation.\n\n";
    std::cout << "  A deterministic model uses only the MEAN Ea_SEI.\n";
    std::cout << "  It has NO IDEA the P05 battery even exists.\n";
    std::cout << "  ProbOS simulates ALL 10,000 batteries simultaneously\n";
    std::cout << "  and finds the dangerous tail — before anyone gets hurt.\n\n";

    print_separator('=');
    std::cout << "  Week 1 C++ demo complete. All systems nominal.\n";
    print_separator('=');
    std::cout << "\n";

    // main() returns 0 to signal success to the operating system.
    // A non-zero return value signals an error (convention: 1 = general error).
    return 0;
}
