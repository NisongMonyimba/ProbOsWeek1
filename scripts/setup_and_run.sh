#!/usr/bin/env bash
# =============================================================================
# setup_and_run.sh
# =============================================================================
#
# PURPOSE:
#   This is the ONE script you run from your Ubuntu terminal.
#   It sets up your project folder, makes all scripts executable,
#   and then runs either RunAll.sh or RunTests.sh — your choice.
#
# YOUR FILE PATH (WSL Ubuntu):
#   Windows sees it as: \\wsl.localhost\Ubuntu-22.04\home\nison\ProbOsWeek1
#   Ubuntu sees it as:  /home/nison/ProbOsWeek1
#
# HOW TO USE:
#   Step 1 — Open Ubuntu terminal (from Windows search bar, type "Ubuntu")
#   Step 2 — Copy this script into your project folder:
#             /home/nison/ProbOsWeek1/setup_and_run.sh
#   Step 3 — Make it executable (only need to do this ONCE):
#             chmod +x /home/nison/ProbOsWeek1/setup_and_run.sh
#   Step 4 — Run it:
#             /home/nison/ProbOsWeek1/setup_and_run.sh
#
# WHAT HAPPENS WHEN YOU RUN IT:
#   1. Checks you are on Ubuntu (Linux)
#   2. Navigates to your project folder
#   3. Makes RunAll.sh and RunTests.sh executable
#   4. Asks you: run ALL steps, or run TESTS only?
#   5. Runs your choice and shows the results
#
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# BASH SAFETY FLAGS
# ─────────────────────────────────────────────────────────────────────────────
#
# These three flags make bash scripts safer. Without them, bash silently
# continues even when something goes wrong.
#
# -e   means "Exit Immediately on Error"
#      If ANY command fails (returns a non-zero exit code), the script stops.
#      Example: if 'cd /wrong/path' fails, the script stops right there.
#      Without -e: the script would keep running in the WRONG directory!
#
# -u   means "treat Undefined Variables as errors"
#      If you accidentally type $PROJECT_ROTT instead of $PROJECT_ROOT,
#      bash will stop and tell you — instead of silently using an empty string.
#
# -o pipefail  means "Pipeline Failure counts as overall failure"
#      A pipeline is commands connected by | (pipe), like: cat file | grep word
#      Normally, only the LAST command's exit code matters.
#      With pipefail, if ANY command in the pipeline fails, the whole thing fails.
#
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# COLOUR CODES FOR TERMINAL OUTPUT
# ─────────────────────────────────────────────────────────────────────────────
#
# These are ANSI escape sequences — special codes that tell the terminal
# to change the text colour.
#
# Format: \033[STYLE;COLOURm
#   \033   = the "escape" character (starts the sequence)
#   [      = marks the start of the code
#   1      = bold text
#   ;      = separator
#   32     = green colour (31=red, 33=yellow, 34=blue, 36=cyan, 37=white)
#   m      = marks the end of the code
#
# \033[0m  = RESET — goes back to the default terminal colour.
#            ALWAYS use this at the end of a coloured string, or every
#            subsequent line will also be that colour.
#
GREEN='\033[1;32m'    # Bold green  — used for SUCCESS messages
RED='\033[1;31m'      # Bold red    — used for ERROR messages
YELLOW='\033[1;33m'   # Bold yellow — used for WARNING messages
BLUE='\033[1;34m'     # Bold blue   — used for INFO messages
CYAN='\033[1;36m'     # Bold cyan   — used for headers / banners
WHITE='\033[1;37m'    # Bold white  — used for general text
RESET='\033[0m'       # Reset       — clears all colour/style

# ─────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────
#
# In bash, a function is defined like this:
#   function_name() {
#       command1
#       command2
#   }
#
# You call a function just by writing its name: print_banner
# You pass arguments after the name: print_ok "message here"
# Inside the function, $1 is the first argument, $2 is the second, etc.
#
# echo -e "text"   prints text to the screen
# The -e flag tells echo to INTERPRET special characters like \n (newline)
# and the \033 colour codes above.
#

