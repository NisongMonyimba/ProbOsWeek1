"""
================================================================================
probos.distributions — the fundamental type system of ProbOS
================================================================================

WHAT IS THIS FILE?
------------------
This is the most important file in Week 1. Everything in ProbOS is built on
probability distributions. A distribution is an object that represents an
UNCERTAIN QUANTITY — something we do not know the exact value of, but we
know the range of possible values and how likely each value is.

EXAMPLES OF UNCERTAIN QUANTITIES IN REAL SYSTEMS:
--------------------------------------------------
  Battery:
    The activation energy of the SEI decomposition reaction (Ea_SEI) is
    not a single number. Different cells from the same manufacturing line
    have slightly different Ea_SEI values. We model this as:
      Ea_SEI ~ Normal(mu=1.35e5, sigma=5000)  [J/mol]

  Drug:
    The drug clearance rate (CL) varies between patients because of
    differences in liver function, body weight, and genetics. We model this as:
      CL ~ LogNormal(mu=1.2, sigma=0.385)  [L/h]  (40% coefficient of variation)

  Finance:
    The option vol-of-vol (xi) in the Heston model is uncertain because it
    is estimated from finite option price data. We model this as:
      xi ~ LogNormal(mu=-1.0, sigma=0.4)

  Hospital:
    ICU length-of-stay varies enormously between patients. We model this as:
      LOS ~ LogNormal(mu=2.1, sigma=0.8)  [days]

THE FOUR OPERATIONS EVERY DISTRIBUTION MUST SUPPORT:
-----------------------------------------------------
1. sample(n)    -> draw n independent random values from the distribution.
                   This is the core of Monte Carlo simulation.

2. pdf(x)       -> evaluate the probability density at x.
                   Tells you how "probable" a value x is.

3. log_pdf(x)   -> evaluate the natural log of the density at x.
                   CRITICAL for Bayesian inference (see WHY below).

4. ppf(u)       -> the inverse CDF. Given a probability u in [0,1],
                   return the value x such that P(X <= x) = u.
                   Used for correlated sampling (the Nataf transform).

WHY log_pdf IS NOT OPTIONAL — THE MOST IMPORTANT NOTE IN THIS FILE:
-------------------------------------------------------------------
Bayesian inference computes:
    log_posterior = log_likelihood + log_prior

If instead we compute:  np.log(pdf(x))
Then when x is an extreme value, pdf(x) underflows to 0.0 (the number is too
small for float64 to represent). Then np.log(0.0) = -infinity. The whole
Bayesian computation collapses. This is not a theoretical concern — it kills
real-world inference runs in battery parameter estimation, drug PK/PD
calibration, and option model calibration.

The analytical log_pdf avoids this by never computing the tiny exponential.
It stays in log-space throughout.

HOW THIS FILE RELATES TO THE C++ CODE:
--------------------------------------
python/src/distributions.py  ← YOU ARE HERE (fast to write, slow to run)
cpp/include/distributions/    ← the same classes in C++ (same math, 100x faster)

We write the prototype in Python for rapid development and testing.
We translate to C++ for performance in the Monte Carlo engine.
Both must implement the SAME mathematical formulas.

REFERENCES:
-----------
Blitzstein & Hwang (2019). "Introduction to Probability." CRC Press.
  - Chapter 1: Probability and Counting (axioms, conditional probability)
  - Chapter 5: Continuous Random Variables (Normal, Exponential)
  - Chapter 6: Moments (expectation, variance)

Jaynes (2003). "Probability Theory: The Logic of Science." Cambridge.
  - The philosophical foundation: probability as extended logic, not frequency.
================================================================================
"""

# ==============================================================================
# IMPORTS
# ==============================================================================

# __future__.annotations: enables postponed evaluation of annotations.
# This lets us write  def sample(self, n: int) -> "FloatArray"  without quotes
# when FloatArray is defined later in the file.
from __future__ import annotations

# abc: Abstract Base Classes.
# An abstract base class defines an INTERFACE — a set of methods that every
# subclass MUST implement. If you try to instantiate a class that does not
# implement all abstract methods, Python raises TypeError immediately.
# This prevents bugs where a distribution "forgets" to implement log_pdf.
from abc import ABC, abstractmethod

