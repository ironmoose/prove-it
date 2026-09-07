# Performance / Scalability Reviewer - design + integration plan (2026-09-07)

Status: proposal. Overnight work built the new lane file and validated the concept; the integration steps below are the reviewed morning work and were NOT done overnight. Shipped prove-it behavior is unchanged until review.md is wired and the version is bumped.

## Why this exists
The prove-it v0.2.1 re-measure on `agent-review-demo-clean` caught 8 of 9 planted defects. The single miss was D9, a pure performance/scale defect: `reconcilePayment` calls `ledger.history(invoice.id)` (a full linear scan of an ever-growing audit trail) once per allocation, plus a per-allocation `invoices.find(...)`, and the ledger retains a full invoice snapshot per event and grows unbounded. Root cause of the MISS: prove-it had no lane whose mandate is algorithmic/scaling complexity. `code-smells-reviewer`'s "Complexity Smells" section covers cyclomatic complexity (nested conditionals, flag arguments), not algorithmic complexity (N+1, quadratic, unbounded growth); `edge-case-qa` covers boundaries, nulls, and races, not scale. D9 fell in a structural gap, not a tuning miss.

## The experiment (this session)
Three candidate performance-reviewer lenses were run BLIND against the fixture (no answer key, no D9 hint), plus a scaling-repro prototype:
- A - Complexity Accountant: formal Big-O in named dimensions.
- B - Production Incident Veteran: the 2am-pager scaling story.
- C - Scaling-Repro-First: only flag what a scaling experiment can prove.

Result: all three caught D9's core (`ledger.history` rescan, HIGH) and the sibling `invoices.find` N+1, with ZERO false positives - none flagged the required append-only ledger, the snapshot payload, or the inherent sorts. C additionally found a third issue A and B missed: recording a ledger event for every zero-amount allocation inflates accumulated events to R x N instead of R x (touched) - the performance face of the same zero-amount-allocation defect the correctness lanes flagged as D8/DC3.

The scaling-repro prototype PROVED D9 with real numbers: events-examined x4.00 per doubling (clean O(N^2); examined / N^2 is flat), wall-clock x13.6 over 4000 runs, heap 40 MB at 100k events. It isolated the AVOIDABLE cost (history() call count stayed linear = necessary work; only the rescan was quadratic) and demonstrated the PROVEN-SAFE counterfactual (an O(1) revision counter makes per-run work flat). Repro artifacts: `~/.claude/prove-it/repros/agent-review-demo-clean/perf/perf-d9-operation-count.ts` and `perf-d9-wallclock.ts`.

Conclusion: a dedicated performance lane reliably catches what the general lanes miss. Ship ONE synthesized lane, not three near-identical ones.

## Design decisions
1. New lane `performance-reviewer` (`plugins/prove-it/agents/performance-reviewer.md`) - CREATED this session as an additive file; it is NOT yet wired into `review.md`, so shipped behavior is unchanged. It is a synthesis: C's provable-by-experiment discipline as the spine, A's dimension rigor, B's scaling story, with required-vs-avoidable as a hard rule. Read-only tools, model sonnet, effort high.
2. `repro-verifier` gains a SCALING-REPRO MODE (proposal below; NOT yet applied). A perf finding cannot be settled by binary pass/fail against a contract; it needs a sweep plus a growth-signal measurement. CONFIRMED = super-linear growth demonstrated; PROVEN-SAFE = linear/bounded as intended; INCONCLUSIVE = no faithful scaling harness could be built.
3. Division of labor: the performance lane PROPOSES the experiment (dimension, signal, predicted shape); the repro-verifier RUNS it. This mirrors how the other lanes propose and the repro-verifier disposes, keeps the perf lane read-only, and keeps the "N of M real" headline honest for perf findings.

## Integration steps (morning, reviewed work - not done overnight)
1. Wire `performance-reviewer` into `review.md`: add it to the Step 4 parallel dispatch (10 -> 11 lanes); add a Performance bucket to Step 5 consolidation; in Step 6, route perf findings that carry a scaling experiment to the repro-verifier in scaling mode. Overlay: none initially (algorithmic analysis is language-agnostic); note language-specific perf idioms as a future overlay.
2. Extend `repro-verifier.md` with the scaling-repro mode section (draft below).
3. Update every agent's frontmatter "in parallel with ..." list to include the new lane (folds into the existing description-drift task, adze 01M1TRBCCXVD).
4. Bump plugin version 0.2.1 -> 0.3.0 (new lane = minor), reinstall, refresh the cache, then VERIFY in a FRESH session: (a) `performance-reviewer` registers as an agent type; (b) re-run `/prove-it:review` on the clean fixture and confirm D9 is now caught AND the score holds with 0 new false positives (watch specifically for the perf lane over-flagging inherent sorts). Fresh-session registration is the same catch-22 proven with v0.2.1: the building session cannot test its own newly added agent.
5. Consider a second perf-bearing fixture before trusting the lane broadly - D9 is a single example, and a lane validated on one case is weak.

## repro-verifier scaling-repro mode (draft section to add)
Add to `repro-verifier.md` a mode that triggers when a seeded finding is tagged as a scaling/performance claim carrying a named dimension and growth signal:
- Build a harness that drives the real API and sweeps the named dimension (for example N = 50, 100, 200, 400), sharing any long-lived structure across iterations so accumulation happens.
- Measure the named growth signal: an instrumented operation count (wrap or subclass to count the suspect work), wall-clock per unit, or retained-object count.
- Classify: CONFIRMED if the signal grows super-linearly in the swept dimension (report the per-doubling ratio and, where applicable, that signal / N^2 is flat); PROVEN-SAFE if it is linear-or-bounded as the code intends; INCONCLUSIVE if no faithful harness could be built.
- Isolate the AVOIDABLE cost, not the required one: hold required structures constant or separate the necessary-work curve from the avoidable-rescan curve, so the verdict is about the recompute, not "the structure is large."
- Report the counterfactual the fix would produce (flat/linear), so confirm mode has an acceptance target.
The prototype at `~/.claude/prove-it/repros/agent-review-demo-clean/perf/perf-d9-operation-count.ts` is the working template: it subclasses Ledger to count events examined and separates the linear necessary-work curve from the quadratic rescan curve.

## Open questions for Parker
- Lane name: `performance-reviewer` vs `scalability-reviewer`.
- Scope: keep it purely asymptotic/scaling, or also allow a proven constant-factor hot-path finding? Recommendation: asymptotic only, to stay honest.
- repro-verifier scaling mode: add one mode section to the existing agent (recommended, it already owns grounding), or a separate perf-repro-verifier agent?
- The zero-amount-allocation ledger inflation (the C finding) is the perf face of the fixture's own D8/DC3 correctness bug - informational, no action needed on the plugin.

## Pointers
- New agent file: `plugins/prove-it/agents/performance-reviewer.md`
- Scaling repro artifacts: `~/.claude/prove-it/repros/agent-review-demo-clean/perf/`
- Gap task: adze 01M1X5NT. Design decision doc: adze, Adze Workflow project.