print_banner() {
    # Prints the big title banner at the start of the script.
    # No arguments needed.
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                                                          ║${RESET}"
    echo -e "${CYAN}║        ProbOS Week 1 — Ubuntu Terminal Launcher          ║${RESET}"
    echo -e "${CYAN}║        Probabilistic Operating System                    ║${RESET}"
    echo -e "${CYAN}║                                                          ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_section() {
    # Prints a section divider with a title.
    # $1 = the section number (e.g. "1")
    # $2 = the section title (e.g. "Checking your system")
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}  [$1] $2${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

print_ok() {
    # Prints a green success message.
    # $1 = the success message
    # Example: print_ok "Project folder found"
    echo -e "${GREEN}  ✓  $1${RESET}"
}

print_err() {
    # Prints a red error message and EXITS THE SCRIPT.
    # $1 = what went wrong
    # $2 = how to fix it (optional second argument)
    #
    # "${2:-}" means: use $2 if it exists, otherwise use an empty string.
    # The :- is bash's "default value" operator.
    echo ""
    echo -e "${RED}  ✗  ERROR: $1${RESET}"
    if [[ -n "${2:-}" ]]; then
        # -n means "not empty" — only print the fix if one was provided
        echo -e "${RED}     HOW TO FIX: $2${RESET}"
    fi
    echo ""
    # exit 1 stops the script immediately.
    # Exit code 1 = general error (convention).
    # Exit code 0 = success (convention).
    exit 1
}

print_warn() {
    # Prints a yellow warning (does NOT stop the script).
    # $1 = the warning message
    echo -e "${YELLOW}  ⚠  WARNING: $1${RESET}"
}

print_info() {
    # Prints a blue informational message.
    # $1 = the info message
    echo -e "${BLUE}  ℹ  $1${RESET}"
}

print_step() {
    # Prints what command is about to run (so the user knows what is happening).
    # $1 = the command or action
    echo -e "${CYAN}  ▶  $1${RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
# DEFINE YOUR PROJECT PATH
# ─────────────────────────────────────────────────────────────────────────────
#
# This is THE most important variable in this script.
#
# YOUR WINDOWS PATH:  \\wsl.localhost\Ubuntu-22.04\home\nison\ProbOsWeek1
# YOUR UBUNTU PATH:   /home/nison/ProbOsWeek1
#
# Why are they different?
#   Windows uses backslashes (\) and drive letters (C:\).
#   Linux/Ubuntu uses forward slashes (/) and starts from root (/).
#   WSL (Windows Subsystem for Linux) maps your Ubuntu home folder
#   to \\wsl.localhost\Ubuntu-22.04\home\YOUR_USERNAME\
#
# In Ubuntu terminal, your project is always at:
#   /home/nison/ProbOsWeek1
#
# IMPORTANT: If your Ubuntu username is NOT "nison", change it below.
# To find your username, type in Ubuntu terminal: whoami
#
PROJECT_PATH="/home/nison/ProbOsWeek1"

# ─────────────────────────────────────────────────────────────────────────────
# START OF MAIN SCRIPT LOGIC
# ─────────────────────────────────────────────────────────────────────────────

print_banner

# Show the current date and time — useful for logging when the script ran
echo -e "${WHITE}  Date:    $(date)${RESET}"

# Show which operating system we are on.
# uname -s returns: Linux, Darwin (macOS), MINGW64_NT (Git Bash on Windows)
OS_NAME=$(uname -s)
echo -e "${WHITE}  OS:      ${OS_NAME}${RESET}"

# Show the current user
echo -e "${WHITE}  User:    $(whoami)${RESET}"

# Show the project path we will use
echo -e "${WHITE}  Project: ${PROJECT_PATH}${RESET}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: VERIFY WE ARE ON LINUX (WSL Ubuntu)
# ─────────────────────────────────────────────────────────────────────────────
print_section "1" "Verifying Operating System"

# Check that we are running on Linux.
# The scripts use Linux-specific tools (apt-get, ninja, etc.)
# Running on Windows directly (without WSL) will not work.
if [[ "${OS_NAME}" != "Linux" ]]; then
    print_err \
        "This script must run inside Ubuntu (WSL), not Windows directly." \
        "Open Ubuntu from the Windows start menu, then run this script."
fi

print_ok "Running on Linux (WSL Ubuntu) ✓"

# Check that we are the right user (nison).
# This is just informational — the script works for any user.
CURRENT_USER=$(whoami)
if [[ "${CURRENT_USER}" != "nison" ]]; then
    print_warn "Current user is '${CURRENT_USER}', expected 'nison'."
    print_warn "Updating PROJECT_PATH to use your actual username..."

    # Automatically fix the project path for the actual user.
    # $HOME is a built-in bash variable that always equals /home/YOUR_USERNAME
    # So /home/nison becomes /home/your_actual_username automatically.
    PROJECT_PATH="${HOME}/ProbOsWeek1"
    echo -e "${YELLOW}  Updated project path: ${PROJECT_PATH}${RESET}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2: CHECK THAT THE PROJECT FOLDER EXISTS
# ─────────────────────────────────────────────────────────────────────────────
print_section "2" "Checking Project Folder"

print_info "Looking for project at: ${PROJECT_PATH}"

# [[ -d "path" ]] tests whether a DIRECTORY exists at "path".
# -d = "is a directory"
# -f = "is a file" (used later)
# The ! in front means NOT — so [[ ! -d ... ]] means "if directory does NOT exist"
if [[ ! -d "${PROJECT_PATH}" ]]; then
    print_err \
        "Project folder not found: ${PROJECT_PATH}" \
        "Make sure you extracted the ZIP to /home/nison/ProbOsWeek1
         In Ubuntu terminal, run:
           ls /home/nison/
         You should see 'ProbOsWeek1' in the list.
         If not, copy the folder from Windows to Ubuntu:
           cp -r /mnt/c/Users/YOUR_WINDOWS_NAME/Downloads/probos-week1 /home/nison/ProbOsWeek1"
fi

print_ok "Project folder found: ${PROJECT_PATH}"

# List what is inside the folder so the user can verify it looks right
print_info "Contents of ${PROJECT_PATH}:"

# ls = list directory contents
# The 2>/dev/null part means: if ls fails (empty dir), don't show an error
ls "${PROJECT_PATH}" 2>/dev/null | while IFS= read -r LINE; do
    echo -e "${BLUE}      ${LINE}${RESET}"
done

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: NAVIGATE INTO THE PROJECT FOLDER
# ─────────────────────────────────────────────────────────────────────────────
print_section "3" "Navigating to Project Folder"

# cd = "change directory" — moves the terminal to a different folder.
# After this command, all relative paths (like scripts/RunAll.sh) will be
# relative to /home/nison/ProbOsWeek1.
print_step "cd ${PROJECT_PATH}"
cd "${PROJECT_PATH}"

# pwd = "print working directory" — shows where you are now.
CURRENT_DIR=$(pwd)
print_ok "Now in: ${CURRENT_DIR}"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: CHECK THAT THE SCRIPTS EXIST
# ─────────────────────────────────────────────────────────────────────────────
print_section "4" "Checking Script Files"

# -f "path" tests whether a FILE exists at "path".
# We check both scripts before trying to make them executable.

if [[ ! -f "scripts/RunAll.sh" ]]; then
    print_err \
        "scripts/RunAll.sh not found" \
        "Make sure you extracted all files from the ZIP.
         Expected location: ${PROJECT_PATH}/scripts/RunAll.sh"
fi
print_ok "scripts/RunAll.sh found"

if [[ ! -f "scripts/RunTests.sh" ]]; then
    print_err \
        "scripts/RunTests.sh not found" \
        "Make sure you extracted all files from the ZIP.
         Expected location: ${PROJECT_PATH}/scripts/RunTests.sh"
fi
print_ok "scripts/RunTests.sh found"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5: MAKE SCRIPTS EXECUTABLE
# ─────────────────────────────────────────────────────────────────────────────
print_section "5" "Making Scripts Executable"

# WHY DO WE NEED chmod?
# ---------------------
# When you copy files from Windows to Linux, they lose their "execute"
# permission. Linux requires you to EXPLICITLY mark a file as executable
# before you can run it as a program.
#
# chmod = "change mode" (permissions)
# +x    = add eXecute permission
# The file still exists — you are just telling Linux "this file is a program".
#
# Without this: you get "Permission denied" when trying to run the script.
# With this:    you can run it with ./scripts/RunAll.sh

print_step "chmod +x scripts/RunAll.sh"
chmod +x scripts/RunAll.sh
print_ok "scripts/RunAll.sh is now executable"

print_step "chmod +x scripts/RunTests.sh"
chmod +x scripts/RunTests.sh
print_ok "scripts/RunTests.sh is now executable"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6: CHECK FOR REQUIRED SYSTEM TOOLS
# ─────────────────────────────────────────────────────────────────────────────
print_section "6" "Checking Required Tools"

# command -v TOOL_NAME
# This checks whether a command is available on your system.
# It returns exit code 0 (success) if found, 1 (failure) if not found.
# We use &>/dev/null to suppress any output from this check.
# &>  redirects BOTH stdout (normal output) and stderr (error output)
# /dev/null is a special Linux "black hole" — anything written there disappears.

# ── Python 3 ─────────────────────────────────────────────────────────────────
if command -v python3 &>/dev/null; then
    # python3 --version prints something like "Python 3.11.2"
    PYTHON_VER=$(python3 --version 2>&1)
    print_ok "Python: ${PYTHON_VER}"
else
    print_warn "Python 3 not found."
    print_warn "Install it with: sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv"
    print_warn "The script will continue but Python tests will fail."
fi

# ── pip3 (Python package installer) ──────────────────────────────────────────
if command -v pip3 &>/dev/null; then
    PIP_VER=$(pip3 --version 2>&1 | cut -d' ' -f1-2)
    print_ok "pip: ${PIP_VER}"
else
    print_warn "pip3 not found."
    print_warn "Install it with: sudo apt-get install -y python3-pip"
fi

# ── GCC (C++ compiler) ───────────────────────────────────────────────────────
if command -v g++ &>/dev/null; then
    GCC_VER=$(g++ --version 2>&1 | head -1)
    print_ok "C++ compiler: ${GCC_VER}"
    CXX_FOUND=true
else
    print_warn "g++ (C++ compiler) not found."
    print_warn "Install it with: sudo apt-get install -y build-essential"
    CXX_FOUND=false
fi

# ── CMake (C++ build system generator) ───────────────────────────────────────
if command -v cmake &>/dev/null; then
    CMAKE_VER=$(cmake --version 2>&1 | head -1)
    print_ok "CMake: ${CMAKE_VER}"
    CMAKE_FOUND=true
else
    print_warn "cmake not found."
    print_warn "Install it with: sudo apt-get install -y cmake"
    CMAKE_FOUND=false
fi

# ── Ninja (fast C++ build tool) ───────────────────────────────────────────────
if command -v ninja &>/dev/null; then
    NINJA_VER=$(ninja --version 2>&1)
    print_ok "Ninja: version ${NINJA_VER}"
else
    print_warn "ninja not found (optional but speeds up C++ build)."
    print_warn "Install it with: sudo apt-get install -y ninja-build"
fi

# ── Google Test (C++ testing framework) ──────────────────────────────────────
# We check for the library file rather than a command.
# dpkg -l = list installed Debian packages
if dpkg -l libgtest-dev 2>/dev/null | grep -q "^ii" 2>/dev/null; then
    print_ok "Google Test: installed (libgtest-dev)"
else
    print_warn "libgtest-dev not found."
    print_warn "C++ tests will be built without Google Test."
    print_warn "Install it with: sudo apt-get install -y libgtest-dev"
fi

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 7: INSTALL MISSING TOOLS (OPTIONAL AUTO-INSTALL)
# ─────────────────────────────────────────────────────────────────────────────
print_section "7" "Optional: Install Missing System Dependencies"

# Ask the user if they want to auto-install missing tools.
# read -r -p "prompt" VAR    reads user input into variable VAR.
# -r prevents backslashes from being interpreted as escape sequences.
# -p lets us set the prompt text.
echo -e "${WHITE}  Some tools may be missing. Auto-install them now?${RESET}"
echo -e "${WHITE}  (This runs: sudo apt-get install -y python3 python3-pip${RESET}"
echo -e "${WHITE}   python3-venv build-essential cmake ninja-build libgtest-dev)${RESET}"
echo ""
echo -e "${YELLOW}  Type 'y' for YES (recommended on first run)${RESET}"
echo -e "${YELLOW}  Type 'n' for NO  (skip if tools are already installed)${RESET}"
echo -e "${YELLOW}  Press Enter to default to NO${RESET}"
echo ""

# The read command waits for user input.
# -r = raw mode (don't interpret backslashes)
# -p = prompt text shown to the user
# INSTALL_CHOICE = the variable that stores what the user typed
read -r -p "  Install missing tools? [y/N]: " INSTALL_CHOICE

# Convert to lowercase for easier comparison.
# ${INSTALL_CHOICE,,} is bash's "lowercase" string operation.
INSTALL_CHOICE="${INSTALL_CHOICE,,}"

if [[ "${INSTALL_CHOICE}" == "y" ]] || [[ "${INSTALL_CHOICE}" == "yes" ]]; then
    echo ""
    print_step "sudo apt-get update"
    # sudo = "Super User DO" — runs the command as administrator.
    # apt-get update = refresh the list of available packages.
    # -y = answer "yes" to all prompts (don't wait for user input).
    sudo apt-get update -y

    print_step "sudo apt-get install -y python3 python3-pip python3-venv build-essential cmake ninja-build libgtest-dev"
    sudo apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        build-essential \
        cmake \
        ninja-build \
        libgtest-dev

    print_ok "System dependencies installed."
else
    print_info "Skipping auto-install. Continuing with what is available."
fi

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 8: CHOOSE WHAT TO RUN
# ─────────────────────────────────────────────────────────────────────────────
print_section "8" "Choose What to Run"

echo ""
echo -e "${WHITE}  What do you want to do?${RESET}"
echo ""
echo -e "${GREEN}  [1]  RunAll.sh${RESET}   — Complete setup + build + tests + examples"
echo -e "${WHITE}       Use this on first run, or when you add new code.${RESET}"
echo -e "${WHITE}       Takes ~3-5 minutes on first run (downloads Python packages).${RESET}"
echo ""
echo -e "${CYAN}  [2]  RunTests.sh${RESET} — Run tests only (Python + C++)"
echo -e "${WHITE}       Use this when you are iterating and just want to check tests.${RESET}"
echo -e "${WHITE}       Takes ~30 seconds.${RESET}"
echo ""
echo -e "${YELLOW}  [3]  Both${RESET}        — Run RunTests.sh first, then RunAll.sh"
echo ""
echo -e "${RED}  [q]  Quit${RESET}         — Exit without running anything"
echo ""

# Wait for the user to type their choice and press Enter.
read -r -p "  Enter your choice [1/2/3/q]: " RUN_CHOICE

# Convert to lowercase
RUN_CHOICE="${RUN_CHOICE,,}"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 9: RUN THE CHOSEN SCRIPT(S)
# ─────────────────────────────────────────────────────────────────────────────
print_section "9" "Running Your Choice"

# ── Function to run a single script ──────────────────────────────────────────
run_script() {
    # Runs one of the project scripts and reports whether it passed or failed.
    # $1 = path to the script (relative to project root)
    # $2 = human-readable name for display

    local SCRIPT_PATH="$1"   # local = this variable only exists inside this function
    local SCRIPT_NAME="$2"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}  Running: ${SCRIPT_NAME}${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    # Check the script exists one more time (safety check)
    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        print_err "Script not found: ${SCRIPT_PATH}"
    fi

    # Check the script is executable
    if [[ ! -x "${SCRIPT_PATH}" ]]; then
        print_warn "${SCRIPT_PATH} is not executable. Fixing now..."
        chmod +x "${SCRIPT_PATH}"
        print_ok "Made executable: ${SCRIPT_PATH}"
    fi

    print_step "bash ${SCRIPT_PATH}"
    echo ""

    # ── Actually run the script ───────────────────────────────────────────────
    # We temporarily turn off "exit on error" (set +e) because we want to
    # CAPTURE whether the script failed, not exit immediately.
    # After capturing the exit code, we turn it back on (set -e).
    set +e
    bash "${SCRIPT_PATH}"
    local SCRIPT_EXIT=$?   # $? = the exit code of the last command (0=success, 1+=failure)
    set -e

    # Report the result
    echo ""
    if [[ ${SCRIPT_EXIT} -eq 0 ]]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "${GREEN}  ✓  ${SCRIPT_NAME} COMPLETED SUCCESSFULLY${RESET}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        return 0   # function succeeded
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "${RED}  ✗  ${SCRIPT_NAME} FAILED (exit code: ${SCRIPT_EXIT})${RESET}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo ""
        echo -e "${YELLOW}  How to debug:${RESET}"
        echo -e "${YELLOW}  1. Read the output above — the error message is there.${RESET}"
        echo -e "${YELLOW}  2. For Python errors: look for 'FAILED' in red.${RESET}"
        echo -e "${YELLOW}  3. For C++ errors: look for 'error:' lines from the compiler.${RESET}"
        echo -e "${YELLOW}  4. Run again with more detail:${RESET}"
        echo -e "${YELLOW}     cd ${PROJECT_PATH}${RESET}"
        echo -e "${YELLOW}     pytest python/tests/ -v --tb=long   # Python${RESET}"
        echo -e "${YELLOW}     cd build && ctest -V                 # C++${RESET}"
        return 1   # function failed
    fi
}

# ── Execute the user's choice ─────────────────────────────────────────────────
# We use a case statement (like a switch in other languages) to handle
# the different choices.

# Track overall success across both scripts if running [3]
OVERALL_SUCCESS=true

case "${RUN_CHOICE}" in

    "1")
        # Run RunAll.sh — the full setup, build, and test pipeline
        if ! run_script "scripts/RunAll.sh" "RunAll.sh (Full Pipeline)"; then
            OVERALL_SUCCESS=false
        fi
        ;;

    "2")
        # Run RunTests.sh — tests only
        if ! run_script "scripts/RunTests.sh" "RunTests.sh (Tests Only)"; then
            OVERALL_SUCCESS=false
        fi
        ;;

    "3")
        # Run both in sequence
        print_info "Running RunTests.sh first, then RunAll.sh..."

        if ! run_script "scripts/RunTests.sh" "RunTests.sh (Tests Only)"; then
            OVERALL_SUCCESS=false
            echo ""
            echo -e "${YELLOW}  RunTests.sh failed. Continuing to RunAll.sh anyway...${RESET}"
        fi

        echo ""
        echo -e "${BLUE}  ── Now running RunAll.sh ──${RESET}"

        if ! run_script "scripts/RunAll.sh" "RunAll.sh (Full Pipeline)"; then
            OVERALL_SUCCESS=false
        fi
        ;;

    "q" | "quit" | "exit")
        echo ""
        echo -e "${YELLOW}  Quitting without running anything.${RESET}"
        echo -e "${WHITE}  To run later:${RESET}"
        echo -e "${WHITE}    cd ${PROJECT_PATH}${RESET}"
        echo -e "${WHITE}    ./scripts/RunAll.sh${RESET}"
        echo -e "${WHITE}    # or:${RESET}"
        echo -e "${WHITE}    ./scripts/RunTests.sh${RESET}"
        echo ""
        exit 0
        ;;

    *)
        # * matches anything not matched above (unknown input)
        print_warn "Unknown choice: '${RUN_CHOICE}'. Running RunAll.sh by default."
        if ! run_script "scripts/RunAll.sh" "RunAll.sh (Full Pipeline)"; then
            OVERALL_SUCCESS=false
        fi
        ;;

