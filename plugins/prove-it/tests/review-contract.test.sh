#!/usr/bin/env bash
# review-contract.test.sh: contract test for commands/review.md. The command is
# markdown the orchestrator follows, so this pins the lane relevance gate
# wording: no "always all ten" language, the gate section and result template
# present, every gated lane's table row carrying its trigger keyword, and the
# always-run lanes outside the table. Prints one PASS/FAIL line per case and
# exits non-zero if any case failed.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEW="$SCRIPT_DIR/../commands/review.md"

FAIL_COUNT=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# The gate section: from its heading to the next heading of any level.
GATE_SECTION="$(awk '
  /^### Lane relevance gate/ { on = 1; next }
  on && /^#+ / { exit }
  on { print }
' "$REVIEW")"

for phrase in "all ten" "10 reviewers" "ten lanes" "ten reviewers" \
  "until every chunk of every lane" "Paste the diff, the clipped" \
  "Never proceed without a real result from every lane" "gh pr diff\` filtered"; do
  if grep -qiF -- "$phrase" "$REVIEW"; then
    fail "absent phrase still present: '$phrase'"
  else
    pass "absent phrase: '$phrase'"
  fi
done

for phrase in \
  "### Lane relevance gate" \
  "Lanes: {N} run / {M} skipped" \
  "Fail open" \
  "--lanes" \
  "forced on" \
  "forced off" \
  "per slice" \
  "slice context file" \
  "### Coverage" \
  "NOT COVERED" \
  "--no-checkout" \
  "path args" \
  "scoped to" \
  "every selected lane of every slice" \
  "headRefOid" \
  "git rev-parse HEAD" \
  "is ignored and reported" \
  "cannot be forced off"; do
  if grep -qF -- "$phrase" "$REVIEW"; then
    pass "present phrase: '$phrase'"
  else
    fail "missing phrase: '$phrase'"
  fi
done

# Gate table rows: one line carrying both the lane's subagent_type and trigger.
check_row() {
  local lane="$1" keyword="$2"
  if printf '%s\n' "$GATE_SECTION" | grep '^|' | grep -F -- "$lane" | grep -qF -- "$keyword"; then
    pass "gate row: $lane has '$keyword'"
  else
    fail "gate row: $lane lacks '$keyword'"
  fi
}
check_row "edge-case-qa" "executable logic"
check_row "code-smells-reviewer" "non-trivial"
check_row "test-reviewer" "test files"
check_row "contract-reviewer" "signature"
check_row "security-reviewer" "trust boundary"
check_row "doc-vouching-reviewer" "justifies"
check_row "self-containment-reviewer" "prose"
check_row "comment-claim-verifier" "falsifiable"

# Section-scoped phrase checks: section from heading regex to the next heading.
section() { awk -v h="$1" '$0 ~ h { on = 1; next } on && /^#+ / { exit } on { print }' "$REVIEW"; }
check_in() {
  local name="$1" heading="$2" phrase="$3"
  if section "$heading" | grep -qF -- "$phrase"; then
    pass "$name: '$phrase'"
  else
    fail "$name lacks '$phrase'"
  fi
}
check_in "gate section" '^### Lane relevance gate' '`-repro-verifier` is refused'
check_in "gate section" '^### Lane relevance gate' 'forced overrides apply to every slice'
check_in "gate section" '^### Lane relevance gate' 'not run'
check_in "PR section" '^### A pull request' 'review nothing'
check_in "PR section" '^### A pull request' 'git status --porcelain'
check_in "PR section" '^### A pull request' 'valid only with a PR target'
check_in "PR section" '^### A pull request' 'git diff -M $BASE_SHA...HEAD -- <paths>'
check_in "hard rules" '^## Hard rules' 'NOT COVERED'
check_in "review id" '^### Resolve the base' 'hash of the path scope'
check_in "gate section" '^### Lane relevance gate' 'out of scope for this scoped review'
check_in "large diffs" '^### Large diffs' 'repro bucket <name>: NOT RUN'
check_in "large diffs" '^### Large diffs' 'renames/moves called out'
check_in "review id" '^### Resolve the base' 'clear any existing'

# The gate table has exactly eight lane rows.
ROWS="$(printf '%s\n' "$GATE_SECTION" | grep '^| `' | wc -l | tr -d ' ')"
if [ "$ROWS" -eq 8 ]; then
  pass "gate table has 8 rows"
else
  fail "gate table has $ROWS rows, expected 8"
fi

# Always-run lanes: named on an "Always run" line, never in a gate-table row.
ALWAYS_LINE="$(printf '%s\n' "$GATE_SECTION" | grep -F 'Always run')"
for lane in code-reviewer acceptance-qa repro-verifier; do
  if printf '%s\n' "$ALWAYS_LINE" | grep -qF -- "$lane"; then
    pass "always-run line names $lane"
  else
    fail "always-run line missing $lane"
  fi
  if printf '%s\n' "$GATE_SECTION" | grep '^|' | grep -qF -- "\`$lane\`"; then
    fail "$lane appears in a gate-table row"
  else
    pass "$lane not in gate table"
  fi
done

# Roster table keeps all ten review agents.
for agent in code-reviewer code-smells-reviewer edge-case-qa test-reviewer \
  contract-reviewer security-reviewer acceptance-qa doc-vouching-reviewer \
  self-containment-reviewer comment-claim-verifier; do
  if grep '^|' "$REVIEW" | grep -qF -- "\`prove-it:$agent\`"; then
    pass "roster has prove-it:$agent"
  else
    fail "roster missing prove-it:$agent"
  fi
done

if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "ALL PASS"
  exit 0
fi
echo "$FAIL_COUNT FAILED"
exit 1
