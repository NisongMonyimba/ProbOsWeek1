# =============================================================================
# RunProbOS.ps1 -- Windows PowerShell launcher for ProbOS
#
# WHAT THIS SCRIPT DOES:
#   Launches ProbOS scripts inside WSL (Windows Subsystem for Linux)
#   from Windows without needing to open a Linux terminal.
#
# HOW TO RUN:
#   1. Open File Explorer
#   2. Navigate to: \\wsl.localhost\Ubuntu-22.04\home\nison\ProbOsWeek1
#   3. Right-click RunProbOS.ps1
#   4. Click: Run with PowerShell
#
# WHAT YOU CAN RUN:
#   [1] RunAll.sh    -- Full pipeline (build + test + examples), 8 steps
#   [2] RunTests.sh  -- Tests only (pytest + mypy + ruff + ctest), ~30 seconds
#   [3] Both         -- RunAll.sh then RunTests.sh
#   [4] Exit
#
# REQUIREMENTS:
#   - WSL2 installed with Ubuntu 22.04
#   - ProbOS cloned to /home/nison/ProbOsWeek1 inside WSL
# =============================================================================

# -----------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------
$WSL_DISTRO  = "Ubuntu-22.04"
$PROJECT_DIR = "/home/nison/ProbOsWeek1"
$RUNALL      = "$PROJECT_DIR/scripts/RunAll.sh"
$RUNTESTS    = "$PROJECT_DIR/scripts/RunTests.sh"

# -----------------------------------------------------------------------
# Helper: run a bash script inside WSL and stream output live
# -----------------------------------------------------------------------
function Invoke-WSL {
    param([string]$ScriptPath, [string]$Label)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Running: $Label" -ForegroundColor Cyan
    Write-Host "  Script : $ScriptPath" -ForegroundColor Gray
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    # wsl.exe streams output live to the PowerShell window
    wsl -d $WSL_DISTRO -- bash -c "cd '$PROJECT_DIR' && chmod +x '$ScriptPath' && bash '$ScriptPath'"

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "  PASSED: $Label" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "  FAILED: $Label (exit code $LASTEXITCODE)" -ForegroundColor Red
    }
    return $LASTEXITCODE
}

# -----------------------------------------------------------------------
# Helper: check WSL is available
# -----------------------------------------------------------------------
function Test-WSL {
    $wslCheck = Get-Command wsl -ErrorAction SilentlyContinue
    if (-not $wslCheck) {
        Write-Host ""
        Write-Host "ERROR: WSL is not installed or not in PATH." -ForegroundColor Red
        Write-Host "Install WSL from: https://learn.microsoft.com/en-us/windows/wsl/install" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }

    $distroCheck = wsl -d $WSL_DISTRO -- echo "ok" 2>$null
    if ($distroCheck -ne "ok") {
        Write-Host ""
        Write-Host "ERROR: WSL distro '$WSL_DISTRO' not found." -ForegroundColor Red
        Write-Host "Available distros:" -ForegroundColor Yellow
        wsl --list --quiet
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# -----------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "============================================================" -ForegroundColor Blue
Write-Host "  ProbOS -- A Probabilistic Execution Runtime" -ForegroundColor Blue
Write-Host "  Reality Computing Corporation" -ForegroundColor Blue
Write-Host "============================================================" -ForegroundColor Blue
Write-Host ""
Write-Host "  Project : $PROJECT_DIR" -ForegroundColor Gray
Write-Host "  Distro  : $WSL_DISTRO" -ForegroundColor Gray
Write-Host ""
Write-Host "  Week 1: Distribution ABC -- 44 Python + 13 C++ tests" -ForegroundColor Gray
Write-Host "  Week 2: Model ABC + BatteryModel2Cell -- 67 Python tests" -ForegroundColor Gray
Write-Host "  Total : 111 Python + 13 C++ = 124 tests" -ForegroundColor Gray
Write-Host ""

# -----------------------------------------------------------------------
# Check WSL before showing menu
# -----------------------------------------------------------------------
Test-WSL

# -----------------------------------------------------------------------
# Menu loop
# -----------------------------------------------------------------------
do {
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  What would you like to run?" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1]  RunAll.sh    -- Full pipeline (8 steps)" -ForegroundColor Yellow
    Write-Host "         Build C++, run 124 tests, run all examples" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2]  RunTests.sh  -- Tests only (~30 seconds)" -ForegroundColor Yellow
    Write-Host "         pytest (111) + mypy + ruff + ctest (13)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3]  Both         -- RunAll.sh then RunTests.sh" -ForegroundColor Yellow
    Write-Host "         Full verification of everything" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [4]  Exit" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

    $choice = Read-Host "  Enter choice [1/2/3/4]"

    switch ($choice) {

        "1" {
            $exit_code = Invoke-WSL -ScriptPath $RUNALL -Label "RunAll.sh (Full Pipeline)"
            Write-Host ""
            if ($exit_code -eq 0) {
                Write-Host "  All 8 steps passed. Week 1 + Week 2 fully verified." -ForegroundColor Green
            }
        }

        "2" {
            $exit_code = Invoke-WSL -ScriptPath $RUNTESTS -Label "RunTests.sh (Test Suite)"
            Write-Host ""
            if ($exit_code -eq 0) {
                Write-Host "  All tests passed. 111 Python + 13 C++ = 124 total." -ForegroundColor Green
            }
        }

        "3" {
            Write-Host ""
            Write-Host "  Running RunAll.sh first, then RunTests.sh..." -ForegroundColor Cyan
            Write-Host ""

            $exit1 = Invoke-WSL -ScriptPath $RUNALL -Label "RunAll.sh (Full Pipeline)"

            if ($exit1 -eq 0) {
                $exit2 = Invoke-WSL -ScriptPath $RUNTESTS -Label "RunTests.sh (Test Suite)"

                Write-Host ""
                if ($exit2 -eq 0) {
                    Write-Host "============================================================" -ForegroundColor Green
                    Write-Host "  BOTH SCRIPTS PASSED -- Full verification complete" -ForegroundColor Green
                    Write-Host "  RunAll.sh  : 8/8 steps PASS" -ForegroundColor Green
                    Write-Host "  RunTests.sh: 5/5 steps PASS" -ForegroundColor Green
                    Write-Host "  Total tests: 111 Python + 13 C++ = 124" -ForegroundColor Green
                    Write-Host "============================================================" -ForegroundColor Green
                } else {
                    Write-Host "  RunTests.sh FAILED (exit code $exit2)" -ForegroundColor Red
                }
            } else {
                Write-Host "  RunAll.sh FAILED -- skipping RunTests.sh" -ForegroundColor Red
            }
        }

        "4" {
            Write-Host ""
            Write-Host "  Exiting ProbOS launcher." -ForegroundColor Gray
            Write-Host ""
            break
        }

        default {
            Write-Host ""
            Write-Host "  Invalid choice '$choice'. Please enter 1, 2, 3, or 4." -ForegroundColor Red
            Write-Host ""
        }
    }

    if ($choice -ne "4") {
        Write-Host ""
        Read-Host "  Press Enter to return to menu"
        Write-Host ""
    }

} while ($choice -ne "4")

Write-Host "  Done. You can close this window." -ForegroundColor Gray
Write-Host ""