# typing provides type annotation utilities.
# numpy is the core numerical library. We use it for:
#   - np.random.default_rng() : the modern random number generator (PCG64)
#   - np.asarray()            : convert inputs to float64 arrays
#   - np.exp(), np.log(), np.sqrt() : element-wise math operations on arrays
#   - np.inf, np.pi           : mathematical constants
import numpy as np

# numpy.typing provides type annotations for numpy arrays.
# NDArray[np.float64] means "a numpy array where each element is float64".
from numpy.typing import NDArray
from scipy import stats as sp_stats

# scipy.special provides special mathematical functions not in numpy.
# erfinv: the inverse error function, needed for Normal.ppf.
# gaussian_kde: kernel density estimation, used in Empirical.pdf.
from scipy.special import erfinv

# ==============================================================================
# TYPE ALIAS
# ==============================================================================

# FloatArray is shorthand for "a numpy array of 64-bit floating point numbers".
# Defining it once here means we can write FloatArray everywhere instead of
# the longer NDArray[np.float64]. If we ever need to change the precision
# (e.g. to float32 for GPU), we change it in ONE place.
FloatArray = NDArray[np.float64]


# ==============================================================================
# THE DISTRIBUTION ABSTRACT BASE CLASS
# ==============================================================================

class Distribution(ABC):
    """
    Abstract base class for ALL probability distributions in ProbOS.

    Every uncertain quantity in every domain model — battery activation
    energy, drug clearance, option volatility, ICU length-of-stay —
    is an instance of a concrete subclass of this class.

    The Monte Carlo engine (Week 3), particle filter (Month 2), and
    sensitivity analysis (Week 4) all work through this interface.
    They never know which specific distribution they are dealing with.

    WHY USE AN ABSTRACT BASE CLASS?
    ---------------------------------
    If the MonteCarloEngine called Normal.sample() directly, it would only
    work with Normal distributions. By making it call Distribution.sample(),
    it works with ANY distribution — LogNormal, Beta, Empirical, anything.
    This is the "Open/Closed Principle": open for extension (new distributions),
    closed for modification (the engine never changes).

    HOW TO CREATE A NEW DISTRIBUTION:
    ----------------------------------
    1. Subclass Distribution.
    2. Implement sample(), pdf(), log_pdf(), ppf().
    3. Optionally override mean(), variance(), support().
    4. Add tests to test_distributions.py.
    That is all. The engine will work with it immediately.
    """

    # ==========================================================================
    # ABSTRACT METHODS — every subclass MUST implement these
    # ==========================================================================

    @abstractmethod
    def sample(
        self,
        n: int,
        rng: np.random.Generator | None = None,
    ) -> FloatArray:
        """
        Draw `n` independent samples from the distribution.

        Parameters
        ----------
        n   : int
            How many samples to draw. Must be >= 1.
        rng : np.random.Generator, optional
            A numpy random number generator. ALWAYS pass one in production
            code to ensure reproducibility.
            If None, a fresh PCG64 generator is created (non-reproducible).

        Returns
        -------
        FloatArray of shape (n,)
            The sampled values.

        Notes
        -----
        Why pass rng as a parameter instead of creating it internally?
        Because the caller needs to control the random stream:
          - Same rng + same calls = same samples every time (reproducibility)
          - Each thread gets its OWN rng (parallel safety, no race conditions)
          - Testing: use a seeded rng for deterministic test output
        """
        ...  # Abstract method — no implementation here

    @abstractmethod
    def pdf(self, x: FloatArray) -> FloatArray:
        """
        Probability density function evaluated element-wise at x.

        For a continuous distribution, pdf(x) is NOT the probability that
        X = x (that is always 0). It is the "height" of the probability density
        at x. Integrating pdf(x) over an interval [a,b] gives P(a <= X <= b).

        Parameters
        ----------
        x : FloatArray
            The points at which to evaluate the density.

        Returns
        -------
        FloatArray of same shape as x
            The density values. Always >= 0.
        """
        ...

    @abstractmethod
    def log_pdf(self, x: FloatArray) -> FloatArray:
        """
        Natural logarithm of the probability density, evaluated analytically.

        IMPORTANT: This is NOT np.log(self.pdf(x)).
        It is computed analytically to avoid numerical underflow.
        See the module docstring for a full explanation.

        Parameters
        ----------
        x : FloatArray
            The points at which to evaluate the log-density.

        Returns
        -------
        FloatArray of same shape as x
            The log-density values. Always <= 0 (since pdf <= 1 for most x).
            Returns -inf where the distribution has zero density.
        """
        ...

    @abstractmethod
    def ppf(self, u: FloatArray) -> FloatArray:
        """
        Percent-point function (inverse CDF, also called the quantile function).

        Given probabilities u in [0, 1], return the values x such that:
            P(X <= x) = u

        Examples:
            ppf(0.05) = the 5th percentile
            ppf(0.50) = the median
            ppf(0.95) = the 95th percentile

        Parameters
        ----------
        u : FloatArray
            Probability values in [0, 1].

        Returns
        -------
        FloatArray of same shape as u
            The corresponding quantile values.

        WHY IS ppf NECESSARY?
        ----------------------
        The CorrelatedSampler class (Week 3) uses the Nataf transform to
        generate correlated samples from multiple distributions. The transform
        works by:
          1. Generate correlated standard normals (easy).
          2. Map each to a uniform on [0,1] via the normal CDF.
          3. Push each uniform through the target distribution's ppf.
        Without ppf, we cannot generate correlated samples.
        """
        ...

    # ==========================================================================
    # OPTIONAL METHODS — subclasses can override these for efficiency
    # ==========================================================================

    def mean(self) -> float:
        """
        Analytical mean of the distribution.

        Override in subclasses where a closed-form formula exists.
        The default raises NotImplementedError to signal "not implemented".
        """
        raise NotImplementedError(
            f"{type(self).__name__} does not provide an analytical mean. "
            "Estimate it numerically: d.sample(100_000).mean()"
        )

    def variance(self) -> float:
        """
        Analytical variance of the distribution.

        Override in subclasses where a closed-form formula exists.
        """
        raise NotImplementedError(
            f"{type(self).__name__} does not provide an analytical variance. "
            "Estimate it numerically: d.sample(100_000).var(ddof=1)"
        )

    def support(self) -> tuple[float, float]:
        """
        The (lower, upper) bounds of the distribution's support.

        Support = the set of x values where pdf(x) > 0.
        Returns (-inf, +inf) by default (appropriate for Normal).
        Override for distributions with bounded support (Beta, Uniform).
        """
        return (-np.inf, np.inf)

    # ==========================================================================
    # PRIVATE HELPER — available to all subclasses
    # ==========================================================================

    @staticmethod
    def _resolve_rng(
        rng: np.random.Generator | None,
    ) -> np.random.Generator:
        """
        Return the given rng if provided, otherwise create a new PCG64 generator.

        This is a STATIC method (does not use self) that every subclass
        can call to avoid repeating the same None-check boilerplate.

        WHY PCG64?
        ----------
        PCG64 (Permuted Congruential Generator) is the modern default in NumPy.
        It passes all statistical tests, is fast, and supports multiple
        independent streams via seed sequences.
        The old numpy.random.seed() used the Mersenne Twister, which has
        known correlations when used with multiple independent seeds.
        NEVER use numpy.random.seed() in new code.
        """
        if rng is not None:
            return rng
        # Create a new generator seeded from OS entropy (non-reproducible).
        # Use this only for interactive exploration, never in production code.
        return np.random.default_rng()


