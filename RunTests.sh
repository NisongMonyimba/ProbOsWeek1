#!/usr/bin/env bash
# RunTests.sh -- run all ProbOS tests (Python + C++)
# Usage: bash RunTests.sh

set -e
REPO="$(cd "$(dirname "$0")" && pwd)"
PYTHON="$REPO/.venv/bin/python"

echo "============================================================"
echo "  ProbOS RunTests.sh"
echo "  $(date)"
echo "============================================================"

echo ""
echo "--- Python tests ---"
$PYTHON -m pytest "$REPO/python/tests/" -v --tb=short --no-header
PYTEST_EXIT=$?
echo "pytest exit: $PYTEST_EXIT"

echo ""
echo "--- mypy (all src) ---"
$PYTHON -m mypy \
    "$REPO/python/src/distributions.py" \
    "$REPO/python/src/state.py" \
    "$REPO/python/src/battery_model.py" \
    "$REPO/python/src/monte_carlo.py" \
    "$REPO/python/src/sensitivity.py" \
    "$REPO/python/src/provenance.py" \
    --strict --ignore-missing-imports \
    --explicit-package-bases --no-error-summary
MYPY_EXIT=$?
echo "mypy exit: $MYPY_EXIT"

echo ""
echo "--- ruff (src + tests) ---"
$PYTHON -m ruff check \
    "$REPO/python/src/" \
    "$REPO/python/tests/" \
    --select E,F,W
RUFF_EXIT=$?
echo "ruff exit: $RUFF_EXIT"

echo ""
echo "--- C++ tests ---"
cd "$REPO/cpp"
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release 2>/dev/null
cmake --build build 2>/dev/null
"$REPO/cpp/build/test_normal" --gtest_brief=1
CPP_EXIT=$?
echo "cpp exit: $CPP_EXIT"
cd "$REPO"

echo ""
echo "============================================================"
TOTAL=$((PYTEST_EXIT + MYPY_EXIT + RUFF_EXIT + CPP_EXIT))
if [ $TOTAL -eq 0 ]; then
    echo "  ALL TESTS PASSED"
else
    echo "  SOME TESTS FAILED (pytest=$PYTEST_EXIT mypy=$MYPY_EXIT ruff=$RUFF_EXIT cpp=$CPP_EXIT)"
fi
echo "============================================================"
exit $TOTAL
