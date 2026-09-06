# TypeScript conventions overlay

Language baseline for TypeScript work. The orchestrator injects this file into the prompts of language-sensitive agents (implementer, test-writer, code-reviewer, code-smells-reviewer, test-reviewer, edge-case-qa) when the changed files are `.ts` / `.tsx`. It carries only rules that are true of the *language*. Anything true of a particular repo, stack, or framework belongs in that repo's own `CLAUDE.md`.

---

## Precedence: this is the baseline; the target repo's CLAUDE.md wins

This overlay sits **underneath** the plugin's standing standards model (`reference/conventions.md`). It is a floor, not a ceiling, and it never displaces a committed standard.

- **Read the target repo's `CLAUDE.md` first**, root plus the nearest nested one relative to the changed files, along with any committed standards doc, and defer to it wherever it speaks. The overlay exists so a language baseline is loaded even before that read completes; the live repo doc wins whenever the two differ.
- **Do not go rogue.** Never impose this overlay's version of a rule over a repo's committed standard. If the repo says something different, the repo is right for that repo. Follow it, and if the divergence looks like a real gap, flag it rather than silently overriding.
- The overlay fills the gaps the repo's own standard leaves. Treat any drift between this file and a repo's `CLAUDE.md` as "the repo is newer" and check the repo.

| Priority | Source |
|----------|--------|
| 1 | Session override from the user |
| 2 | Target repo `CLAUDE.md` (root plus nearest nested) |
| 3 | This overlay |
| 4 | General good practice for the detected stack |

---

## Type safety

**Absolute prohibitions.**

- **No `as any`, ever.** Use a proper type, `unknown`, `Pick`, or a narrowed interface instead.
- **No `as unknown as T`.** This is a last-resort escape hatch. Prefer narrowing the production type (for example `Pick<T, 'field'>`) so no cast is needed at all.
- When a function only uses a subset of a large type's fields, **narrow the parameter with `Pick<T, 'field1' | 'field2'>`**. This makes the dependency explicit and avoids forced casts at call sites, especially in tests.

**Nullability.**

- Prefer `strict` and `strictNullChecks` semantics: if a value can be absent, its type says so. Do not launder absence through a non-null assertion (`!`) when a check or a default would do.
- `?.` and `??` express intent; a chain of them papering over a type that should have been narrowed once does not.

**Discriminated unions over optional-field soup.**

- When a value has several shapes, model it as a union with a literal discriminant (`kind`, `type`, `status`) rather than one interface where half the fields are optional. The compiler can then prove exhaustiveness; an object of optionals cannot.
- Exhaustive `switch` on the discriminant with a `never`-typed default arm turns a new variant into a compile error instead of a runtime surprise.

**Type-safety smells** for the code-smells lens. Each is a small type lie; flag new ones in new code.

| Smell | What it looks like | Why it matters |
|-------|--------------------|----------------|
| Index-signature escape hatch | `[key: string]: unknown` / `[key: string]: any` on a type whose shape is actually known | An index signature says "I give up on typing this" |
| Type-assertion chain | `as unknown as T`, or stacked `as` casts forcing a type | Usually means the source type is wrong or too broad |
| Overly broad type | `Record<string, any>`, `object`, or `unknown` where the shape is known | Code works, type safety is lost at that boundary |
| Suppression proliferation | New `@ts-expect-error` / `@ts-ignore` in the diff | A few in legacy code is expected; new ones in new code are a smell |
| Non-null assertion as a habit | `value!.field` where a guard belongs | Moves a compile-time check to a runtime crash |

---

## Async and concurrency

Properties of the JavaScript execution model, so they hold in any TypeScript project regardless of its dependencies.

- **A floating promise is a silent bug.** A promise-returning call that is neither awaited, nor returned, nor given an explicit handler loses its rejection and runs in an unpredictable order. A `try` / `catch` wrapped around an un-awaited call catches nothing.
- **Interleaving happens only at `await`.** JavaScript runs your code on one thread, so two async operations touching the same in-process object can interleave only where an `await` sits between the read and the write. Do not flag a race in a function that reads and writes shared state with no `await` in between. Do flag it when there is an `await` in the middle, or when the state lives outside the process, where another process or instance can write it concurrently.
- **`await` inside a loop serializes by construction.** That is often the intent: ordering, rate limits, backpressure. Do not convert it to a concurrent form without evidence that concurrency is safe there, and do not flag it as a defect without evidence that it is actually too slow.
- **Rejections need a reachable handler.** Every async entry point (event handler, job callback, top-level call) either awaits its work inside a `try` / `catch` or attaches a rejection handler. An unhandled rejection is a crash or a silent drop depending on the runtime's configuration, and neither is a behavior to leave to chance.

---

## Forbidden-pattern audit (TypeScript)

When an agent's workflow calls for a forbidden-pattern audit, run these against the **changed `.ts` / `.tsx` files** and report **integer counts, not adjectives**. Empty findings are a claim made under audit, not an exemption: report the number, not "all clean."

