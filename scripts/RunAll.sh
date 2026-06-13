#!/usr/bin/env bash
# =============================================================================
# scripts/RunAll.sh
# =============================================================================
# Master runner for ProbOS Week 1.
# One command to: install dependencies, build C++, run tests, run examples.
#
# USAGE (from the project root directory):
#   chmod +x scripts/RunAll.sh
#   ./scripts/RunAll.sh
#
# WHAT IT DOES (in order):
#   Step 1:  Check system requirements (Python 3.11+, GCC/Clang, CMake, Ninja)
#   Step 2:  Create Python virtual environment (.venv)
#   Step 3:  Install Python dependencies from requirements.txt
#   Step 4:  Run Python tests via RunTests.sh
#   Step 5:  Build C++ code (cmake + ninja)
#   Step 6:  Run C++ tests via ctest
#   Step 7:  Run Python examples (coin flip, normal demo)
#   Step 8:  Run C++ demo (probos_main)
#   Step 9:  Print a final success/failure report
#
# EXIT CODES:
#   0 = everything succeeded
#   1 = one or more steps failed
#
# NOTE:
#   On first run this takes ~3-5 minutes (downloading Python packages).
#   On subsequent runs it takes ~30 seconds (packages already installed).
# =============================================================================

# --------------------------------------------------------------------------- #
# BASH SAFETY FLAGS (same as RunTests.sh)
# --------------------------------------------------------------------------- #
set -euo pipefail

# --------------------------------------------------------------------------- #
# COLOUR CODES
# --------------------------------------------------------------------------- #
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
CYAN='\033[1;36m'
RESET='\033[0m'

# --------------------------------------------------------------------------- #
# HELPER FUNCTIONS
# --------------------------------------------------------------------------- #