# ==============================================================================
# CONCRETE DISTRIBUTION 1: Normal (Gaussian)
# ==============================================================================

class Normal(Distribution):
    """
    Normal (Gaussian) distribution: N(mu, sigma^2).

    The most fundamental distribution in statistics. Its bell-curve shape
    arises naturally from the Central Limit Theorem: any quantity that is
    the sum of many independent random effects will be approximately Normal,
    regardless of the individual distributions.

    DOMAIN EXAMPLES:
    ----------------
    Battery SEI activation energy:
        Ea_SEI ~ Normal(1.35e5, 5e3)  [J/mol]
        Mean = 135,080 J/mol, Std = 5,000 J/mol

    Surgical encoder noise:
        encoder_noise ~ Normal(0.0, 0.05)  [degrees per joint]

    Taylor rule inflation coefficient (macroeconomics):
        phi_pi ~ Normal(1.5, 0.25)  [dimensionless]

    PARAMETERS:
    -----------
    mu    : float
        The mean (centre) of the distribution. Can be any real number.
    sigma : float
        The standard deviation (spread). Must be strictly positive.
        Variance = sigma^2.

    FORMULAS:
    ---------
    PDF:     f(x) = exp(-z^2/2) / (sigma * sqrt(2*pi))
             where z = (x - mu) / sigma

    log PDF: log f(x) = -0.5 * log(2*pi*sigma^2) - z^2/2

    PPF:     Q(u) = mu + sigma * sqrt(2) * erfinv(2*u - 1)
             where erfinv is the inverse error function
    """

    def __init__(self, mu: float, sigma: float) -> None:
        """
        Construct Normal(mu, sigma^2).

        Parameters
        ----------
        mu    : float — mean of the distribution
        sigma : float — standard deviation (must be > 0)

        Raises
        ------
        ValueError if sigma <= 0
        """
        # Validate inputs immediately — "fail fast" principle.
        # Better to get an error here than a silent wrong result downstream.
        if sigma <= 0.0:
            raise ValueError(
                f"Normal: sigma must be strictly positive, got sigma={sigma}. "
                f"A Normal distribution with sigma <= 0 is mathematically "
                f"undefined."
            )
        # Store as instance attributes (self.mu, self.sigma).
        # We convert to float to handle cases where int is passed in.
        self.mu = float(mu)
        self.sigma = float(sigma)

    def sample(
        self,
        n: int,
        rng: np.random.Generator | None = None,
    ) -> FloatArray:
        """
        Draw n independent samples from Normal(mu, sigma^2).

        Uses numpy's Box-Muller transform internally.
        The output is a 1-D float64 array of length n.
        """
        return self._resolve_rng(rng).normal(
            loc=self.mu,        # mean of the distribution
            scale=self.sigma,   # standard deviation
            size=n,             # how many samples to draw
        )

    def pdf(self, x: FloatArray) -> FloatArray:
        """
        Evaluate the Normal PDF element-wise.

        Formula: f(x) = exp(-z^2/2) / (sigma * sqrt(2*pi))
        where z = (x - mu) / sigma  (standardisation)
        """
        # Convert input to float64 array (handles Python lists, scalars, etc.)
        x = np.asarray(x, dtype=np.float64)

        # Standardise: z = (x - mu) / sigma
        # This maps any Normal(mu, sigma) to a standard Normal(0, 1) problem.
        z = (x - self.mu) / self.sigma

        # Compute the PDF.
        # np.exp, np.pi, np.sqrt are all element-wise operations.
        result: FloatArray = np.exp(-0.5 * z * z) / (self.sigma * np.sqrt(2.0 * np.pi))
        return result

    def log_pdf(self, x: FloatArray) -> FloatArray:
        """
        Evaluate the log-Normal PDF element-wise (analytical form).

        Formula: log f(x) = -0.5 * log(2*pi*sigma^2) - z^2/2
        This is mathematically exact and numerically stable for all finite x.
        """
        x = np.asarray(x, dtype=np.float64)
        z = (x - self.mu) / self.sigma

        # The constant term: -0.5 * log(2 * pi * sigma^2)
        # This does NOT depend on x — we could cache it for speed, but
        # clarity comes first in educational code.
        log_normaliser = 0.5 * np.log(2.0 * np.pi * self.sigma ** 2)

        result: FloatArray = np.asarray(-log_normaliser - 0.5 * z * z, dtype=np.float64)
        return result

    def ppf(self, u: FloatArray) -> FloatArray:
        """
        Normal quantile function (inverse CDF).

        Formula: Q(u) = mu + sigma * sqrt(2) * erfinv(2*u - 1)

        DERIVATION:
        The Normal CDF is: F(x) = 0.5 * [1 + erf((x-mu)/(sigma*sqrt(2)))]
        Inverting: x = mu + sigma * sqrt(2) * erfinv(2*u - 1)
        where erf is the error function and erfinv is its inverse.
        """
        u = np.asarray(u, dtype=np.float64)
        # erfinv is imported from scipy.special at the top of this file.
        result: FloatArray = np.asarray(
            self.mu + self.sigma * np.sqrt(2.0) * erfinv(2.0 * u - 1.0),
            dtype=np.float64,
        )
        return result

    def mean(self) -> float:
        """The mean of Normal(mu, sigma^2) is mu."""
        return self.mu

    def variance(self) -> float:
        """The variance of Normal(mu, sigma^2) is sigma^2."""
        return self.sigma ** 2

    def __repr__(self) -> str:
        """String representation for debugging: print(d) shows the parameters."""
        return f"Normal(mu={self.mu}, sigma={self.sigma})"


