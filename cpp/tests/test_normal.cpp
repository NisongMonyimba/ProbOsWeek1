// =============================================================================
// cpp/tests/test_normal.cpp — Google Test suite for probos::Normal
// =============================================================================
//
// WHAT IS GOOGLE TEST?
// --------------------
// Google Test (gtest) is the most widely-used C++ testing framework.
// It provides:
//   TEST(TestSuiteName, TestName) { ... }  — defines a test case
//   EXPECT_EQ(a, b)     — fails if a != b (test continues)
//   EXPECT_NEAR(a, b, tolerance) — fails if |a-b| > tolerance
//   EXPECT_THROW(expr, ExceptionType) — fails if expr does NOT throw
//   ASSERT_*            — like EXPECT_* but stops the test immediately on fail
//
// TESTING PHILOSOPHY:
// -------------------
// We test MATHEMATICAL PROPERTIES, not just "does it run without crashing".
// A test like "sample() returns something" tells us nothing useful.
// A test like "the empirical mean of 100,000 samples is within 3 sigma/sqrt(N)
// of the true mean" tests the Law of Large Numbers — a real mathematical claim.
//
// HOW TO RUN:
//   cd build && ctest --output-on-failure -V
//   OR: ./build/bin/test_normal --gtest_color=yes
// =============================================================================

// Google Test header — provides TEST(), EXPECT_*, ASSERT_*, etc.
#include <gtest/gtest.h>

// Standard library
#include <random>
#include <vector>
#include <numeric>
#include <cmath>
#include <stdexcept>
#include <limits>

// Our distribution under test
#include "distributions/normal.hpp"

// Bring the class into scope so we don't type the full namespace everywhere.
using probos::distributions::Normal;


// =============================================================================
// TEST SUITE: NormalConstructor
// Tests that the constructor behaves correctly.
// =============================================================================

TEST(NormalConstructor, ValidParametersDoNotThrow) {
    // Verify that valid inputs do NOT throw an exception.
    // EXPECT_NO_THROW runs the code and fails if it throws anything.
    EXPECT_NO_THROW(Normal(0.0,    1.0));     // standard normal
    EXPECT_NO_THROW(Normal(-100.0, 0.001));   // small sigma, negative mu
    EXPECT_NO_THROW(Normal(1e6,    1e4));     // large values (battery Ea range)
}

TEST(NormalConstructor, NegativeSigmaThrows) {
    // Verify that sigma <= 0 throws std::invalid_argument.
    // A Normal distribution with sigma <= 0 is mathematically undefined.
    EXPECT_THROW(Normal(0.0, -1.0),  std::invalid_argument);
    EXPECT_THROW(Normal(0.0, -0.001), std::invalid_argument);
}

TEST(NormalConstructor, ZeroSigmaThrows) {
    EXPECT_THROW(Normal(0.0, 0.0), std::invalid_argument);
}

TEST(NormalConstructor, AccessorsMatchConstructorArguments) {
    // After construction, mu() and sigma() must return what we passed in.
    // EXPECT_DOUBLE_EQ checks for exact equality of two doubles.
    // For values that are exact floating-point representations (like 3.7),
    // this is appropriate. For computed values, use EXPECT_NEAR with a tolerance.
    Normal d(3.7, 1.2);
    EXPECT_DOUBLE_EQ(d.mu(),    3.7);
    EXPECT_DOUBLE_EQ(d.sigma(), 1.2);
    EXPECT_DOUBLE_EQ(d.mean(),  3.7);
    EXPECT_DOUBLE_EQ(d.var(),   1.2 * 1.2);
    EXPECT_DOUBLE_EQ(d.std(),   1.2);
}


// =============================================================================
// TEST SUITE: NormalSampling
// Tests that the sampling behaviour is statistically correct.
// =============================================================================

