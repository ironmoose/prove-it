#!/usr/bin/env bash
# prove-it quality gate: PreToolUse hook (gate-check.sh)
#
# Reads a PreToolUse payload on stdin and decides whether to allow or deny
# the pending edit based on ~/.claude/prove-it/gate-state.json /
# gate-verdicts.json. Always exits 0, the decision is conveyed via the
# printed JSON (permissionDecision: deny) or by printing nothing (allow).
#
# FAILS OPEN: any internal error (missing jq, malformed JSON, unexpected
# exception) allows the edit through. This script must never be the reason
# a user's own editing gets stuck.
#
# A finding is only "covered" once a verification (prove-it-gate verify) has
# recorded a Confirmed or Proven-safe status for it. A Confirmed verification
# is bound to a SHA-256 digest of the file it was verified against, if that
# file changes afterward, the digest no longer matches and the gate re-closes
# for that file until it is re-verified. Proven-safe verifications drop the
# finding outright (no fix is being authorized) and are exempt from the
# digest check.
#
# FILE-SCOPED BLOCKING: gate-state.json / gate-verdicts.json are MACHINE-WIDE
# (no per-repo or per-session scoping), so the deny check below is scoped to
# the file the pending edit actually targets. An edit is denied ONLY when
# that specific file still has an unverified finding (or a Confirmed finding
# whose file changed since verification, per the digest-binding check
# further down). Editing any file the gate holds no open finding on is
# allowed even while the gate is open overall, so one session's open gate
# never freezes edits in an unrelated file, repo, worktree, or another
# tool's concurrent session sharing this machine's state.
#
# LOCKING: reads of gate-state.json / gate-verdicts.json below take a SHARED
# flock on the same GATE_DIR/gate.lock that prove-it-gate uses, so this hook
# never reads the pair mid one of prove-it-gate's read-modify-write spans (e.g.
# between `open` writing gate-state.json and removing gate-verdicts.json).
# The wait is bounded to 2 seconds, not indefinite, and on timeout, or if
# `flock` (util-linux; absent on stock macOS) is not on PATH, this hook
# proceeds WITHOUT the lock rather than deny or hang. That is a deliberate
# consequence of FAILS OPEN above: a lock is a new way for this hook to get
# stuck, and getting stuck is worse than the rare stale read an unlocked
# fallback risks. See prove-it-gate's own header for the fuller design writeup;
# both files were fixed together on 2026-08-26 (previously undocumented as a
# known, unfixed limitation, see gate/README.md history).

GATE_DIR="$HOME/.claude/prove-it"
STATE_FILE="$GATE_DIR/gate-state.json"
VERDICTS_FILE="$GATE_DIR/gate-verdicts.json"

# --- helper: fail-open exit -------------------------------------------------
fail_open() {
    local reason="$1"
    if [ -n "$reason" ]; then
        printf '{"systemMessage": "prove-it gate: could not evaluate gate state, allowing edit (fail-open). %s"}\n' "$reason"
    fi
    exit 0
}

# --- guard: jq must exist ---------------------------------------------------
command -v jq >/dev/null 2>&1 || fail_open "jq not found on PATH."

# --- read stdin --------------------------------------------------------------
INPUT="$(cat)" || fail_open "could not read stdin."
[ -n "$INPUT" ] || fail_open "empty stdin."

printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || fail_open "stdin was not valid JSON."

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)" || fail_open "could not extract tool_name."
FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)" || fail_open "could not extract file_path."