esac

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 10: FINAL SUMMARY AND NEXT STEPS
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║                    Session Complete                      ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${WHITE}  Project location (Ubuntu): ${PROJECT_PATH}${RESET}"
echo -e "${WHITE}  Project location (Windows): \\\\wsl.localhost\\Ubuntu-22.04\\home\\nison\\ProbOsWeek1${RESET}"
echo ""

if [[ "${OVERALL_SUCCESS}" == "true" ]]; then
    echo -e "${GREEN}  ✓  Everything completed successfully!${RESET}"
    echo ""
    echo -e "${WHITE}  ── Useful commands for next time ──${RESET}"
    echo ""
    echo -e "${BLUE}  # Navigate to project (always start here)${RESET}"
    echo -e "${WHITE}  cd ${PROJECT_PATH}${RESET}"
    echo ""
    echo -e "${BLUE}  # Run ALL steps (install + build + test + demos)${RESET}"
    echo -e "${WHITE}  ./scripts/RunAll.sh${RESET}"
    echo ""
    echo -e "${BLUE}  # Run TESTS only (fast, ~30 seconds)${RESET}"
    echo -e "${WHITE}  ./scripts/RunTests.sh${RESET}"
    echo ""
    echo -e "${BLUE}  # Run a single Python test file with details${RESET}"
    echo -e "${WHITE}  source .venv/bin/activate${RESET}"
    echo -e "${WHITE}  pytest python/tests/test_distributions.py -v --tb=long${RESET}"
    echo ""
    echo -e "${BLUE}  # Run C++ tests directly${RESET}"
    echo -e "${WHITE}  cd build && ctest -V --output-on-failure && cd ..${RESET}"
    echo ""
    echo -e "${BLUE}  # Run a Python example${RESET}"
    echo -e "${WHITE}  source .venv/bin/activate${RESET}"
    echo -e "${WHITE}  python python/examples/week1_coin_flip.py${RESET}"
    echo -e "${WHITE}  python python/examples/week1_normal_demo.py${RESET}"
    echo ""
    echo -e "${BLUE}  # Run the C++ demo${RESET}"
    echo -e "${WHITE}  ./build/bin/probos_main${RESET}"
    echo ""
    echo -e "${GREEN}  ── Week 2 will add: BatteryModel2Cell ODE ──${RESET}"
    echo ""