TEST(NormalSampling, EmpiricalMeanConvergesToMu) {
    // LAW OF LARGE NUMBERS:
    // The sample mean x_bar of N iid samples converges to the true mean mu.
    // The error |x_bar - mu| is bounded (with high probability) by:
    //   3 * sigma / sqrt(N)
    // This is the "3-sigma rule" for the sample mean.
    //
    // With N = 100,000 and sigma = 2.0:
    //   tolerance = 3 * 2.0 / sqrt(100000) = 0.019
    // So the empirical mean must be within 0.019 of 5.0.

    Normal d(5.0, 2.0);
    std::mt19937_64 rng(42);

    const int N = 100'000;
    double sum = 0.0;
    for (int i = 0; i < N; ++i) {
        sum += d.sample(rng);
    }
    double empirical_mean = sum / N;

    double tolerance = 3.0 * 2.0 / std::sqrt(static_cast<double>(N));
    EXPECT_NEAR(empirical_mean, 5.0, tolerance)
        << "Empirical mean should be within " << tolerance
        << " of true mean 5.0 (3-sigma LLN bound)";
}

TEST(NormalSampling, EmpiricalStdConvergesToSigma) {
    // CENTRAL LIMIT THEOREM:
    // The sample standard deviation also converges to sigma.
    // We use a tolerance of 0.05 (5% of sigma = 3.0).

    Normal d(0.0, 3.0);
    std::mt19937_64 rng(7);

    const int N = 100'000;
    std::vector<double> s(N);
    for (int i = 0; i < N; ++i) s[i] = d.sample(rng);

    double mean = std::accumulate(s.begin(), s.end(), 0.0) / N;
    double var  = 0.0;
    for (double x : s) var += (x - mean) * (x - mean);
    var /= (N - 1);  // Bessel's correction

    EXPECT_NEAR(std::sqrt(var), 3.0, 0.05)
        << "Empirical std should be close to true sigma = 3.0";
}

TEST(NormalSampling, SameSeedProducesSameSequence) {
    // Reproducibility test: same seed -> same sample sequence.
    //
    // IMPORTANT: we use two separate mt19937_64 objects with the same
    // seed, and a SINGLE Normal object reset between runs via its
    // reset() method. std::normal_distribution caches one value
    // internally (Box-Muller generates pairs). Calling dist_.reset()
    // discards that cache so both runs start from identical state.
    Normal d(0.0, 1.0);

    // Run 1: seed 99
    std::mt19937_64 rng1(99);
    std::vector<double> run1(50);
    for (int i = 0; i < 50; ++i) run1[i] = d.sample(rng1);

    // Reset the distribution internal cache, then run again with same seed
    d = Normal(0.0, 1.0);  // fresh object = empty cache
    std::mt19937_64 rng2(99);  // same seed
    for (int i = 0; i < 50; ++i) {
        double x2 = d.sample(rng2);
        EXPECT_DOUBLE_EQ(run1[i], x2)
            << "Sample " << i << " differs between two runs with same seed";
    }
}


// =============================================================================
// TEST SUITE: NormalDensity
// Tests that the pdf and log_pdf are mathematically correct.
// =============================================================================

TEST(NormalDensity, PdfIsPositiveOnEntireRealLine) {
    // The Normal distribution has support on all of R.
    // The PDF must be positive (strictly > 0) everywhere.
    Normal d(0.0, 1.0);

    for (double x = -10.0; x <= 10.0; x += 0.5) {
        EXPECT_GT(d.pdf(x), 0.0)
            << "pdf should be positive at x = " << x;
    }
}

TEST(NormalDensity, PdfIsMaximumAtMean) {
    // The Normal PDF has its maximum at x = mu.
    // For any x != mu, pdf(x) < pdf(mu).
    Normal d(2.0, 1.5);
    double peak = d.pdf(d.mu());

    for (double offset : {0.5, 1.0, 2.0, 3.0, 5.0}) {
        EXPECT_GT(peak, d.pdf(d.mu() + offset))
            << "pdf(mu) should exceed pdf(mu + " << offset << ")";
        EXPECT_GT(peak, d.pdf(d.mu() - offset))
            << "pdf(mu) should exceed pdf(mu - " << offset << ")";
    }
}

