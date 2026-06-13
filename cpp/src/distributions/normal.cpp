// =============================================================================
// probos/distributions/normal.cpp
// =============================================================================
//
// WHAT IS THIS FILE?
// ------------------
// This is the IMPLEMENTATION file for the Normal class declared in normal.hpp.
// While normal.hpp says WHAT the class can do, this file says HOW it does it.
//
// The first line must always include the corresponding header.
// This ensures that the implementation matches the declaration — if the
// header changes (e.g. a method signature changes), the compiler immediately
// reports a mismatch here.
// =============================================================================

#include "distributions/normal.hpp"

// We are implementing methods of probos::distributions::Normal.
// Opening the namespace saves typing the full prefix on every method.
namespace probos {
namespace distributions {


// =============================================================================
// Normal::Normal — constructor
// =============================================================================
//
// MEMBER INITIALISER LIST (the : mu_(mu), sigma_(sigma), dist_(mu, sigma) part)
// -------------------------------------------------------------------------------
// In C++, member variables should be initialised in the MEMBER INITIALISER LIST,
// not in the constructor body. This is because:
//   1. It is more efficient — the member is constructed directly rather than
//      default-constructed and then assigned.
//   2. For members without a default constructor (like some STL types), it is
//      the ONLY way to initialise them.
//
// The order of initialisation follows the ORDER OF DECLARATION in the header,
// NOT the order listed here. Our header declares: mu_, sigma_, dist_.
// So they are always initialised in that order regardless of what we write here.
Normal::Normal(double mu, double sigma)
    : mu_(mu)              // initialise mu_ to the parameter mu
    , sigma_(sigma)        // initialise sigma_ to the parameter sigma
    , dist_(mu, sigma)     // initialise the STL distribution with (mu, sigma)
{
    // The constructor BODY runs AFTER all members are initialised.
    // Use it for validation — checks that should throw if parameters are invalid.

    if (sigma <= 0.0) {
        // std::invalid_argument is the right exception type for "you gave me
        // a parameter that makes no mathematical sense".
        // std::to_string converts the double to a string for the error message.
        throw std::invalid_argument(
            "probos::Normal: sigma must be strictly positive, got "
            + std::to_string(sigma)
            + ". A Normal distribution with sigma <= 0 is mathematically "
              "undefined."
        );
    }
}


// =============================================================================
// Normal::sample — draw one random sample
// =============================================================================
double Normal::sample(std::mt19937_64& rng) const {
    // std::normal_distribution<double>::operator()(rng) draws one sample.
    //
    // WHAT ALGORITHM DOES IT USE?
    // The C++ standard does not mandate a specific algorithm, but most
    // implementations use either:
    //   - Box-Muller transform: generates two standard normals from two uniforms
    //     using cos/sin. Simple, but generates two values at once (stores one).
    //   - Ziggurat algorithm: much faster for large batches because it avoids
    //     expensive transcendental functions in most cases.
    //
    // The distribution was initialised with (mu, sigma) in the constructor,
    // so it returns values from Normal(mu, sigma^2) directly.
    return dist_(rng);
}


// =============================================================================
// Normal::pdf — probability density function
// =============================================================================
double Normal::pdf(double x) const noexcept {
    // The Normal PDF formula:
    //
    //   f(x) = (1 / (sigma * sqrt(2*pi))) * exp( -(x-mu)^2 / (2*sigma^2) )
    //
    // We compute it in two steps:
    //   1. z = (x - mu) / sigma  (standardise to N(0,1))
    //   2. f(x) = exp(-z^2/2) / (sigma * sqrt(2*pi))
    //
    // This factoring reduces the number of operations and is slightly more
    // numerically stable than computing (x-mu)^2 / (2*sigma^2) directly.

    const double z = (x - mu_) / sigma_;

    // std::numbers::pi is the C++20 value of pi to full double precision.
    // Before C++20 you would write M_PI (non-standard) or 3.14159265358979323846.
    return std::exp(-0.5 * z * z)
           / (sigma_ * std::sqrt(2.0 * std::numbers::pi));
}


// =============================================================================
// Normal::log_pdf — log probability density (analytical, numerically stable)
// =============================================================================
double Normal::log_pdf(double x) const noexcept {
    // The log-Normal PDF formula:
    //
    //   log f(x) = -0.5 * log(2 * pi * sigma^2) - (x-mu)^2 / (2*sigma^2)
    //
    // Derivation:
    //   Take log of pdf:
    //   log f(x) = log( exp(-z^2/2) / (sigma * sqrt(2*pi)) )
    //            = -z^2/2 - log(sigma * sqrt(2*pi))
    //            = -z^2/2 - log(sigma) - 0.5*log(2*pi)
    //            = -0.5 * (log(2*pi) + log(sigma^2)) - z^2/2
    //            = -0.5 * log(2*pi*sigma^2) - z^2/2
    //
    // Note: we compute log(sigma^2) = 2*log(sigma), not log(sigma*sigma),
    // to avoid a potential overflow in sigma*sigma for very large sigma.

    const double z = (x - mu_) / sigma_;

    // log_normaliser = 0.5 * log(2 * pi * sigma^2)
    // This is the constant part of the log-density (does not depend on x).
    // We could cache it in the constructor for speed, but clarity comes first.
    const double log_normaliser =
        0.5 * std::log(2.0 * std::numbers::pi * sigma_ * sigma_);

    return -log_normaliser - 0.5 * z * z;
}


} // namespace distributions
} // namespace probos
