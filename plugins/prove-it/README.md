# prove-it

A code review harness with a simple thesis: a finding is not real until a script proves it.

## The problem

Static review produces confident prose whether or not the bug is real. A reviewer, human or AI, can describe a defect in complete, plausible detail and still be wrong. In practice a large share of findings from any review pass are fiction: real-looking, well-argued, and non-reproducible. Each one costs a full fix cycle before anyone finds out, because nothing forces the claim to be checked against the actual code before it gets acted on.

The other half of the problem shows up after the fix. A team declares a bug fixed because the test suite is green, but that suite was already green while the bug existed. Passing tests were never evidence the defect is gone; they just show that whatever those tests check still works. Without a repro that specifically targets the defect, "green" and "fixed" are two different claims wearing the same color.

## How it works

prove-it runs as a loop, not a one-shot report:

1. **Parallel reviewers.** A panel of specialized reviewer sub-agents examines the change concurrently, each looking for a different class of defect, and produces a list of findings.
2. **Repro-verify.** For each finding, a reproduction verifier writes and runs a small script that tries to demonstrate the defect against the real code. Every finding leaves this step as one of three things: **Confirmed** (the repro fails, proving the defect is real), **Proven-safe** (the repro passes, proving the code is fine and the finding is dropped), or **Inconclusive** (the repro can't settle it, so the finding stays open and flagged). Plausible-but-wrong findings get dropped here instead of surviving into a fix cycle.
3. **Fix.** Only Confirmed findings go to a fix step.
4. **Confirm-fix.** After the fix, prove-it re-runs each Confirmed finding's own repro, unchanged, and requires it to now pass. The repo's full test suite passing is not accepted as proof, because that suite was already green while the defect was still there.
5. **Promote.** Once a fix is confirmed, its repro is promoted into a permanent regression test in your repo, so the defect that was proven once can never silently come back unnoticed.

## Three modes

- **Review a PR.** Point prove-it at an open pull request; it reviews the diff, runs the repro-verify loop, and reports Confirmed findings with their repros attached.
- **Review your local working diff.** Same loop, run against uncommitted local changes, for review before you open a PR.
- **Follow-up review after a fix.** Re-runs the repro for each previously Confirmed finding against the fixed code, confirms or reopens it, and promotes confirmed fixes to regression tests.

## Install

```
/plugin marketplace add ironmoose/prove-it
/plugin install prove-it@prove-it
```

## Conventions overlays

prove-it ships baseline TypeScript and Python conventions overlays that its reviewer agents read before judging a change, plus a setup step to customize them for your own project's standards. If the `adze-bonch` plugin is also installed, prove-it can read its overlays too, so the two plugins share one set of conventions instead of drifting apart.

## Why a green test suite is not proof

A green suite tells you the tests you already had still pass. It does not tell you the bug a reviewer just described is gone, because if that suite covered the bug, the bug would already have been caught before review ever started. Proof that a fix works has to come from re-running the exact repro that demonstrated the defect in the first place, against the fixed code, and watching it flip from fail to pass.

## Status

v0.3.2, standalone.

<!-- screenshots: added in a later phase -->
