#!/usr/bin/env bash
# =============================================================================
# check_ci.sh
# ProbOS -- permanent CI watcher script
#
# USAGE:
#   bash check_ci.sh              -- watch the most recent CI run on this branch
#   bash check_ci.sh <run-id>     -- watch a specific run by ID
#
# WHAT IT DOES:
#   1. Confirms gh CLI is authenticated (re-prompts if the token expired)
#   2. Finds the most recent workflow run for the current branch (or uses
#      the run-id passed as $1)
#   3. Watches it live until it completes
#   4. Prints a clear PASS/FAIL summary at the end
#   5. On failure, automatically shows the failed job's log so you don't
#      have to run a second command
#
# WHY THIS EXISTS:
#   gh auth tokens expire periodically (as happened June 19). This script
#   detects that case explicitly and tells you to re-authenticate, instead
#   of failing with a cryptic "Bad credentials" error days later.
# =============================================================================

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR" || exit 1

# -----------------------------------------------------------------------
# Step 1: confirm gh CLI is authenticated
# -----------------------------------------------------------------------
if ! gh auth status > /dev/null 2>&1; then
    echo "============================================================"
    echo "  gh CLI is not authenticated (token may have expired)"
    echo "============================================================"
    echo "  Run: gh auth login"
    echo "  Choose: GitHub.com -> HTTPS or SSH -> Paste an auth token"
    echo "  Generate a token at: https://github.com/settings/tokens"
    echo "  Minimum scopes needed: repo, read:org"
    echo "============================================================"
    exit 1
fi

# -----------------------------------------------------------------------
# Step 2: determine which run to watch
# -----------------------------------------------------------------------
RUN_ID="${1:-}"

if [ -z "$RUN_ID" ]; then
    echo "============================================================"
    echo "  Looking up most recent CI run..."
    echo "============================================================"
    RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')

    if [ -z "$RUN_ID" ] || [ "$RUN_ID" == "null" ]; then
        echo "ERROR: Could not find any workflow runs. Have you pushed yet?"
        exit 1
    fi
fi

echo "Watching run ID: $RUN_ID"
echo ""

# -----------------------------------------------------------------------
# Step 3: watch the run live until it completes
# -----------------------------------------------------------------------
gh run watch "$RUN_ID" --exit-status
WATCH_EXIT=$?

echo ""
echo "============================================================"

# -----------------------------------------------------------------------
# Step 4: print PASS/FAIL summary
# -----------------------------------------------------------------------
if [ "$WATCH_EXIT" -eq 0 ]; then
    echo "  CI RESULT: PASS -- all jobs succeeded"
    echo "============================================================"
    exit 0
else
    echo "  CI RESULT: FAIL -- at least one job failed"
    echo "============================================================"
    echo ""
    echo "  Showing failed job logs below:"
    echo "------------------------------------------------------------"
    gh run view "$RUN_ID" --log-failed
    echo "------------------------------------------------------------"
    echo ""
    echo "  Full run details: gh run view $RUN_ID"
    echo "  Open in browser:  gh run view $RUN_ID --web"
    exit 1
fi
