#!/usr/bin/env bash
# =============================================================================
# RunTests.sh -- Run the full ProbOS test suite
#
# WHAT THIS SCRIPT RUNS:
#   1. pytest   -- all Python unit tests (Week 1 + Week 2)
#   2. mypy     -- strict type checking on all Python source files
#   3. ruff     -- code style and lint checker
#   4. ctest    -- C++ Google Tests (Week 1)
#   5. Syntax   -- quick syntax check on all example scripts
#
# HOW TO RUN:
#   cd /home/nison/ProbOsWeek1
#   source .venv/bin/activate
#   ./scripts/RunTests.sh
#
# EXPECTED OUTPUT:
#   All steps print PASS.  Any failure prints FAIL and exits immediately.
# =============================================================================

set -euo pipefail   # exit immediately on any error

# Find the project root (the directory containing this script's parent)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Colour codes for readable output
GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

pass() { echo -e "${GREEN}  PASS${RESET}  $1"; }
fail() { echo -e "${RED}  FAIL${RESET}  $1"; exit 1; }

echo ""
echo "============================================================"
echo "  ProbOS Test Suite"
echo "  Project: $PROJECT_ROOT"
echo "============================================================"
echo ""

# ------------------------------------------------------------
# STEP 1: pytest -- Python unit tests
# -v        verbose output (show each test name)
# --tb=short  short traceback on failure
# We run ALL test files: Week 1 distributions + Week 2 state/battery
# ------------------------------------------------------------
echo "Step 1: Python tests (pytest)"
echo "  Files:"
echo "    python/tests/test_distributions.py  (Week 1 -- 44 tests)"
echo "    python/tests/test_state.py           (Week 2 -- 27 tests)"
echo "    python/tests/test_battery_model.py   (Week 2 -- 40 tests)"
echo ""

if python -m pytest python/tests/ -v --tb=short --no-header -q; then
    pass "pytest -- all Python tests"
else
    fail "pytest -- one or more tests failed"
fi

echo ""

# ------------------------------------------------------------
# STEP 2: mypy -- strict type checking
# --strict enables the most thorough type checking:
#   no implicit Any, no untyped defs, no missing return types
# We check all source files (not test files, which use Any freely)
# ------------------------------------------------------------
echo "Step 2: mypy strict type checking"
echo "  Files: python/src/*.py"
echo ""

if python -m mypy python/src/ --strict --ignore-missing-imports --explicit-package-bases --no-error-summary 2>&1; then
    pass "mypy -- 0 type errors"
else
    fail "mypy -- type errors found"
fi

echo ""

# ------------------------------------------------------------
# STEP 3: ruff -- code style and lint
# ruff is much faster than flake8 and covers more rules.
# --select E,F,W selects: pycodestyle errors, pyflakes, warnings
# ------------------------------------------------------------
echo "Step 3: ruff lint"
echo "  Files: python/src/*.py python/tests/*.py python/examples/*.py"
echo ""

if python -m ruff check python/src/ python/tests/ python/examples/ --select E,F,W 2>&1; then
    pass "ruff -- 0 lint warnings"
else
    fail "ruff -- lint warnings found"
fi

echo ""

# ------------------------------------------------------------
# STEP 4: ctest -- C++ Google Tests (Week 1)
# We build first to make sure the C++ code is up to date,
# then run ctest from the build directory.
# ------------------------------------------------------------
echo "Step 4: C++ tests (ctest)"

BUILD_DIR="$PROJECT_ROOT/build"

if [ ! -d "$BUILD_DIR" ]; then
    echo "  Build directory not found -- running cmake first..."
    mkdir -p "$BUILD_DIR"
    cmake -S "$PROJECT_ROOT" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        > /dev/null 2>&1 || fail "cmake configuration failed"
fi

cmake --build "$BUILD_DIR" 2>&1 || fail "C++ build failed"

if (cd "$BUILD_DIR" && ctest --output-on-failure -q 2>&1); then
    pass "ctest -- all C++ tests"
else
    fail "ctest -- one or more C++ tests failed"
fi

echo ""

# ------------------------------------------------------------
# STEP 5: Syntax check all example scripts
# python -m py_compile is faster than ast.parse for this purpose.
# ------------------------------------------------------------
echo "Step 5: Example script syntax check"

EXAMPLES=(
    "python/examples/week1_coin_flip.py"
    "python/examples/week1_normal_demo.py"
    "python/examples/week2_battery_ode.py"
    "python/examples/week2_clt_demo.py"
)

ALL_OK=true
for f in "${EXAMPLES[@]}"; do
    if python -m py_compile "$f" 2>&1; then
        echo "    OK  $f"
    else
        echo "    FAIL  $f"
        ALL_OK=false
    fi
done

if $ALL_OK; then
    pass "syntax check -- all example scripts"
else
    fail "syntax check -- one or more example scripts have errors"
fi

echo ""
echo "============================================================"
echo -e "  ${GREEN}ALL TESTS PASSED${RESET}"
echo "  Week 1: 44 Python + 13 C++ tests"
echo "  Week 2: 27 (state ABC) + 40 (battery model) = 67 tests"
echo "  Total : 111 Python + 13 C++ = 124 tests"
echo "============================================================"
echo ""