# ==============================================================================
# CONCRETE DISTRIBUTION 2: LogNormal
# ==============================================================================

class LogNormal(Distribution):
    """
    LogNormal distribution: if Y ~ Normal(mu, sigma^2), then X = exp(Y).

    USE LOGNORMAL WHEN:
    -------------------
    - The quantity MUST be positive (you cannot have negative clearance rates
      or negative pre-exponential factors).
    - The quantity varies MULTIPLICATIVELY (spans orders of magnitude).
    - The distribution is right-skewed (most values are small, but there is
      a long tail of large values).

    DOMAIN EXAMPLES:
    ----------------
    Arrhenius pre-exponential factor A (battery):
        A_SEI ~ LogNormal(mu=34.05, sigma=0.5)  [s^-1]
        This spans 1e14 to 1e16 s^-1 — a factor of 100.

    Drug clearance CL (pharmacokinetics):
        CL ~ LogNormal(mu=1.2, sigma=0.385)  [L/h]
        40% coefficient of variation — typical inter-patient variability.

    Option vol-of-vol xi (Heston model):
        xi ~ LogNormal(mu=-1.0, sigma=0.4)
        Must be positive; spans 0.2 to 1.5 depending on market conditions.

    MAP kinase rate constants (systems biology):
        k1f ~ LogNormal(mu=-4.6, sigma=1.0)  [nM^-1 s^-1]
        Literature values span 2-3 orders of magnitude between labs.

    PARAMETERS:
    -----------
    mu    : float
        Mean of the UNDERLYING normal log(X). NOT the mean of X itself.
    sigma : float
        Std of the UNDERLYING normal log(X). Must be > 0.

    Mean of X:     E[X] = exp(mu + sigma^2/2)
    Variance of X: Var[X] = (exp(sigma^2) - 1) * exp(2*mu + sigma^2)
    """

    def __init__(self, mu: float, sigma: float) -> None:
        if sigma <= 0.0:
            raise ValueError(
                f"LogNormal: sigma must be > 0, got sigma={sigma}. "
                f"Remember: mu and sigma are the parameters of the "
                f"UNDERLYING normal, not of X itself."
            )
        self.mu = float(mu)
        self.sigma = float(sigma)

    def sample(
        self,
        n: int,
        rng: np.random.Generator | None = None,
    ) -> FloatArray:
        """Draw n samples. All samples are strictly positive."""
        return self._resolve_rng(rng).lognormal(
            mean=self.mu,    # mean of the underlying normal log(X)
            sigma=self.sigma, # std of the underlying normal
            size=n,
        )

    def pdf(self, x: FloatArray) -> FloatArray:
        """
        LogNormal PDF:
        f(x) = exp(-z^2/2) / (x * sigma * sqrt(2*pi))
        where z = (log(x) - mu) / sigma

        The PDF is zero for x <= 0 (LogNormal only has support on (0, inf)).
        """
        x = np.asarray(x, dtype=np.float64)

        # Create output array of zeros.
        # Points where x <= 0 will remain 0 (correct: no probability there).
        out = np.zeros_like(x)

        # Compute the PDF only at positive x values.
        # pos is a boolean mask: True where x > 0.
        pos = x > 0.0
        if np.any(pos):
            z = (np.log(x[pos]) - self.mu) / self.sigma
            out[pos] = np.exp(-0.5 * z * z) / (
                x[pos] * self.sigma * np.sqrt(2.0 * np.pi)
            )
        return out

    def log_pdf(self, x: FloatArray) -> FloatArray:
        """
        LogNormal log-PDF (analytical):
        log f(x) = -log(x * sigma * sqrt(2*pi)) - z^2/2  for x > 0
        log f(x) = -inf                                   for x <= 0
        """
        x = np.asarray(x, dtype=np.float64)

        # Initialise with -inf (the log-PDF is -inf outside the support).
        out = np.full_like(x, -np.inf)

        pos = x > 0.0
        if np.any(pos):
            z = (np.log(x[pos]) - self.mu) / self.sigma
            out[pos] = (
                -np.log(x[pos] * self.sigma * np.sqrt(2.0 * np.pi))
                - 0.5 * z * z
            )
        return out

    def ppf(self, u: FloatArray) -> FloatArray:
        """
        LogNormal quantile function.
        If Q_N(u) is the Normal quantile, then Q_LN(u) = exp(Q_N(u)).
        """
        u = np.asarray(u, dtype=np.float64)
        # First compute the Normal quantile, then exponentiate.
        normal_quantile = self.mu + self.sigma * np.sqrt(2.0) * erfinv(2.0 * u - 1.0)
        result: FloatArray = np.asarray(np.exp(normal_quantile), dtype=np.float64)
        return result

    def mean(self) -> float:
        """E[X] = exp(mu + sigma^2/2)"""
        return float(np.exp(self.mu + 0.5 * self.sigma ** 2))

    def variance(self) -> float:
        """Var[X] = (exp(sigma^2) - 1) * exp(2*mu + sigma^2)"""
        s2 = self.sigma ** 2
        return float((np.exp(s2) - 1.0) * np.exp(2.0 * self.mu + s2))

    def support(self) -> tuple[float, float]:
        """LogNormal has support on (0, +inf)."""
        return (0.0, np.inf)

    def __repr__(self) -> str:
        return f"LogNormal(mu={self.mu}, sigma={self.sigma})"


