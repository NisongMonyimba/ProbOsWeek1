#!/usr/bin/env bash
# =============================================================================
# scripts/RunTests.sh
# =============================================================================
# Test runner for ProbOS Week 1.
# Runs ALL tests (Python + C++) and reports clear PASS / FAIL for each suite.
#
# USAGE:
#   chmod +x scripts/RunTests.sh
#   ./scripts/RunTests.sh
#
# WHAT IT DOES:
#   1. Activates the Python virtual environment (if it exists)
#   2. Runs the Python pytest suite
#   3. Builds the C++ code (if the build directory exists)
#   4. Runs the C++ Google Test suite
#   5. Prints a final summary with PASS/FAIL counts
#
# EXIT CODES:
#   0 = all tests passed
#   1 = one or more tests failed
#
# COLOUR OUTPUT:
#   Green = PASS
#   Red   = FAIL
#   Yellow = WARNING / skipped
#
# NOTE: This script is designed to be run from the PROJECT ROOT directory.
#   cd probos-week1
#   ./scripts/RunTests.sh
# =============================================================================

# --------------------------------------------------------------------------- #
# BASH SAFETY FLAGS
# --------------------------------------------------------------------------- #
# -e : exit immediately if any command returns a non-zero exit code.
#      Without this, the script keeps running after a failure, hiding errors.
# -u : treat undefined variables as errors. Catches typos like $PYTON_PATH.
# -o pipefail : if any command in a pipeline fails, the whole pipeline fails.
#              Without this, "false | true" would succeed.
set -euo pipefail

# --------------------------------------------------------------------------- #
# COLOUR CODES for terminal output
# --------------------------------------------------------------------------- #
# These are ANSI escape codes. They work on Linux, macOS, and Windows Terminal.
# \033[1;32m = bold green   (for PASS)
# \033[1;31m = bold red     (for FAIL)
# \033[1;33m = bold yellow  (for WARNING)
# \033[1;34m = bold blue    (for INFO)
# \033[0m    = reset to default

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
RESET='\033[0m'

# --------------------------------------------------------------------------- #
# HELPER FUNCTIONS
# --------------------------------------------------------------------------- #

print_header() {
    # Prints a formatted section header.
    # $1 = the header text
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}  $1${RESET}"
    echo -e "${BLUE}══════════════════════════════════════════════════════${RESET}"
}

print_step() {
    # Prints a test step with a bullet point.
    # $1 = step description
    echo -e "${BLUE}  ▶ $1${RESET}"
}

print_pass() {
    # Prints a green PASS message.
    # $1 = what passed
    echo -e "${GREEN}  ✓ PASS: $1${RESET}"
}

print_fail() {
    # Prints a red FAIL message with the error details.
    # $1 = what failed
    # $2 = error details (optional)
    echo -e "${RED}  ✗ FAIL: $1${RESET}"
    if [[ -n "${2:-}" ]]; then
        echo -e "${RED}    Details: $2${RESET}"
    fi
}

print_warn() {
    # Prints a yellow WARNING message.
    # $1 = warning text
    echo -e "${YELLOW}  ⚠ WARN: $1${RESET}"
}

print_info() {
    # Prints a blue informational message.
    # $1 = info text
    echo -e "${BLUE}  ℹ $1${RESET}"
}

# --------------------------------------------------------------------------- #
# GLOBAL COUNTERS
# These track total pass/fail counts across all test suites.
# --------------------------------------------------------------------------- #
TOTAL_PASS=0
TOTAL_FAIL=0
SUITES_RUN=0
SUITES_FAILED=0

# --------------------------------------------------------------------------- #
# FIND THE PROJECT ROOT
# --------------------------------------------------------------------------- #
# We want this script to work whether called from the project root or from
# the scripts/ subdirectory.
#
# SCRIPT_DIR: the directory containing this script
# PROJECT_ROOT: one level up from SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo ""
echo -e "${WHITE}ProbOS Week 1 — Test Runner${RESET}"
echo -e "${BLUE}Project root: ${PROJECT_ROOT}${RESET}"

# Change to the project root so all relative paths work correctly.
cd "${PROJECT_ROOT}"

# --------------------------------------------------------------------------- #
# SUITE 1: PYTHON TESTS (pytest)
# --------------------------------------------------------------------------- #
print_header "Suite 1: Python Tests (pytest)"