else
    echo -e "${RED}  ✗  One or more steps failed.${RESET}"
    echo ""
    echo -e "${WHITE}  ── Debug checklist ──${RESET}"
    echo ""
    echo -e "${YELLOW}  1. Did pip install succeed?${RESET}"
    echo -e "${WHITE}     source .venv/bin/activate${RESET}"
    echo -e "${WHITE}     pip install -r requirements.txt${RESET}"
    echo ""
    echo -e "${YELLOW}  2. Do Python tests fail?${RESET}"
    echo -e "${WHITE}     source .venv/bin/activate${RESET}"
    echo -e "${WHITE}     pytest python/tests/ -v --tb=long${RESET}"
    echo ""
    echo -e "${YELLOW}  3. Does C++ not compile?${RESET}"
    echo -e "${WHITE}     sudo apt-get install -y build-essential cmake ninja-build libgtest-dev${RESET}"
    echo -e "${WHITE}     rm -rf build && mkdir build && cd build${RESET}"
    echo -e "${WHITE}     cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Debug${RESET}"
    echo -e "${WHITE}     ninja${RESET}"
    echo ""
    echo -e "${YELLOW}  4. Are scripts giving 'Permission denied'?${RESET}"
    echo -e "${WHITE}     chmod +x scripts/RunAll.sh scripts/RunTests.sh${RESET}"
    echo ""
    # Exit with failure code so the terminal shows the script failed
    exit 1
fi