# ==============================================================================
# CONCRETE DISTRIBUTION 3: Uniform
# ==============================================================================

class Uniform(Distribution):
    """
    Continuous Uniform distribution on [low, high].

    The "maximum ignorance within bounds" prior.
    Use Uniform when you know the RANGE of a parameter but have no reason
    to prefer any particular value within that range.

    Also the foundation of Monte Carlo sensitivity analysis: Saltelli's
    method sweeps parameters uniformly across their plausible ranges to
    compute Sobol' indices.

    DOMAIN EXAMPLES:
    ----------------
    Unknown reaction rate (broad prior for sensitivity screening):
        k ~ Uniform(1e-6, 1e-2)  [s^-1]

    Number of fiducial markers in surgical robot registration:
        n_fiducials ~ Uniform(4, 9)  (floor to integer in the model)

    Process parameter range for ICH Q8 design space:
        LOD_percent ~ Uniform(2.0, 8.0)  [% loss on drying]
    """

    def __init__(self, low: float, high: float) -> None:
        if not (low < high):
            raise ValueError(
                f"Uniform: need low < high, got low={low}, high={high}. "
                f"The interval [low, high] must be non-empty."
            )
        self.low  = float(low)
        self.high = float(high)

    def sample(
        self,
        n: int,
        rng: np.random.Generator | None = None,
    ) -> FloatArray:
        return self._resolve_rng(rng).uniform(
            low=self.low,
            high=self.high,
            size=n,
        )

    def pdf(self, x: FloatArray) -> FloatArray:
        """
        Uniform PDF:
        f(x) = 1 / (high - low)  for x in [low, high]
        f(x) = 0                  elsewhere
        """
        x      = np.asarray(x, dtype=np.float64)
        width  = self.high - self.low
        inside = (x >= self.low) & (x <= self.high)
        # np.where(condition, value_if_true, value_if_false)
        return np.where(inside, 1.0 / width, 0.0)

    def log_pdf(self, x: FloatArray) -> FloatArray:
        """
        Uniform log-PDF:
        log f(x) = -log(high - low)  for x in [low, high]
        log f(x) = -inf              elsewhere
        """
        x      = np.asarray(x, dtype=np.float64)
        inside = (x >= self.low) & (x <= self.high)
        return np.where(inside, -np.log(self.high - self.low), -np.inf)

    def ppf(self, u: FloatArray) -> FloatArray:
        """
        Uniform quantile function: Q(u) = low + u * (high - low)
        Linear interpolation between low and high.
        """
        u = np.asarray(u, dtype=np.float64)
        return self.low + u * (self.high - self.low)

    def mean(self) -> float:
        """E[X] = (low + high) / 2"""
        return 0.5 * (self.low + self.high)

    def variance(self) -> float:
        """Var[X] = (high - low)^2 / 12"""
        return (self.high - self.low) ** 2 / 12.0

    def support(self) -> tuple[float, float]:
        return (self.low, self.high)

    def __repr__(self) -> str:
        return f"Uniform(low={self.low}, high={self.high})"


