#pragma once
// =============================================================================
// probos/distributions/normal.hpp
// =============================================================================
//
// The Normal (Gaussian) distribution — the first C++ type in ProbOS.
//
// WHAT IS THIS FILE?
// ------------------
// A header file (.hpp) declares WHAT a class looks like: its name, its member
// variables, and the signatures of its methods. It does NOT contain the actual
// implementation of those methods (that goes in normal.cpp).
//
// WHY SEPARATE HEADER AND IMPLEMENTATION?
// ----------------------------------------
// When you #include "distributions/normal.hpp" in 10 different files, the
// compiler only needs to parse the lightweight header. The implementation
// in normal.cpp is compiled once and linked in at the end. This dramatically
// speeds up compilation in large projects.
//
// THE #pragma once DIRECTIVE
// ---------------------------
// Prevents the header from being included more than once in the same
// translation unit. Without this, you would get "redefinition" errors if
// two files both include this header. It replaces the older include-guard
// pattern:
//   #ifndef PROBOS_DISTRIBUTIONS_NORMAL_HPP
//   #define PROBOS_DISTRIBUTIONS_NORMAL_HPP
//   ...
//   #endif
//
// WHY C++ AND NOT JUST PYTHON?
// -----------------------------
// Python is fast to write but slow to run. A Monte Carlo simulation with
// 10,000 particles and 10,000 time steps (100 million iterations) runs in
// ~80 seconds in Python. The same simulation in C++ runs in ~0.8 seconds.
// We write the prototype in Python (quick to experiment), then translate
// the inner loop to C++ (fast to run).
//
// THE FUTURE OF THIS CLASS
// -------------------------
// In Month 2 this class will become a template:  Normal<T>
// When T = double, it is a fast forward simulator.
// When T = dual<double> (a dual number for automatic differentiation),
// the same code computes gradients for free — enabling HMC inference.
// We keep it non-templated for now for clarity.
// =============================================================================

// Standard library includes
// <cmath>   : std::exp, std::sqrt, std::log
// <random>  : std::normal_distribution, std::mt19937_64
// <stdexcept>: std::invalid_argument (for the sigma <= 0 check)
// <string>  : std::to_string (for the error message)
// <numbers> : std::numbers::pi (C++20 — the value of pi to full precision)
#include <cmath>
#include <random>
#include <stdexcept>
#include <string>
#include <numbers>

// NAMESPACE ORGANISATION
// -----------------------
// We use nested namespaces to avoid name collisions with other libraries.
// All ProbOS code lives in the `probos` namespace.
// Distributions specifically live in `probos::distributions`.
//
// Usage:
//   probos::distributions::Normal d(0.0, 1.0);
//
// Or with a using declaration:
//   using probos::distributions::Normal;
//   Normal d(0.0, 1.0);
namespace probos {
namespace distributions {

// =============================================================================
// class Normal
// =============================================================================
class Normal {
public:
    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================

    // explicit keyword: prevents accidental implicit conversions.
    // Without explicit: Normal d = 5.0;  would compile (with mu=5.0, sigma??).
    // With explicit:    Normal d = 5.0;  is a compile error.
    //
    // Parameters:
    //   mu    (double) : the mean of the distribution
    //   sigma (double) : the standard deviation (MUST be > 0)
    //
    // Throws: std::invalid_argument if sigma <= 0
    explicit Normal(double mu, double sigma);


    // =========================================================================
    // SAMPLING
    // =========================================================================

    // Draw ONE sample from Normal(mu, sigma^2).
    //
    // WHY PASS THE RNG BY REFERENCE?
    // --------------------------------
    // The random number generator (RNG) has internal state that advances
    // each time you draw a sample. By passing it by reference, we:
    //   1. Allow the CALLER to own and manage the RNG.
    //   2. Enable reproducibility: the caller seeds the RNG once and reuses
    //      it across many calls, producing a deterministic stream.
    //   3. Enable parallel safety: each thread can have its OWN RNG with a
    //      different seed — no shared mutable state, no data races.
    //
    // std::mt19937_64:
    //   The Mersenne Twister with a 64-bit state. It is the standard RNG
    //   for scientific computing in C++. It is NOT cryptographically secure,
    //   but it passes all statistical tests and is very fast.
    //
    // Example usage:
    //   std::mt19937_64 rng(42);   // seed = 42
    //   Normal n(0.0, 1.0);
    //   double x = n.sample(rng);  // x is a draw from N(0,1)
    //   double y = n.sample(rng);  // y is the NEXT draw from the same stream
    double sample(std::mt19937_64& rng) const;


    // =========================================================================
    // DENSITY EVALUATION
    // =========================================================================

    // Probability density function (PDF):
    //
    //   f(x) = exp( -(x-mu)^2 / (2*sigma^2) ) / (sigma * sqrt(2*pi))
    //
    // This is the height of the bell curve at point x.
    // It is NOT a probability — it is a density. For a continuous distribution
    // P(X = x) = 0 for any specific x; only P(a <= X <= b) makes sense.
    //
    // [[nodiscard]] : the compiler warns if you call pdf(x) but ignore the
    //                 return value. This catches bugs like writing pdf(x) when
    //                 you meant to write log_pdf(x).
    //
    // noexcept : promises to the compiler and callers that this function will
    //            never throw an exception. This allows the compiler to optimise
    //            call sites more aggressively.
    [[nodiscard]] double pdf(double x) const noexcept;


    // Log probability density function:
    //
    //   log f(x) = -0.5 * log(2*pi*sigma^2) - (x-mu)^2 / (2*sigma^2)
    //
    // CRITICAL: THIS IS NOT std::log(pdf(x))
    // ----------------------------------------
    // When x is very far from mu (e.g. x = mu + 50*sigma), pdf(x) is so
    // small that it rounds to 0.0 in floating point (underflow). Then
    // std::log(0.0) = -infinity, and the Bayesian computation collapses.
    //
    // The analytical form above stays numerically finite for any finite x,
    // because we never compute the tiny exponential — we stay in log-space.
    //
    // THIS DIFFERENCE KILLS REAL INFERENCE RUNS. Always use log_pdf.
    [[nodiscard]] double log_pdf(double x) const noexcept;


    // =========================================================================
    // ACCESSORS (read-only properties)
    // =========================================================================

    // [[nodiscard]] : warn if the return value is ignored.
    // noexcept      : these are simple member variable reads; they never throw.

    [[nodiscard]] double mu()    const noexcept { return mu_; }
    [[nodiscard]] double sigma() const noexcept { return sigma_; }
    [[nodiscard]] double mean()  const noexcept { return mu_; }
    [[nodiscard]] double var()   const noexcept { return sigma_ * sigma_; }
    [[nodiscard]] double std()   const noexcept { return sigma_; }


private:
    // =========================================================================
    // PRIVATE MEMBER VARIABLES
    // =========================================================================

    // Trailing underscore convention: private member variables end in _.
    // This distinguishes them from local variables and parameters at a glance.

    double mu_;      // mean of the distribution
    double sigma_;   // standard deviation

    // std::normal_distribution<double> is the STL implementation of the
    // Gaussian distribution. It is parameterised by (mu, sigma).
    //
    // WHY mutable?
    // std::normal_distribution::operator() modifies the distribution's
    // internal state (some algorithms store a cached value between calls for
    // efficiency). This makes operator() non-const. But sample() is logically
    // const (calling it does not change the distribution's parameters). The
    // mutable keyword says "this field can be modified even in a const method".
    mutable std::normal_distribution<double> dist_;
};

} // namespace distributions
} // namespace probos
