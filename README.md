# prove-it

A code review harness for Claude Code where a finding is not real until a script reproduces it. A panel of parallel reviewers finds issues, and a repro-verifier proves or refutes each one against the real code before you act on it.

This repo is a single-plugin marketplace; the plugin itself lives under [`plugins/prove-it/`](plugins/prove-it/README.md).

## How it works

prove-it runs as a loop, not a one-shot report:

1. **Parallel reviewers** examine the change at once, each hunting a different class of defect.
2. **Repro-verify** writes and runs a script against the real code for each finding. It lands as **Confirmed** (the repro fails, so the defect is real), **Proven-safe** (the repro passes, so the finding is dropped), or **Inconclusive** (the repro cannot settle it, so it stays flagged).
3. **Fix** only the Confirmed findings.
4. **Confirm-fix** re-runs each finding's own repro and requires it to pass now. A green test suite is not accepted as proof, because it was already green while the bug existed.
5. **Promote** the repro into a permanent regression test, so a bug proven once cannot silently return.

## Install

```
/plugin marketplace add ironmoose/prove-it
/plugin install prove-it@prove-it
```

Optionally run `/prove-it:setup` to detect your languages, choose a comment style, and install the edit-blocking gate. prove-it works out of the box without it.

## Basic commands

| Command | What it does |
|---|---|
| `/prove-it:review` | Review your local uncommitted diff |
| `/prove-it:review <PR number or url>` | Review an open pull request |
| `/prove-it:review <path>` | Review a specific path |
| `/prove-it:setup` | Optional setup wizard: languages, comment style, and the gate |
| `/prove-it:follow-up` | Re-run each Confirmed finding's repro against the fix and promote passing ones to regression tests |

Full command reference: [review](plugins/prove-it/commands/review.md), [setup](plugins/prove-it/commands/setup.md), [follow-up](plugins/prove-it/commands/follow-up.md).

## How it compares

We ran prove-it and Claude Code's built-in `/code-review max` head to head on the same 275-file security pull request, against the same commits:

| | prove-it | `/code-review max` |
|---|---|---|
| Cost | ~$10 to $15 | $54.74 |
| Findings execution-tested | 11 (each one run) | 0 (static only) |
| Proven real by a repro | 5 (one CRITICAL, on a live database) | 19 asserted, none executed |
| False positives caught by running | 6 refunded | no repro step |
| Model | Sonnet reviewer pods + Opus orchestrator | Opus 4.8 |
| Scope | 41 of 275 files (hand-picked) | full diff |

At roughly a fifth to a quarter of the cost, prove-it's repro gate refunded a phantom CRITICAL (a "this breaks every construction" claim that turned out false the moment it was executed) and four phantom lint errors that a static reviewer reports as real.

The honest caveat: prove-it was scoped to the security core here, and the full-diff `/code-review max` caught a real break that the scoping excluded. Coverage and cost are knobs you set. What prove-it changes is the guarantee: every finding it surfaces was proven by running the code, not asserted.

*(One pull request, not a benchmark. prove-it's cost is approximate from the run tally; the built-in figure is exact.)*

## Documentation

- [Plugin README](plugins/prove-it/README.md): the full pitch, the problem it solves, and the loop in detail
- [Review command](plugins/prove-it/commands/review.md): how the review orchestrator scopes, fans out, and repro-verifies
- [Setup wizard](plugins/prove-it/commands/setup.md): languages, comment styles, gate install, and the config file
- [Follow-up command](plugins/prove-it/commands/follow-up.md): confirm-fix and regression-test promotion
- [The quality gate](plugins/prove-it/gate/README.md): the edit-blocking hook and the open, verify, confirm-fix, close cycle
- [Reviewer agents](plugins/prove-it/agents): the specialized reviewer and verifier sub-agents
- [Conventions overlays](plugins/prove-it/reference): the baseline TypeScript and Python style overlays