# ==============================================================================
# CONCRETE DISTRIBUTION 4: Beta
# ==============================================================================

class Beta(Distribution):
    """
    Beta distribution: Beta(alpha, beta), supported on [0, 1].

    The natural choice for any quantity that is a PROPORTION or PROBABILITY:
    it lives on [0,1] and its shape can be tuned to express everything from
    "I think it is around 0.8" to "I know nothing" to "it is near 0".

    DOMAIN EXAMPLES:
    ----------------
    Drug protein binding fraction (pharmacokinetics):
        f_bound ~ Beta(alpha=8, beta=2)   (mean = 0.8, std ≈ 0.12)
        "About 80% of drug molecules are bound to plasma proteins."

    Hospital nurse sick-call rate:
        sick_rate ~ Beta(alpha=2, beta=18)  (mean = 0.10, std ≈ 0.07)
        "About 10% of nurses call in sick on any given day."

    Drug bioavailability:
        F ~ Beta(alpha=4, beta=2)  (mean ≈ 0.67)

    PARAMETERS:
    -----------
    alpha : float > 0  — shape parameter (higher alpha → mode closer to 1)
    beta  : float > 0  — shape parameter (higher beta → mode closer to 0)

    Mean: alpha / (alpha + beta)
    Variance: alpha*beta / ((alpha+beta)^2 * (alpha+beta+1))

    SPECIAL CASES:
    --------------
    Beta(1, 1) = Uniform(0, 1)    (no prior knowledge)
    Beta(alpha, 1) for large alpha = concentrated near 1
    Beta(1, beta)  for large beta  = concentrated near 0
    """

    def __init__(self, alpha: float, beta: float) -> None:
        if alpha <= 0.0 or beta <= 0.0:
            raise ValueError(
                f"Beta: alpha and beta must be > 0, "
                f"got alpha={alpha}, beta={beta}."
            )
        self.alpha = float(alpha)
        self.beta  = float(beta)

    def sample(
        self,
        n: int,
        rng: np.random.Generator | None = None,
    ) -> FloatArray:
        return self._resolve_rng(rng).beta(
            a=self.alpha,
            b=self.beta,
            size=n,
        )

    def pdf(self, x: FloatArray) -> FloatArray:
        """Beta PDF via scipy.stats.beta (handles edge cases correctly)."""
        vals = sp_stats.beta.pdf(
            np.asarray(x, dtype=np.float64),
            a=self.alpha,
            b=self.beta,
        )
        result: FloatArray = np.asarray(vals, dtype=np.float64)
        return result

    def log_pdf(self, x: FloatArray) -> FloatArray:
        """Beta log-PDF via scipy.stats.beta.logpdf (numerically stable)."""
        vals = sp_stats.beta.logpdf(
            np.asarray(x, dtype=np.float64),
            a=self.alpha,
            b=self.beta,
        )
        result: FloatArray = np.asarray(vals, dtype=np.float64)
        return result

    def ppf(self, u: FloatArray) -> FloatArray:
        """Beta quantile function via scipy.stats.beta.ppf."""
        vals = sp_stats.beta.ppf(
            np.asarray(u, dtype=np.float64),
            a=self.alpha,
            b=self.beta,
        )
        result: FloatArray = np.asarray(vals, dtype=np.float64)
        return result

    def mean(self) -> float:
        """E[X] = alpha / (alpha + beta)"""
        return self.alpha / (self.alpha + self.beta)

    def variance(self) -> float:
        """Var[X] = alpha*beta / ((alpha+beta)^2 * (alpha+beta+1))"""
        a, b = self.alpha, self.beta
        return (a * b) / ((a + b) ** 2 * (a + b + 1.0))

    def support(self) -> tuple[float, float]:
        """Beta is defined on [0, 1]."""
        return (0.0, 1.0)

    def __repr__(self) -> str:
        return f"Beta(alpha={self.alpha}, beta={self.beta})"