TEST(NormalDensity, PdfIsSymmetricAroundMean) {
    // The Normal PDF is symmetric: f(mu + d) = f(mu - d) for all d.
    Normal n(3.0, 2.0);

    for (double offset : {0.1, 0.5, 1.0, 2.0, 3.0}) {
        double above = n.pdf(n.mu() + offset);
        double below = n.pdf(n.mu() - offset);
        EXPECT_NEAR(above, below, 1e-15)
            << "pdf should be symmetric: f(mu+" << offset
            << ") should equal f(mu-" << offset << ")";
    }
}

TEST(NormalDensity, LogPdfIsConsistentWithPdf) {
    // MATHEMATICAL CONSISTENCY:
    // exp(log_pdf(x)) must equal pdf(x) to machine precision.
    // This verifies that the analytical log_pdf formula is correct.
    //
    // EXPECT_NEAR with tolerance 1e-12 is appropriate for double precision:
    // the machine epsilon (smallest representable difference) is ~2.2e-16.
    // We allow 1e-12 to account for rounding in the exp() computation.

    Normal d(1.0, 2.0);

    for (double x = -6.0; x <= 8.0; x += 0.5) {
        double via_log = std::exp(d.log_pdf(x));
        double direct  = d.pdf(x);
        EXPECT_NEAR(via_log, direct, 1e-12)
            << "exp(log_pdf(x)) should equal pdf(x) at x = " << x;
    }
}

TEST(NormalDensity, LogPdfRemainsFiniteAtExtremeValues) {
    // NUMERICAL STABILITY (the critical test):
    // When x is far from mu, pdf(x) underflows to 0.0.
    // But log_pdf(x) must remain a finite (large negative) number.
    //
    // If log_pdf just computed std::log(pdf(x)), it would return -infinity.
    // This test verifies that our analytical implementation avoids this.

    Normal d(0.0, 1.0);

    // x = 50 standard deviations from the mean
    // pdf(50) = exp(-50^2/2) / sqrt(2*pi) ≈ exp(-1250) ≈ 10^{-543}
    // This is FAR below double's minimum positive value (~2.2e-308).
    // So pdf(50) should underflow to exactly 0.0.
    double x_extreme = 50.0;

    double pdf_val    = d.pdf(x_extreme);
    double logpdf_val = d.log_pdf(x_extreme);

    // Verify pdf underflows (this is EXPECTED behaviour)
    EXPECT_EQ(pdf_val, 0.0)
        << "pdf(50) should underflow to 0.0";

    // Verify log_pdf is finite (this is what we are TESTING for)
    EXPECT_TRUE(std::isfinite(logpdf_val))
        << "log_pdf(50) should be finite, not -infinity. "
        << "Got: " << logpdf_val;

    // Verify log_pdf is a large negative number (sanity check)
    EXPECT_LT(logpdf_val, -100.0)
        << "log_pdf(50) should be a very negative finite number";
}

// =============================================================================
// TEST SUITE: NormalProperties
// Higher-level mathematical properties of the Normal distribution.
// =============================================================================

TEST(NormalProperties, PdfApproximatelyIntegratesTo1) {
    // PROBABILITY AXIOM:
    // The total probability must be 1.
    // We verify this numerically using the trapezoidal rule.
    // The Normal distribution has effectively zero density beyond 8 sigma
    // from the mean, so we integrate from mu-8*sigma to mu+8*sigma.

    Normal d(5.0, 2.0);

    // Trapezoidal integration over [mu - 8*sigma, mu + 8*sigma]
    const int n_points = 100'000;
    double x_min = d.mu() - 8.0 * d.sigma();
    double x_max = d.mu() + 8.0 * d.sigma();
    double dx    = (x_max - x_min) / n_points;

    double integral = 0.0;
    double x_prev   = x_min;
    double f_prev   = d.pdf(x_prev);

    for (int i = 1; i <= n_points; ++i) {
        double x_curr = x_min + i * dx;
        double f_curr = d.pdf(x_curr);
        // Trapezoidal rule: area of trapezoid = (f1 + f2) / 2 * dx
        integral += (f_prev + f_curr) * 0.5 * dx;
        x_prev = x_curr;
        f_prev = f_curr;
    }

    EXPECT_NEAR(integral, 1.0, 1e-6)
        << "PDF should integrate to 1.0 over the support. Got: " << integral;
}