```bash
# Type-safety prohibitions
grep -nE 'as any\b' <changed .ts files>              | wc -l
grep -nE 'as unknown as\b' <changed .ts files>       | wc -l
grep -nE '@ts-(ignore|expect-error)\b' <changed .ts files> | wc -l

# Non-null assertions (heuristic; each hit needs a look, not an automatic fix)
grep -nE '\w!\.' <changed .ts files>                 | wc -l

# Test hollowness heuristic. Adapt the assertion pattern to the repo's
# assertion library (expect, assert, should, or another).
grep -cE 'expect\(|assert\.|\.should\b' <changed test files>

# External I/O without try/catch (heuristic, manual review)
grep -nE 'await .*\.(read|write|fetch|exec|query)' <changed files>
```

---

## Forbidden-pattern audit: report format (TypeScript)

Emit the audit as this section, with the real integer counts filled in:

```
## Forbidden-Pattern Audit (TypeScript)
- `as any`: 0 occurrences
- `as unknown as`: 0 occurrences
- `@ts-ignore` / `@ts-expect-error`: 0 occurrences
- non-null assertions: 0 (or list file:line + justification)
- Test assertion counts: foo.test.ts (4), bar.test.ts (7)
- Unwrapped external I/O calls: 0 (or list locations + justification)
```

- Any count above zero for a forbidden cast must be **fixed before reporting**, or carried with a per-occurrence inline justification. "All clean" is not acceptable phrasing; report numbers.
- **A test file with zero assertion calls is hollow.** Hollow tests are forbidden. If a test you created or touched has zero assertions, fix it or flag it.
- If the target repo's `CLAUDE.md` names additional forbidden patterns, add them to this audit for that repo.

---

## Import and module smells

- **Unnecessary re-export.** Code moved to a new file but the old location keeps `export { thing }` as a compatibility shim. Consumers should import from the new location directly. Look for `import { X } from './new-file'; export { X };`.
- **Barrel-file bloat.** An `index.ts` that re-exports single items from many files, pulling everything into scope even when callers need one export.
- **Import chain.** `A` imports from `B` which imports from `C`, when `A` could import from `C` directly. Each hop is a coupling point.
- **Deep relative paths.** `../../../..` climbing out of a module usually means the import crossed a boundary that deserves a named entry point.
- **Type-only imports.** Where the repo's tooling cares (`isolatedModules`, bundler transpilation), a type used only in a signature is imported with `import type`.

---

## Size and decomposition

There is **no universal line cap** in this overlay. If the target repo's `CLAUDE.md` sets one, that number is the rule for that repo. Absent one, use the calibration below.

- **Class size.** Do not flag a class for length alone. A class that is a flat registry of many small members, one per route, command, event, or case, is legitimately large by design. Test fixtures are exempt.
- **Long method.** A procedural function at an entry point is legitimately long. If it has clear top-level sections and they do not share state in confusing ways, it is a sequence, not a smell. Flag only when the function **mixes abstraction levels**, for example input parsing plus business logic plus external I/O in one body, not on raw length.
- **`Manager` / `Helper` / `Handler` / `Util` naming.** Not a universal TypeScript prohibition. Many TypeScript codebases use these names deliberately. Flag such a name only when the target repo's `CLAUDE.md` bans it, or when the name is genuinely hiding an unclear responsibility.
- **Primitive obsession.** Many codebases deliberately use raw `string` for ids and opaque identifiers. Do not flag every `id: string` parameter. Flag only when the primitive is genuinely ambiguous at the call site, or is used in arithmetic or comparison where a typed value object would prevent a real class of bug (money, durations, units).
- **Every exemption above covers CODE, never PROSE.** A legitimately large class, a procedural orchestration function, an exempt test fixture: none of that says anything about the comments inside them. Never read a size exemption across to comments or JSDoc. See the next section.

---

## Comments and JSDoc

**A comment states intent, in three sentences at most.** One or two is the norm; three is the ceiling, and it applies to every comment and JSDoc block: module, class, function, and inline alike. Say what the code is for, or what constraint the next edit must not break. Do not argue the case: no derivations, no measured numbers, no alternatives considered and rejected, and never a task or issue reference. Evidence worth keeping outlives the line it justified; it belongs in the commit message, the PR, or an ADR.

**The ceiling is absolute, not proportional.** "It states a real why" does not license a fourth sentence; that test passes for an essay. Count sentences. A reviewer asked whether a five-line block over a three-line function is *proportionate* will answer "mostly earns it", which is exactly how bloat ships. Over three? Delete the weakest sentence. Do not reword them all shorter and keep them all.

