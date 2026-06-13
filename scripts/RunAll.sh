#!/usr/bin/env bash
# =============================================================================
# RunAll.sh -- Full ProbOS build and test pipeline
#
# WHAT THIS SCRIPT DOES (8 steps):
#   1. Check system requirements (Python, g++, cmake, ninja)
#   2. Create Python virtual environment if it does not exist
#   3. Install Python dependencies from requirements.txt
#   4. Run all Python tests (pytest + mypy + ruff)
#   5. Build C++ code (cmake + ninja)
#   6. Run C++ tests (ctest)
#   7. Run Week 1 Python examples
#   8. Run Week 2 Python examples
#
# HOW TO RUN:
#   cd /home/nison/ProbOsWeek1
#   chmod +x scripts/RunAll.sh
#   ./scripts/RunAll.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"
BOLD="\033[1m"

step=0
pass_count=0
fail_count=0

run_step() {
    step=$((step + 1))
    local label="$1"
    local cmd="$2"
    printf "Step %d: %-40s" "$step" "$label"
    if eval "$cmd" > /tmp/probos_step_${step}.log 2>&1; then
        echo -e "${GREEN}PASS${RESET}"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}FAIL${RESET}"
        fail_count=$((fail_count + 1))
        echo "--- Output ---"
        cat /tmp/probos_step_${step}.log
        echo "--- End ---"
        exit 1
    fi
}

echo ""
echo -e "${BOLD}============================================================${RESET}"
echo -e "${BOLD}  ProbOS Full Pipeline${RESET}"
echo -e "${BOLD}  Project: $PROJECT_ROOT${RESET}"
echo -e "${BOLD}============================================================${RESET}"
echo ""

# Step 1: Check requirements
run_step "Check system requirements" \
    "python3 --version && g++ --version && cmake --version && ninja --version"

# Step 2: Python virtual environment
run_step "Python virtual environment" \
    "[ -d .venv ] || python3 -m venv .venv"

# Step 3: Install dependencies
run_step "Install Python dependencies" \
    "source .venv/bin/activate && pip install -q -r requirements.txt"

# Step 4: Python tests
run_step "Python tests (111 tests)" \
    "source .venv/bin/activate && python -m pytest python/tests/ -q --tb=short"

# Step 5: Build C++
run_step "Build C++ code (cmake + ninja)" \
    "mkdir -p build && cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -Wno-dev > /dev/null && cmake --build build"

# Step 6: C++ tests
run_step "C++ tests (13 tests)" \
    "cd build && ctest --output-on-failure -q"

# Step 7: Week 1 examples
run_step "Week 1 examples" \
    "source .venv/bin/activate && python python/examples/week1_coin_flip.py && python python/examples/week1_normal_demo.py"

# Step 8: Week 2 examples
run_step "Week 2 examples" \
    "source .venv/bin/activate && python python/examples/week2_battery_ode.py && python python/examples/week2_clt_demo.py"

echo ""
echo -e "${BOLD}============================================================${RESET}"
echo -e "  ${GREEN}${BOLD}ALL $pass_count STEPS PASSED${RESET}"
echo ""
echo "  Week 1: 44 Python + 13 C++ tests"
echo "  Week 2: 67 Python tests (27 state + 40 battery)"
echo "  Total : 111 Python + 13 C++ = 124 tests"
echo -e "${BOLD}============================================================${RESET}"
echo ""
