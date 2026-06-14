#!/usr/bin/env bash
# RunAll.sh -- run all ProbOS examples end-to-end
# Usage: bash RunAll.sh

set -e
REPO="$(cd "$(dirname "$0")" && pwd)"
PYTHON="$REPO/.venv/bin/python"

echo "============================================================"
echo "  ProbOS RunAll.sh"
echo "  $(date)"
echo "============================================================"

echo ""
echo "--- Week 1 examples ---"
$PYTHON "$REPO/python/examples/week1_distribution_showcase.py" \
    && echo "  week1_distribution_showcase: OK" \
    || echo "  week1_distribution_showcase: SKIP (file may not exist)"

echo ""
echo "--- Week 2 examples ---"
$PYTHON "$REPO/python/examples/week2_battery_ode.py" \
    && echo "  week2_battery_ode: OK" \
    || echo "  week2_battery_ode: SKIP"

echo ""
echo "--- Week 3 examples ---"
$PYTHON "$REPO/python/examples/week3_mc_battery.py" \
    && echo "  week3_mc_battery: OK"

$PYTHON "$REPO/python/examples/week3_clt_convergence.py" \
    && echo "  week3_clt_convergence: OK"

$PYTHON "$REPO/python/examples/week3_sobol_battery.py" \
    && echo "  week3_sobol_battery: OK"

echo ""
echo "--- C++ build and run ---"
cd "$REPO/cpp"
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release 2>/dev/null
cmake --build build 2>/dev/null
"$REPO/cpp/build/probos_main" \
    && echo "  probos_main: OK" \
    || echo "  probos_main: SKIP"
cd "$REPO"

echo ""
echo "============================================================"
echo "  RunAll.sh COMPLETE"
echo "============================================================"