- **Keep the trap, cut the archaeology.** The constraint that breaks the code if violated stays. The release that changed it, the issue number, the benchmark, and the story of how it was found go.
- Comments explain the non-obvious **why**, not the **what**. If a comment restates the code, delete it; if the code needs a comment to be understood, prefer clearer code first.
- **Scope and applies-to lists belong in the module or directory doc, not in a function's own JSDoc.** Enumerating a function's call sites inside that function's doc is unenforced, goes stale silently the moment a caller changes, and a stale list misleads. Call sites are what grep is for.
- Do not state the same fact in both a JSDoc block and an adjacent inline comment. One keeps it.
- The bar for any individual line: **would omitting it let someone make a wrong change?** If not, it is commentary, not documentation.
- JSDoc belongs on exported and public surfaces and on non-obvious logic, not on every function. An `@param` list that restates the signature adds maintenance and no information.

---

## Test quality (framework-neutral)

**Detect and follow the framework the target repo already uses.** Read its test config and neighboring test files to determine the runner, the assertion library, the mocking library, the file-placement convention (co-located versus a `tests/` tree), the naming suffix, and the targeted-run command. Do not introduce a second framework, and do not reinvent a helper the repo already ships. The quality lenses below apply regardless of which framework that turns out to be.

**Hollow assertions.**

- A test with zero assertions is hollow and is forbidden.
- A test whose only assertion is that a call did not throw asserts nothing about behavior unless not-throwing *is* the behavior under test. Say so explicitly when it is.
- Asserting on a value the test itself just constructed, with no code under test in between, is a tautology.
- Snapshot-style assertions that were regenerated to match new output prove that output changed, not that it is correct.

**Over-mocking.**

- **Mock behavior, build data.** Construct DTOs, models, and plain value objects for real; mock only behavior-carrying collaborators such as clients, repositories, queues, and process boundaries.
- Mock with a spec or typed mock so a renamed or removed method fails the test instead of silently passing.
- **Never invent a type or interface just so a test can mock it.** If the only reason an abstraction exists is the test, delete the abstraction and test the real thing.
- A boundary mocked in a unit test still needs an integration test against the real dependency. A unit test proving you called the mock correctly proves nothing about the mock matching reality.
- A test that mocks every collaborator and then asserts only on the mocks is testing the wiring diagram, not the code.

**Framework misuse.**

- Setup registered in a run-once hook when the framework needs per-test isolation is a flakiness source, especially under parallel execution. Follow the isolation model the repo's framework and config actually use.
- Bypassing an established shared test helper in favor of a hand-rolled equivalent is a smell; find the helper first.
- An async assertion that is not awaited passes vacuously. A test that waits with a fixed sleep instead of the framework's wait primitive is flaky by construction.
- Where the repo's mocking library uses argument matchers, a permissive matcher in **setup** is often required for the call to be satisfied at all. It asserts nothing only when it appears in the **verification** step for an argument that carries the test's behavior; flag that case, not the setup.
- A deliberately loose guard assertion added for a clearer failure message is a low-severity finding at most. Frame it as "remove for a tighter test, but understand why it is there."

**Test structure.**

- Arrange, Act, Assert, with one main thing under assertion per test.
- Descriptive names that state the behavior, so a failure reads like a specification.
- Near-identical tests that differ only in inputs and expected outputs collapse into the framework's parametrized or table-driven form. Reserve separate test functions for genuinely different behaviors.
- **No logic in tests.** No `if` / `for` / `while` / `try` steering assertions inside a test body. A test with branching is testing itself.

---

## What does not belong in this file

The test for anything in this file: **would this rule be true of ANY repo in this language?** If it is only true of repos that happen to use a particular library, ORM, test framework, queue, editor, or architecture, it is a stack fact, not a language fact, and it must not be here. Putting it here means every TypeScript repo gets lectured about libraries it does not use.

The following categories are **deliberately absent** and belong in the target repo's own `CLAUDE.md`:

| Category | Examples of what belongs there instead |
|----------|----------------------------------------|
| Layer architecture and directory conventions | Which layer may hold access control, what a controller may contain, where validation lives, what may be injected into what |
| The project's chosen test framework | Test runner, assertion library, mocking library, file placement and naming, targeted-run command, coverage targets |
| Shared test infrastructure | Named helpers, fixtures, mock builders, and render wrappers the repo already ships |
| ORM and query-builder usage | Query idioms, parameter limits, empty-array and null semantics, migration rules |
| Message-queue and job semantics | Retry, idempotency, stalling, concurrency defaults |
| Cache and datastore semantics | Expiry-during-read, degradation policy, consumer-group setup |
| HTTP client, validation, and serialization libraries | Which library, which schema style, where schemas live |
| UI component and styling conventions | Component taxonomy, state management, styling system, accessibility targets |
| Content and input-format hazards | Editor-produced markup, encoding, sanitization requirements |
| Runtime performance choices | Streaming versus full reads, bounded prefixes, and other deliberate tradeoffs a reviewer must not undo |
| "Verify before flagging" facts | Codebase-specific facts that defuse a finding, such as which gate already covers a path |

If a rule you want to add would be false in another TypeScript project, it is a repo rule, and it goes in that repo's `CLAUDE.md`.