print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║       ProbOS Week 1 — Master Runner (RunAll.sh)         ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}  Step $1: $2${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

print_ok() {
    echo -e "${GREEN}  ✓ $1${RESET}"
}

print_err() {
    echo -e "${RED}  ✗ ERROR: $1${RESET}"
    if [[ -n "${2:-}" ]]; then
        echo -e "${RED}    → $2${RESET}"
    fi
}

print_warn() {
    echo -e "${YELLOW}  ⚠ WARNING: $1${RESET}"
}

print_info() {
    echo -e "${BLUE}  ℹ $1${RESET}"
}

print_cmd() {
    # Shows the command being run
    echo -e "${CYAN}  $ $1${RESET}"
}

# track_step: records whether each step succeeded.
# We use an array indexed by step number.
declare -A STEP_STATUS   # associative array: step_name -> "PASS" or "FAIL"

# --------------------------------------------------------------------------- #
# FIND THE PROJECT ROOT
# --------------------------------------------------------------------------- #
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

print_banner
echo -e "${WHITE}  Project root: ${PROJECT_ROOT}${RESET}"
echo -e "${WHITE}  Script:       ${BASH_SOURCE[0]}${RESET}"
echo -e "${WHITE}  Date:         $(date)${RESET}"

cd "${PROJECT_ROOT}"

# --------------------------------------------------------------------------- #
# STEP 1: CHECK SYSTEM REQUIREMENTS
# --------------------------------------------------------------------------- #
print_section "1" "Check System Requirements"

ALL_REQUIREMENTS_MET=true

# Python 3.11+
if command -v python3.11 &>/dev/null; then
    PY_CMD="python3.11"
    print_ok "Python 3.11: $(python3.11 --version)"
elif command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PY_MAJOR=$(python3 -c "import sys; print(sys.version_info.major)")
    PY_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")
    if [[ "$PY_MAJOR" -ge 3 ]] && [[ "$PY_MINOR" -ge 11 ]]; then
        PY_CMD="python3"
        print_ok "Python: $(python3 --version)"
    else
        print_warn "Python 3.11+ recommended, found Python ${PY_VERSION}."
        print_warn "The code may still work on 3.9+, but type annotations may differ."
        PY_CMD="python3"
    fi
else
    print_err "Python 3 not found" \
        "Install from https://python.org or: sudo apt-get install python3"
    ALL_REQUIREMENTS_MET=false
    PY_CMD="python3"
fi

# C++ compiler (GCC or Clang)
if command -v g++ &>/dev/null; then
    print_ok "C++ compiler: $(g++ --version | head -1)"
    CXX_AVAILABLE=true
elif command -v clang++ &>/dev/null; then
    print_ok "C++ compiler: $(clang++ --version | head -1)"
    CXX_AVAILABLE=true
else
    print_warn "No C++ compiler found."
    print_warn "C++ build will be skipped."
    print_warn "Install with: sudo apt-get install build-essential"
    CXX_AVAILABLE=false
fi

# CMake
if command -v cmake &>/dev/null; then
    print_ok "CMake: $(cmake --version | head -1)"
    CMAKE_AVAILABLE=true
else
    print_warn "CMake not found — C++ build will be skipped."
    print_warn "Install with: sudo apt-get install cmake"
    CMAKE_AVAILABLE=false
fi

# Ninja build system (faster than Make)
if command -v ninja &>/dev/null; then
    print_ok "Ninja: $(ninja --version)"
    NINJA_AVAILABLE=true
else
    print_warn "Ninja not found — will use default cmake generator."
    print_warn "Install with: sudo apt-get install ninja-build"
    NINJA_AVAILABLE=false
fi

# Google Test (optional — C++ tests depend on it)
if dpkg -l libgtest-dev 2>/dev/null | grep -q "^ii" 2>/dev/null; then
    print_ok "Google Test: installed (libgtest-dev)"
    GTEST_AVAILABLE=true
elif [[ -f "/usr/lib/libgtest.a" ]] || [[ -f "/usr/local/lib/libgtest.a" ]]; then
    print_ok "Google Test: found (libgtest.a)"
    GTEST_AVAILABLE=true
else
    print_warn "Google Test not found — C++ unit tests will be skipped."
    print_warn "Install with: sudo apt-get install -y libgtest-dev"
    GTEST_AVAILABLE=false
fi

if [[ "$ALL_REQUIREMENTS_MET" == "false" ]]; then
    print_err "Critical requirements not met. Cannot continue."
    exit 1
fi

STEP_STATUS["requirements"]="PASS"

# --------------------------------------------------------------------------- #
# STEP 2: CREATE PYTHON VIRTUAL ENVIRONMENT
# --------------------------------------------------------------------------- #
print_section "2" "Create Python Virtual Environment"

if [[ -d ".venv" ]]; then
    print_info "Virtual environment already exists (.venv)"
    print_info "To recreate it: rm -rf .venv && ./scripts/RunAll.sh"
else
    print_cmd "${PY_CMD} -m venv .venv"
    set +e
    ${PY_CMD} -m venv .venv 2>&1
    VENV_EXIT=$?
    set -e

    if [[ ${VENV_EXIT} -eq 0 ]]; then
        print_ok "Virtual environment created: .venv/"
    else
        print_err "Failed to create virtual environment" \
            "Check that python3-venv is installed: sudo apt-get install python3-venv"
        STEP_STATUS["venv"]="FAIL"
        # Continue anyway — maybe system Python has everything we need
    fi
fi

# Activate the virtual environment
if [[ -f ".venv/bin/activate" ]]; then
    # shellcheck source=/dev/null
    source .venv/bin/activate
    print_ok "Virtual environment activated"
    # After activation, 'python' and 'pip' point to .venv/bin/python and pip
    PYTHON="python"
    PIP="pip"
elif [[ -f ".venv/Scripts/activate" ]]; then
    # shellcheck source=/dev/null
    source .venv/Scripts/activate
    print_ok "Virtual environment activated (Windows)"
    PYTHON="python"
    PIP="pip"
else
    print_warn "Could not activate virtual environment — using system Python"
    PYTHON="${PY_CMD}"
    PIP="pip3"
fi

STEP_STATUS["venv"]="PASS"

# --------------------------------------------------------------------------- #
# STEP 3: INSTALL PYTHON DEPENDENCIES
# --------------------------------------------------------------------------- #
print_section "3" "Install Python Dependencies"

if [[ ! -f "requirements.txt" ]]; then
    print_err "requirements.txt not found" "Are you in the project root?"
    STEP_STATUS["pip"]="FAIL"
else
    print_cmd "pip install -r requirements.txt"
    echo ""

    # Upgrade pip silently first (old pip can cause confusing errors)
    ${PYTHON} -m pip install --upgrade pip --quiet

    set +e
    ${PYTHON} -m pip install -r requirements.txt 2>&1
    PIP_EXIT=$?
    set -e

    echo ""

    if [[ ${PIP_EXIT} -eq 0 ]]; then
        print_ok "All Python packages installed"
        STEP_STATUS["pip"]="PASS"
    else
        print_err "pip install failed" \
            "Check your internet connection and requirements.txt"
        STEP_STATUS["pip"]="FAIL"
    fi
fi

# --------------------------------------------------------------------------- #
# STEP 4: RUN PYTHON TESTS
# --------------------------------------------------------------------------- #
print_section "4" "Run Python Tests"

print_cmd "./scripts/RunTests.sh (Python suites only)"
echo ""

set +e
# Run only the Python suites (not C++ — we haven't built yet).
# We call pytest directly here rather than RunTests.sh to avoid duplication.
${PYTHON} -m pytest python/tests/ \
    -v \
    --tb=short \
    --no-header \
    2>&1
PY_TEST_EXIT=$?
set -e

echo ""
if [[ ${PY_TEST_EXIT} -eq 0 ]]; then
    print_ok "All Python tests passed"
    STEP_STATUS["python_tests"]="PASS"
else
    print_err "Python tests failed" \
        "Fix the failing tests before building C++."
    STEP_STATUS["python_tests"]="FAIL"
fi

# --------------------------------------------------------------------------- #
# STEP 5: BUILD C++ CODE
# --------------------------------------------------------------------------- #
print_section "5" "Build C++ Code"

if [[ "$CXX_AVAILABLE" == "false" ]] || [[ "$CMAKE_AVAILABLE" == "false" ]]; then
    print_warn "C++ build skipped (compiler or CMake not available)."
    STEP_STATUS["cpp_build"]="SKIP"
else
    # Determine the build generator (Ninja is faster, Make is fallback)
    if [[ "$NINJA_AVAILABLE" == "true" ]]; then
        CMAKE_GENERATOR="-G Ninja"
        BUILD_CMD="ninja"
    else
        CMAKE_GENERATOR=""
        BUILD_CMD="make -j$(nproc 2>/dev/null || echo 4)"
    fi

    # Create build directory if it doesn't exist
    if [[ ! -d "build" ]]; then
        mkdir -p build
        print_info "Created build/ directory"
    fi

    # Configure with CMake
    print_cmd "cmake .. ${CMAKE_GENERATOR} -DCMAKE_BUILD_TYPE=Debug"
    set +e
    (cd build && cmake .. ${CMAKE_GENERATOR} -DCMAKE_BUILD_TYPE=Debug 2>&1)
    CMAKE_EXIT=$?
    set -e

    if [[ ${CMAKE_EXIT} -ne 0 ]]; then
        print_err "CMake configuration failed" "See output above for details."
        STEP_STATUS["cpp_build"]="FAIL"
    else
        print_ok "CMake configuration succeeded"

        # Build with ninja or make
        print_cmd "(cd build && ${BUILD_CMD})"
        set +e
        (cd build && eval "${BUILD_CMD}" 2>&1)
        BUILD_EXIT=$?
        set -e

        if [[ ${BUILD_EXIT} -eq 0 ]]; then
            print_ok "C++ build succeeded"
            STEP_STATUS["cpp_build"]="PASS"
        else
            print_err "C++ build failed" "See compiler output above."
            STEP_STATUS["cpp_build"]="FAIL"
        fi
    fi
fi

# --------------------------------------------------------------------------- #
# STEP 6: RUN C++ TESTS
# --------------------------------------------------------------------------- #
print_section "6" "Run C++ Tests"

if [[ "${STEP_STATUS["cpp_build"]:-SKIP}" != "PASS" ]]; then
    print_warn "C++ tests skipped (build step did not pass)."
    STEP_STATUS["cpp_tests"]="SKIP"
elif ! command -v ctest &>/dev/null; then
    print_warn "ctest not found — skipping C++ tests."
    STEP_STATUS["cpp_tests"]="SKIP"
else
    # Check if any test executables were built
    TEST_EXE=$(find build -name "test_normal" -type f 2>/dev/null | head -1)

    if [[ -z "${TEST_EXE}" ]]; then
        print_warn "No C++ test executables found."
        print_warn "Google Test may not have been installed during cmake."
        print_warn "Install: sudo apt-get install -y libgtest-dev"
        print_warn "Then rebuild: rm -rf build && ./scripts/RunAll.sh"
        STEP_STATUS["cpp_tests"]="SKIP"
    else
        print_info "Found test executable: ${TEST_EXE}"
        print_cmd "(cd build && ctest --output-on-failure -V)"
        echo ""

        set +e
        (cd build && ctest --output-on-failure -V 2>&1)
        CTEST_EXIT=$?
        set -e

        echo ""
        if [[ ${CTEST_EXIT} -eq 0 ]]; then
            print_ok "All C++ tests passed"
            STEP_STATUS["cpp_tests"]="PASS"
        else
            print_err "C++ tests failed" "See test output above."
            STEP_STATUS["cpp_tests"]="FAIL"
        fi
    fi
fi

# --------------------------------------------------------------------------- #
# STEP 7: RUN PYTHON EXAMPLES
# --------------------------------------------------------------------------- #
print_section "7" "Run Python Examples"

run_python_example() {
    # Helper to run a single Python example.
    # $1 = path to the example file
    # $2 = description
    local FILE="$1"
    local DESC="$2"

    if [[ ! -f "${FILE}" ]]; then
        print_err "Example file not found: ${FILE}"
        return 1
    fi

    print_cmd "${PYTHON} ${FILE}"
    echo ""

    set +e
    ${PYTHON} "${FILE}" 2>&1
    local EXIT=$?
    set -e

    echo ""
    if [[ ${EXIT} -eq 0 ]]; then
        print_ok "${DESC}"
        return 0
    else
        print_err "${DESC} failed" "Exit code: ${EXIT}"
        return 1
    fi
}

ALL_EXAMPLES_PASSED=true

# Example 1: coin flip
echo -e "${YELLOW}── Example 1: Coin Flip (Law of Large Numbers) ──${RESET}"
if ! run_python_example \
    "python/examples/week1_coin_flip.py" \
    "Coin flip example (Law of Large Numbers)"; then
    ALL_EXAMPLES_PASSED=false
fi

echo ""
echo -e "${YELLOW}── Example 2: Normal Distribution (Battery Ea_SEI) ──${RESET}"
if ! run_python_example \
    "python/examples/week1_normal_demo.py" \
    "Normal distribution example (Battery Ea_SEI)"; then
    ALL_EXAMPLES_PASSED=false
fi

if [[ "${ALL_EXAMPLES_PASSED}" == "true" ]]; then
    STEP_STATUS["examples"]="PASS"
else
    STEP_STATUS["examples"]="FAIL"
fi

# --------------------------------------------------------------------------- #
# STEP 8: RUN C++ DEMO
# --------------------------------------------------------------------------- #
print_section "8" "Run C++ Demo"

if [[ "${STEP_STATUS["cpp_build"]:-SKIP}" != "PASS" ]]; then
    print_warn "C++ demo skipped (build step did not pass)."
    STEP_STATUS["cpp_demo"]="SKIP"
else
    # Find the probos_main executable
    MAIN_EXE=""
    if [[ -f "build/bin/probos_main" ]]; then
        MAIN_EXE="build/bin/probos_main"
    elif [[ -f "build/probos_main" ]]; then
        MAIN_EXE="build/probos_main"
    else
        MAIN_EXE=$(find build -name "probos_main" -type f 2>/dev/null | head -1)
    fi

    if [[ -z "${MAIN_EXE}" ]]; then
        print_err "probos_main executable not found" "Was the build successful?"
        STEP_STATUS["cpp_demo"]="FAIL"
    else
        print_cmd "${MAIN_EXE}"
        echo ""

        set +e
        "./${MAIN_EXE}" 2>&1
        DEMO_EXIT=$?
        set -e

        echo ""
        if [[ ${DEMO_EXIT} -eq 0 ]]; then
            print_ok "C++ demo completed successfully"
            STEP_STATUS["cpp_demo"]="PASS"
        else
            print_err "C++ demo failed" "Exit code: ${DEMO_EXIT}"
            STEP_STATUS["cpp_demo"]="FAIL"
        fi
    fi
fi

# --------------------------------------------------------------------------- #
# STEP 9: FINAL REPORT
# --------------------------------------------------------------------------- #
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║                    Final Report                         ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Tally pass/fail/skip
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

declare -A STEP_LABELS
STEP_LABELS["requirements"]="System Requirements"
STEP_LABELS["venv"]="Python Virtual Environment"
STEP_LABELS["pip"]="Python Dependencies"
STEP_LABELS["python_tests"]="Python Tests (pytest)"
STEP_LABELS["cpp_build"]="C++ Build"
STEP_LABELS["cpp_tests"]="C++ Tests (Google Test)"
STEP_LABELS["examples"]="Python Examples"
STEP_LABELS["cpp_demo"]="C++ Demo"

for KEY in requirements venv pip python_tests cpp_build cpp_tests examples cpp_demo; do
    STATUS="${STEP_STATUS[$KEY]:-SKIP}"
    LABEL="${STEP_LABELS[$KEY]}"

    if [[ "${STATUS}" == "PASS" ]]; then
        echo -e "  ${GREEN}✓ PASS${RESET}  ${LABEL}"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [[ "${STATUS}" == "FAIL" ]]; then
        echo -e "  ${RED}✗ FAIL${RESET}  ${LABEL}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        echo -e "  ${YELLOW}─ SKIP${RESET}  ${LABEL}"
        SKIP_COUNT=$((SKIP_COUNT + 1))
    fi
done

echo ""
echo -e "  Passed: ${GREEN}${PASS_COUNT}${RESET}   Failed: ${RED}${FAIL_COUNT}${RESET}   Skipped: ${YELLOW}${SKIP_COUNT}${RESET}"
echo ""

if [[ ${FAIL_COUNT} -eq 0 ]]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║                                                          ║${RESET}"
    echo -e "${GREEN}║   ✓  ALL STEPS PASSED — Week 1 is complete!             ║${RESET}"
    echo -e "${GREEN}║                                                          ║${RESET}"
    echo -e "${GREEN}║   Next steps:                                            ║${RESET}"
    echo -e "${GREEN}║   1. git add -A                                          ║${RESET}"
    echo -e "${GREEN}║   2. git commit -m 'feat(week1): Distribution ABC        ║${RESET}"
    echo -e "${GREEN}║                    Python + C++, 26 tests passing'       ║${RESET}"
    echo -e "${GREEN}║   3. git push origin week1/foundation                    ║${RESET}"
    echo -e "${GREEN}║   4. Open PR: week1/foundation → main                    ║${RESET}"
    echo -e "${GREEN}║                                                          ║${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║                                                          ║${RESET}"
    echo -e "${RED}║   ✗  ${FAIL_COUNT} STEP(S) FAILED — See details above               ║${RESET}"
    echo -e "${RED}║                                                          ║${RESET}"
    echo -e "${RED}║   How to debug:                                          ║${RESET}"
    echo -e "${RED}║   Python: pytest python/tests/ -v --tb=long             ║${RESET}"
    echo -e "${RED}║   C++:    cd build && ctest -V --output-on-failure       ║${RESET}"
    echo -e "${RED}║   Types:  mypy python/src/ --ignore-missing-imports      ║${RESET}"
    echo -e "${RED}║                                                          ║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    exit 1
fi
