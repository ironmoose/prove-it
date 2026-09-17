#!/usr/bin/env bash
# exempt-folders.test.sh: TDD regression test for config.json's exempt_folders
# support in gate-check.sh (the PreToolUse quality-gate hook). Self-contained,
# no external test framework: prints one PASS/FAIL line per case and exits
# non-zero if any case failed.
#
# This test points gate-check.sh at a scratch GATE_DIR via the
# PROVE_IT_GATE_DIR env override (see gate-check.sh's GATE_DIR line), so it
# never touches the real ~/.claude/prove-it/ state.
#
# The scratch root is created under $HOME/.cache rather than via a bare
# mktemp -d (which defaults under /tmp) for two reasons: gate-check.sh has
# pre-existing, unrelated built-in exemptions for anything under /tmp/* and
# for anything under GATE_DIR itself. If the "project" files this test edits
# resolved under either of those, they would be auto-allowed by those
# built-ins regardless of the exempt_folders feature under test, and the
# test would pass or fail for the wrong reason. The gate dir and the project
# dir are kept as SIBLING directories under the scratch root so neither one
# is nested inside the other.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_CHECK="$SCRIPT_DIR/../gate-check.sh"

FAIL_COUNT=0

BASE_DIR="$HOME/.cache"
mkdir -p "$BASE_DIR"
T="$(mktemp -d "$BASE_DIR/exempt-folders-test.XXXXXX")"
T="$(realpath "$T")"
cleanup() {
    rm -rf "$T"
}
trap cleanup EXIT

GATE_DIR_PATH="$T/gatedir"
PROJ_DIR="$T/proj"
mkdir -p "$GATE_DIR_PATH" "$PROJ_DIR/notes" "$PROJ_DIR/src" "$PROJ_DIR/notes-ideas"

export PROVE_IT_GATE_DIR="$GATE_DIR_PATH"

NOTES_FILE="$PROJ_DIR/notes/a.md"
SRC_FILE="$PROJ_DIR/src/b.py"
NOTES_IDEAS_FILE="$PROJ_DIR/notes-ideas/c.md"

: > "$NOTES_FILE"
: > "$SRC_FILE"
: > "$NOTES_IDEAS_FILE"

cat > "$GATE_DIR_PATH/gate-state.json" <<EOF
{"status":"findings-open","findings":[{"id":"F1","file":"$NOTES_FILE"},{"id":"F2","file":"$SRC_FILE"},{"id":"F3","file":"$NOTES_IDEAS_FILE"}]}
EOF

write_config() {
    printf '{"exempt_folders": ["notes"]}' > "$GATE_DIR_PATH/config.json"
}

remove_config() {
    rm -f "$GATE_DIR_PATH/config.json"
}

# Runs gate-check.sh as a PreToolUse Edit hook against the given target
# file path, capturing stdout and exit code into OUT / EXIT_CODE.
run_gate_check() {
    local target_file="$1"
    local payload
    payload="$(jq -n --arg fp "$target_file" '{tool_name: "Edit", tool_input: {file_path: $fp}}')"
    OUT="$(printf '%s' "$payload" | "$GATE_CHECK")"
    EXIT_CODE=$?
}

is_deny() {
    printf '%s' "$OUT" | grep -qi 'permissionDecision.*deny'
}

report() {
    local name="$1"
    local passed="$2"
    if [ "$passed" -eq 1 ]; then
        echo "PASS: $name"
    else
        echo "FAIL: $name"
        echo "  exit code: $EXIT_CODE"
        echo "  output: $OUT"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# --- Case 1: config.json exempts "notes"; editing the notes file must be
# --- ALLOWED even though F1 is an open, unverified finding on that exact
# --- file -- this proves exempt_folders overrides the coverage-deny check.
write_config
run_gate_check "$NOTES_FILE"
if [ "$EXIT_CODE" -eq 0 ] && ! is_deny; then
    report "case1_notes_exempt_allows_edit" 1
else
    report "case1_notes_exempt_allows_edit" 0
fi

# --- Case 2: same config.json, but the target file (src/b.py) is not under
# --- any exempt folder and has its own open finding F2 -- must be DENIED,
# --- and the denial must name F2.
run_gate_check "$SRC_FILE"
if is_deny && printf '%s' "$OUT" | grep -q 'F2'; then
    report "case2_non_exempt_file_denied" 1
else
    report "case2_non_exempt_file_denied" 0
fi

# --- Case 3: remove config.json entirely and re-run the exact same edit as
# --- case 1. This must now be DENIED -- proving Case 1's ALLOW came from
# --- config.json's exempt_folders, not a coincidental match against the
# --- built-in /tmp or GATE_DIR exemptions.
remove_config
run_gate_check "$NOTES_FILE"
if is_deny; then
    report "case3_without_config_notes_denied" 1
else
    report "case3_without_config_notes_denied" 0
fi

# --- Case 4 (negative-anchor): config.json restored with exempt_folders:
# --- ["notes"]. A file under "notes-ideas/" must NOT match "notes" -- proves
# --- the match is an anchored path-component match, not a substring match.
# --- F3's open finding on this exact file is what makes a DENY here
# --- meaningful: without it, the file would be allowed regardless of
# --- exempt_folders, since the gate only denies files with an open finding.
write_config
run_gate_check "$NOTES_IDEAS_FILE"
if is_deny && printf '%s' "$OUT" | grep -q 'F3'; then
    report "case4_negative_anchor_notes_ideas_denied" 1
else
    report "case4_negative_anchor_notes_ideas_denied" 0
fi

echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "ALL CASES PASSED"
    exit 0
else
    echo "$FAIL_COUNT CASE(S) FAILED"
    exit 1
fi
