# prove-it

A standalone Claude Code plugin: a code review harness where a finding is not real until a script reproduces it.

The plugin itself lives under [`plugins/prove-it/`](plugins/prove-it/README.md), including its own README with the full pitch, how it works, and install instructions. This repo is also a single-plugin marketplace, so it can be added directly:

```
/plugin marketplace add ironmoose/prove-it
/plugin install prove-it@prove-it
```

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

## Status

v1.0.0. Agents, commands, the repro-verify loop, the edit-blocking gate, and conventions overlays all ship.