# Check that Python 3 is available.
if ! command -v python3 &>/dev/null; then
    print_fail "Python 3 not found" "Install from https://www.python.org"
    SUITES_FAILED=$((SUITES_FAILED + 1))
else
    PYTHON_VERSION=$(python3 --version 2>&1)
    print_info "Found: ${PYTHON_VERSION}"

    # Activate the virtual environment if it exists.
    # The virtual environment is created by RunAll.sh — if it does not exist,
    # we warn and try to use the system Python.
    if [[ -f ".venv/bin/activate" ]]; then
        # shellcheck source=/dev/null
        source .venv/bin/activate
        print_info "Virtual environment activated (.venv)"
    elif [[ -f ".venv/Scripts/activate" ]]; then
        # Windows-style path
        # shellcheck source=/dev/null
        source .venv/Scripts/activate
        print_info "Virtual environment activated (.venv, Windows)"
    else
        print_warn "No virtual environment found (.venv/). Using system Python."
        print_warn "Run ./scripts/RunAll.sh first to create the virtual environment."
    fi

    # Check that pytest is available.
    if ! python3 -m pytest --version &>/dev/null; then
        print_fail "pytest not installed" "Run: pip install pytest"
        SUITES_FAILED=$((SUITES_FAILED + 1))
    else
        PYTEST_VERSION=$(python3 -m pytest --version 2>&1 | head -1)
        print_info "Found: ${PYTEST_VERSION}"

        # Check that the test file exists.
        if [[ ! -f "python/tests/test_distributions.py" ]]; then
            print_fail "Test file not found" "python/tests/test_distributions.py"
            SUITES_FAILED=$((SUITES_FAILED + 1))
        else
            print_step "Running python/tests/test_distributions.py..."
            echo ""

            # Run pytest and capture the output AND exit code.
            # We cannot use set -e here because we want to capture the failure.
            # Temporarily disable -e:
            set +e
            python3 -m pytest python/tests/test_distributions.py \
                --tb=short \
                --no-header \
                -q \
                2>&1
            PYTEST_EXIT=$?
            set -e

            echo ""

            if [[ ${PYTEST_EXIT} -eq 0 ]]; then
                print_pass "All Python tests passed"
                TOTAL_PASS=$((TOTAL_PASS + 1))
                SUITES_RUN=$((SUITES_RUN + 1))
            else
                print_fail "Python tests failed" \
                    "Exit code: ${PYTEST_EXIT}. See output above for details."
                TOTAL_FAIL=$((TOTAL_FAIL + 1))
                SUITES_FAILED=$((SUITES_FAILED + 1))
                SUITES_RUN=$((SUITES_RUN + 1))
            fi
        fi
    fi
fi

# --------------------------------------------------------------------------- #
# SUITE 2: PYTHON TYPE CHECKING (mypy)
# --------------------------------------------------------------------------- #
print_header "Suite 2: Python Type Checking (mypy)"

if ! python3 -m mypy --version &>/dev/null 2>&1; then
    print_warn "mypy not installed — skipping type checks"
    print_warn "Install with: pip install mypy"
else
    MYPY_VERSION=$(python3 -m mypy --version 2>&1)
    print_info "Found: ${MYPY_VERSION}"
    print_step "Type-checking python/src/distributions.py..."

    set +e
    python3 -m mypy python/src/distributions.py \
        --ignore-missing-imports \
        --no-error-summary \
        2>&1
    MYPY_EXIT=$?
    set -e

    if [[ ${MYPY_EXIT} -eq 0 ]]; then
        print_pass "No type errors found"
        TOTAL_PASS=$((TOTAL_PASS + 1))
        SUITES_RUN=$((SUITES_RUN + 1))
    else
        print_fail "Type errors found" \
            "Fix the errors shown above before committing."
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        SUITES_FAILED=$((SUITES_FAILED + 1))
        SUITES_RUN=$((SUITES_RUN + 1))
    fi
fi

# --------------------------------------------------------------------------- #
# SUITE 3: PYTHON LINTING (ruff)
# --------------------------------------------------------------------------- #
print_header "Suite 3: Python Linting (ruff)"

if ! python3 -m ruff --version &>/dev/null 2>&1; then
    print_warn "ruff not installed — skipping linting"
    print_warn "Install with: pip install ruff"