# --- EXEMPT PATHS ------------------------------------------------------------
GATE_DIR_EXPANDED="$HOME/.claude/prove-it"
if [ -n "$FILE_PATH" ]; then
    case "$FILE_PATH" in
        "$GATE_DIR_EXPANDED"/*|"$GATE_DIR_EXPANDED")
            exit 0
            ;;
        /tmp/*)
            exit 0
            ;;
        */scratchpad|*/scratchpad/*)
            exit 0
            ;;
    esac
fi

# --- no gate state file at all => allow -------------------------------------
[ -f "$STATE_FILE" ] || exit 0

# --- best-effort shared lock (see LOCKING note in the header) --------------
# Bounded wait only. Failure to acquire (timeout, or no flock on PATH) is
# NOT a fail_open condition -- it does not exit here, it just proceeds to
# read the state files without the lock, same as before this was added.
GATE_LOCK="$GATE_DIR/gate.lock"
if command -v flock >/dev/null 2>&1; then
    if exec 200>>"$GATE_LOCK" 2>/dev/null; then
        flock -w 2 -s 200 2>/dev/null
    fi
fi

STATUS="$(jq -r '.status // empty' "$STATE_FILE" 2>/dev/null)" || fail_open "could not parse gate-state.json."
[ "$STATUS" = "findings-open" ] || exit 0

# --- file-scoped coverage check: every finding ON THIS FILE must have a  ---
# --- Confirmed or Proven-safe verification entry (Inconclusive, or no    ---
# --- entry at all, does NOT count). Findings on OTHER files never deny   ---
# --- this edit -- see the FILE-SCOPED BLOCKING note in the file header.  ---
# --- Cannot scope without a target file, so allow rather than guess.     ---
[ -n "$FILE_PATH" ] || exit 0

TARGET_FILE="$(realpath -m "$FILE_PATH" 2>/dev/null || printf '%s' "$FILE_PATH")"

# gate-verdicts.json may legitimately not exist yet (nothing verified so
# far); jq errors on a --slurpfile of a missing path, which would otherwise
# spuriously fail_open on every edit once the old "no verdicts file at all"
# branch above is gone. Fall back to /dev/null (an empty slurp) instead.
MISSING_IDS="$(jq -r -n \
    --slurpfile state "$STATE_FILE" \
    --slurpfile verdicts "$([ -f "$VERDICTS_FILE" ] && echo "$VERDICTS_FILE" || echo /dev/null)" \
    --arg target "$TARGET_FILE" \
    '
    ($state[0].findings // []) as $findings
    | ($verdicts[0].verdicts // []) as $vs
    | [ $findings[] | select(.file == $target) | .id as $fid
        | select(
            ([$vs[] | select(.id == $fid and (.status == "Confirmed" or .status == "Proven-safe"))] | length) == 0
          )
        | $fid
      ]
    | join(", ")
    ' 2>/dev/null)" || fail_open "could not evaluate finding coverage for this file."

if [ -n "$MISSING_IDS" ]; then
    REASON="A quality gate is open with unverified finding(s) on this file ($TARGET_FILE): $MISSING_IDS. Run \`prove-it-gate verify <id> --repro <path>\` for each (add --proven-safe if the repro proves the code is safe instead of confirming the defect)."
    SYS_MSG="prove-it gate: blocking edit to this file, unverified findings ($MISSING_IDS). Run \`prove-it-gate verify <id> --repro <path> [--proven-safe]\`, or use \`prove-it-gate override --reason \"...\"\` to bypass."
    jq -n --arg reason "$REASON" --arg sysmsg "$SYS_MSG" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}, systemMessage: $sysmsg}' \
        2>/dev/null || fail_open "could not build deny JSON."
    exit 0
fi

# --- digest-binding check: a Confirmed verification is void once its file --
# --- changes. Proven-safe entries are exempt (they drop the finding rather --
# --- than authorize an edit, so there is nothing to bind to a digest).     --
# --- A confirmed fix (prove-it-gate confirm-fix) re-digests the file AFTER the --
# --- fix and records that as fix_file_sha256. The current file is "not    --
# --- stale" if it matches EITHER the pre-fix digest (file_sha256) or the  --
# --- post-fix digest (fix_file_sha256, when present) -- the same two      --
# --- digests `prove-it-gate status`'s "[current]" / "[current as fixed]"      --
# --- branches accept. Without this, a properly confirmed fix immediately  --
# --- re-locks its own file, because the hook only ever knew the pre-fix   --
# --- digest.                                                              --
if [ -n "$FILE_PATH" ]; then
    NORMALIZED_FILE_PATH="$(realpath -m "$FILE_PATH" 2>/dev/null || printf '%s' "$FILE_PATH")"

    CURRENT_DIGEST=""
    if [ -f "$NORMALIZED_FILE_PATH" ]; then
        CURRENT_DIGEST="$(sha256sum "$NORMALIZED_FILE_PATH" 2>/dev/null | awk '{print $1}')"
    fi

    STALE_IDS="$(jq -r -n \
        --slurpfile verdicts "$([ -f "$VERDICTS_FILE" ] && echo "$VERDICTS_FILE" || echo /dev/null)" \
        --arg target "$NORMALIZED_FILE_PATH" \
        --arg current "$CURRENT_DIGEST" \
        '[($verdicts[0].verdicts // [])[]
          | select(.status == "Confirmed" and .file == $target
                    and .file_sha256 != $current
                    and ((.fix_file_sha256 // "") != $current))
          | .id] | join(", ")' \
        2>/dev/null)" || fail_open "could not evaluate digest binding."

    if [ -n "$STALE_IDS" ]; then
        REASON="The verification for $STALE_IDS was against a different version of this file ($NORMALIZED_FILE_PATH), the file has changed since verification (and, if a fix was previously confirmed, since that fix too). If the defect described by $STALE_IDS is reproducible again in the current file, re-verify with: prove-it-gate verify <id> --repro <path>. If you already fixed it in this new version, confirm the fix with: prove-it-gate confirm-fix <id>."
        SYS_MSG="prove-it gate: blocking edit, verification for $STALE_IDS is stale (file changed since verification/fix). Re-verify with \`prove-it-gate verify <id> --repro <path>\`, confirm a new fix with \`prove-it-gate confirm-fix <id>\`, or use \`prove-it-gate override --reason \"...\"\` to bypass."
        jq -n --arg reason "$REASON" --arg sysmsg "$SYS_MSG" \
            '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}, systemMessage: $sysmsg}' \
            2>/dev/null || fail_open "could not build deny JSON."
        exit 0
    fi
fi

exit 0