# ==============================================================================
# CONCRETE DISTRIBUTION 5: Empirical (data-driven)
# ==============================================================================

class Empirical(Distribution):
    """
    Distribution defined directly by a sample of OBSERVED DATA.

    This is the bridge between the real world and the model.
    When a customer provides:
      - Real ICU length-of-stay measurements from their hospital EHR
      - Real DFT functional error data from their quantum chemistry calculations
      - Real battery capacity measurements from their production line
    ...you wrap that data in an Empirical distribution and the Monte Carlo
    engine samples from the actual observed distribution.

    SAMPLING: bootstrap (sampling with replacement from the observed data).
    This is non-parametric: no assumption is made about the shape of the
    distribution.

    PDF: a Gaussian kernel density estimate (KDE) is fitted to the data.
    This gives a smooth density estimate rather than a histogram.

    USE WHEN:
    ---------
    - You have real measured data AND
    - You do not know the parametric form AND
    - You want to use the data directly without model assumptions.

    PARAMETERS:
    -----------
    data : array-like
        The observed data points. Minimum 2 points required.
    """

    def __init__(self, data: FloatArray) -> None:
        # Convert to 1-D float64 array, removing any NaN or extra dimensions.
        data = np.asarray(data, dtype=np.float64).ravel()

        if data.size < 2:
            raise ValueError(
                f"Empirical: need at least 2 data points, got {data.size}."
            )

        self.data    = data
        self._sorted = np.sort(data)   # pre-sorted for percentile computation

        # Fit a Gaussian kernel density estimate.
        # The bandwidth is chosen automatically by Scott's rule (default).
        # This gives a smooth, continuous approximation to the density.
        from scipy.stats import gaussian_kde
        self._kde = gaussian_kde(data)

    def sample(
        self,
        n: int,
        rng: np.random.Generator | None = None,
    ) -> FloatArray:
        """
        Bootstrap sampling: draw n values with replacement from the observed data.
        Each returned sample is one of the original observed values.
        """
        result: FloatArray = self._resolve_rng(rng).choice(
            self.data,
            size=n,
            replace=True,
        )
        return result

    def pdf(self, x: FloatArray) -> FloatArray:
        """Kernel density estimate evaluated at x."""
        vals = self._kde(np.asarray(x, dtype=np.float64))
        result: FloatArray = np.asarray(vals, dtype=np.float64)
        return result

    def log_pdf(self, x: FloatArray) -> FloatArray:
        """Log of the kernel density estimate."""
        vals = self._kde.logpdf(np.asarray(x, dtype=np.float64))
        result: FloatArray = np.asarray(vals, dtype=np.float64)
        return result

    def ppf(self, u: FloatArray) -> FloatArray:
        """
        Empirical quantile function: linear interpolation over sorted data.
        Q(0.05) = the value below which 5% of observed data falls.
        """
        u = np.asarray(u, dtype=np.float64)
        return np.quantile(self._sorted, u)

    def mean(self) -> float:
        """Sample mean of the data."""
        return float(self.data.mean())

    def variance(self) -> float:
        """Sample variance (with Bessel's correction, ddof=1)."""
        return float(self.data.var(ddof=1))

    def support(self) -> tuple[float, float]:
        """The support is approximately [min(data), max(data)]."""
        return (float(self._sorted[0]), float(self._sorted[-1]))

    def __repr__(self) -> str:
        return (
            f"Empirical(n={len(self.data)}, "
            f"mean={self.mean():.4g}, "
            f"std={np.sqrt(self.variance()):.4g})"
        )


# ==============================================================================
# PUBLIC API — what `from probos.distributions import *` exports
# ==============================================================================

__all__ = [
    "Distribution",   # The abstract base class
    "Normal",         # Normal(mu, sigma)
    "LogNormal",      # LogNormal(mu, sigma)  -- parameters of underlying normal
    "Uniform",        # Uniform(low, high)
    "Beta",           # Beta(alpha, beta)
    "Empirical",      # Empirical(data)
    "FloatArray",     # Type alias for NDArray[np.float64]
]