else
    RUFF_VERSION=$(python3 -m ruff --version 2>&1)
    print_info "Found: ${RUFF_VERSION}"
    print_step "Linting python/ directory..."

    set +e
    python3 -m ruff check python/ 2>&1
    RUFF_EXIT=$?
    set -e

    if [[ ${RUFF_EXIT} -eq 0 ]]; then
        print_pass "No linting issues found"
        TOTAL_PASS=$((TOTAL_PASS + 1))
        SUITES_RUN=$((SUITES_RUN + 1))
    else
        print_fail "Linting issues found" \
            "Fix the issues shown above."
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        SUITES_FAILED=$((SUITES_FAILED + 1))
        SUITES_RUN=$((SUITES_RUN + 1))
    fi
fi

# --------------------------------------------------------------------------- #
# SUITE 4: C++ TESTS (Google Test via ctest)
# --------------------------------------------------------------------------- #
print_header "Suite 4: C++ Tests (Google Test via ctest)"

# Check that the build directory exists.
# The build directory is created by RunAll.sh or by the user running cmake.
if [[ ! -d "build" ]]; then
    print_warn "build/ directory not found — C++ tests cannot run."
    print_warn "Build the C++ code first:"
    print_warn "  mkdir build && cd build && cmake .. -G Ninja && ninja && cd .."
    print_warn "Or run: ./scripts/RunAll.sh"
else
    # Check that ctest is available.
    if ! command -v ctest &>/dev/null; then
        print_warn "ctest not found — skipping C++ tests."
        print_warn "Install CMake: sudo apt-get install cmake"
    else
        CTEST_VERSION=$(ctest --version 2>&1 | head -1)
        print_info "Found: ${CTEST_VERSION}"

        # Check that the test executable was actually built.
        # It might not be if Google Test was not found during cmake.
        if [[ ! -f "build/bin/test_normal" ]] && \
           [[ ! -f "build/test_normal" ]] && \
           [[ -z "$(find build -name 'test_normal' -type f 2>/dev/null)" ]]; then
            print_warn "C++ test executable not found."
            print_warn "This usually means Google Test was not installed."
            print_warn "Install Google Test:"
            print_warn "  Ubuntu/Debian: sudo apt-get install -y libgtest-dev"
            print_warn "Then rebuild: cd build && ninja"
        else
            print_step "Running C++ tests (ctest)..."
            echo ""

            set +e
            # Run ctest from the build directory.
            # --output-on-failure: only show test output if a test fails.
            # -V : verbose (show each test name).
            (cd build && ctest --output-on-failure -V 2>&1)
            CTEST_EXIT=$?
            set -e

            echo ""

            if [[ ${CTEST_EXIT} -eq 0 ]]; then
                print_pass "All C++ tests passed"
                TOTAL_PASS=$((TOTAL_PASS + 1))
                SUITES_RUN=$((SUITES_RUN + 1))
            else
                print_fail "C++ tests failed" \
                    "Exit code: ${CTEST_EXIT}. See output above."
                TOTAL_FAIL=$((TOTAL_FAIL + 1))
                SUITES_FAILED=$((SUITES_FAILED + 1))
                SUITES_RUN=$((SUITES_RUN + 1))
            fi
        fi
    fi
fi

# --------------------------------------------------------------------------- #
# FINAL SUMMARY
# --------------------------------------------------------------------------- #
print_header "Test Summary"

echo -e "  Suites run:    ${WHITE}${SUITES_RUN}${RESET}"
echo -e "  Suites passed: ${GREEN}$((SUITES_RUN - SUITES_FAILED))${RESET}"
echo -e "  Suites failed: ${RED}${SUITES_FAILED}${RESET}"
echo ""

if [[ ${SUITES_FAILED} -eq 0 ]]; then
    echo -e "${GREEN}  ╔══════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}  ║  ALL TESTS PASSED — Ready to commit  ║${RESET}"
    echo -e "${GREEN}  ╚══════════════════════════════════════╝${RESET}"
    echo ""
    exit 0
else
    echo -e "${RED}  ╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}  ║  ${SUITES_FAILED} SUITE(S) FAILED — Fix before committing  ║${RESET}"
    echo -e "${RED}  ╚══════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${YELLOW}  HOW TO DEBUG:${RESET}"
    echo -e "${YELLOW}  Python failures: pytest python/tests/ -v --tb=long${RESET}"
    echo -e "${YELLOW}  C++ failures:    cd build && ctest -V --output-on-failure${RESET}"
    echo ""
    # Exit with code 1 to signal failure to CI systems and calling scripts.
    exit 1
fi
