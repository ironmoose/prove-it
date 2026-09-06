# Python conventions overlay

Language baseline for Python work. The orchestrator injects this file into the prompts of language-sensitive agents (implementer, test-writer, code-reviewer, code-smells-reviewer, test-reviewer, edge-case-qa) when the changed files are `.py`. It carries only rules that are true of the *language*. Anything true of a particular repo, service, or deployment belongs in that repo's own `CLAUDE.md`.

---

## Precedence: this is the baseline; the target repo's CLAUDE.md wins

This overlay sits **underneath** the plugin's standing standards model (`reference/conventions.md`). It is a floor, not a ceiling, and it never displaces a committed standard.

- **Read the target repo's `CLAUDE.md` first**, root plus the nearest nested one relative to the changed files, along with any committed standards doc, and defer to it wherever it speaks. This overlay fills the gaps the repo's own standard leaves; it never displaces it.
- **Do not go rogue.** Never impose this overlay's version of a rule over a repo's committed standard. If the repo says something different, the repo is right for that repo. Follow it and, if the divergence looks like a real gap, flag it rather than silently overriding.
- **Treat the repo's copy of any shared philosophy as authoritative.** If the target repo commits its own "how to code" section, read that copy and prefer it. It may have evolved past what is captured here. This is "check the source, do not recall it" applied to the standard itself.

| Priority | Source |
|----------|--------|
| 1 | Session override from the user |
| 2 | Target repo `CLAUDE.md` (root plus nearest nested) |
| 3 | This overlay |
| 4 | General good practice for the detected stack |

Three invariants hold **within this overlay**. They describe how this file is written; they do not override a repo's committed standard.

- **One standard, no per-repo gating.** There are no "in repo X do this, in repo Y do that" blocks here. The same calibration applies to every Python file regardless of which project it lives in.
- **No size caps on CODE.** There is no function-length, class-length, or method-count limit anywhere in this file. Readability is hops, not lines (see below). Do not flag or split code for being "too long." **This exemption covers code only. It does NOT cover comments or docstrings**, which are governed by the sentence ceiling under Hygiene.
- **No library rules live here.** This file carries only rules that hold for any Python file regardless of its dependencies. Guidance for a data-modeling, HTTP, logging, or serialization library is a stack fact and belongs in the target repo's `CLAUDE.md`. If the repo is silent on a library, follow that library's own current documentation rather than inventing a house rule.

---

## How to code (the calibration that comes first)

This philosophy governs everything below it. When any guidance elsewhere seems to pull toward more types or smaller units, this section wins.

- **Readability is hops, not lines.** Optimize for the number of jumps a reader makes to understand a change: fewer types, fewer files, fewer indirections. A cohesive 60-line class or a 40-line function that reads straight through is *better* than four 15-line pieces the reader has to reassemble. **Never split a cohesive unit just for length; there is no length limit here.** Long is not a smell; scattered is.

- **A name must earn itself.** Introduce a new type, class, or abstraction only if you would say its name aloud while explaining the system. "The subscriber subscribes" earns no `Subscriber` type; it is just a function. Prefer fewer types. An extra name the reader must learn is a cost, not a courtesy.

- **Name modules for their subject, never their role.** Banned module names: `utils`, `helpers`, `common`, `shared`, `misc`, `base`. Test a module name by asking, from the name alone, whether you can tell what belongs in it. `retry`, `pagination`, `csv_export` pass; `helpers` fails because anything could land there.

- **Classes hold state.** Reach for a class when there is state or a lifecycle to own (a connection, a running task, a buffer) or real data to model. A one-method, no-state class is a function wearing a costume; write the function. A well-named module of free functions is good Python, not a design gap to "fix" by wrapping it in a class.

- **Model a closed set of strings as `Literal[...]`, not a `StrEnum`.** A fixed set of string constants, a `status` or a `job_type` say, is a `Literal["open", "closed", ...]`.

- **Inject at the edges, construct in the middle.** The composition root wires only what crosses the process boundary (network, disk, clock, subprocess) plus anything pluggable by design. Logic you own is not injected: call it and test it directly. A `Callable` is a perfectly good injected dependency; a dependency need not be a class or an interface.

- **Mock behavior, build data.** Build DTOs, models, and value objects for real, or as small fakes; mock only behavior-carrying collaborators. Never invent a type just so a test can mock it. Full testing form below.

- **Check the library, do not recall it.** For unfamiliar or correctness-critical APIs (signatures, config keys, acknowledgement, retry, and pagination semantics) pull the current docs rather than writing from memory. Getting the contract wrong is a bug the type checker will not catch.

---

## Python hygiene (universal)

Applies to every Python file.

- **Docstrings, PEP 257 shape.**
  - Public modules, classes, and methods or functions get a docstring. A one-line docstring is imperative ("Return the parsed report.", not "Returns..."), and keeps its closing `"""` on the **same line** as the text.
  - Non-public (leading-underscore) methods do **not** get a docstring. Put a `#` comment after the `def` line if anything needs saying.
  - **A comment states intent, in three sentences at most.** One or two is the norm; three is the ceiling, and it applies to every comment and docstring: module, class, function, and inline alike. Say what the code is for, or what constraint the next edit must not break. Do not argue the case: no derivations, no measured numbers, no alternatives considered and rejected, and never a task or issue reference. Evidence worth keeping outlives the line it justified; it belongs in the commit message, the PR, or an ADR.
  - **The ceiling is absolute, not proportional.** "It states a real why" does not license a fourth sentence; that test passes for an essay. Count sentences. A reviewer asked whether a five-line docstring over a three-line function is *proportionate* will answer "mostly earns it", which is exactly how bloat ships. Over three? Delete the weakest sentence. Do not reword them all shorter and keep them all.
  - **Keep the trap, cut the archaeology.** "Keep `body` as the iteration target; `__aenter__` returns the raw response" earns its place. The paragraph on which release changed that, the issue number, and how it was discovered does not.
  - Comments explain the non-obvious **why**, not the **what**. If a comment restates the code, delete it; if the code needs a comment to be understood, prefer clearer code first.
  - **Scope and applies-to lists belong in the module docstring, not in a function's own docstring.** Enumerating a function's call sites inside that function's doc is unenforced, goes stale silently the moment a caller changes, and a stale list misleads. Call sites are what grep is for.
- **PEP 8** for layout and naming: `snake_case` for functions and variables, `UPPER_SNAKE_CASE` for constants, `PascalCase` for classes.
- **f-strings** for all string interpolation. No `%` formatting or `str.format` in new code.
- **Chain exceptions:** `raise NewError(...) from exc` on every re-raise so the original traceback survives. A re-raise that drops the cause is a defect.
- **No swallowing errors:** no bare `except:` and no `except Exception: pass`. Catch the narrowest exception you can act on; if you catch, either handle it, log it, or re-raise with `from`.
- **No `Any`.** Do not annotate with `: Any` or `-> Any` unless the type is genuinely unknowable at that boundary, and then narrow it as soon as you can. `object`, a `Protocol`, a `TypedDict`, or a real model is almost always better. `Any` disables the checker exactly where you need it.
- **Modern type-hint syntax (Python 3.10+).** Pipe syntax for unions and optionals, `str | None` and `int | str`, over `Optional[...]` and `Union[...]`. This is a property of the interpreter the code targets, so it is the default on current versions.
- **No mutable default arguments.** `def f(items: list[str] = [])` binds one list at definition time and shares it across every call. Default to `None` and build the container inside the function.
- **Import order:** stdlib, then third-party, then local, grouped and blank-line separated. Explicit imports over wildcards.

---

## Testing

**Detect and follow the test framework the target repo already uses.** Read its test config and neighboring test files to determine the runner, the parametrization form, the fixture and async conventions, and the file-placement rule, then follow them. Do not introduce a second framework. The quality bar below applies regardless of which runner that turns out to be.

- **AAA and FIRST.** Each test is Arrange, Act, Assert, with one main thing under assertion. Tests are Fast, Independent, Repeatable, Self-validating, and Timely: no ordering dependencies, no shared mutable state, no network or wall-clock reliance.
- **Descriptive names.** `test_should_<behavior>_when_<condition>`, for example `test_should_retry_when_upstream_returns_503`. The name states the behavior, so a failure reads like a spec.
- **Parametrize, do not copy-paste.** Near-identical tests that differ only in inputs and expected outputs collapse into one parametrized case, in whatever form the repo's runner provides. Reserve separate test functions for genuinely different behaviors.
- **Mock behavior, build data.** This is the load-bearing testing rule.
  - **Build** DTOs, models, and value objects for real, or as small hand-written fakes. They carry data, not behavior; a real one is clearer and safer than a mock.
  - **Mock** only behavior-carrying collaborators (connections, clients, repositories, subprocess runners), and bind each mock to the real type so a renamed or removed method fails the test instead of silently passing. In the standard library that is `spec=` on `unittest.mock`.
  - **Never invent a type just so a test can mock it.** If the only reason an interface exists is the test, delete the interface and test the real thing.
  - **A boundary mocked in a unit test also needs an integration test** against the real dependency. A unit test proving you called the mock correctly proves nothing about the mock matching reality.
- **No hollow assertions.** A test with zero assertions is forbidden. A test whose only assertion is that a call did not raise asserts nothing unless not-raising *is* the behavior under test; say so explicitly when it is.
- **No logic in tests.** No `if` / `for` / `while` / `try` steering assertions inside a test. A test with branching is testing itself. Push variation into parametrization and keep the body straight-line.

---

## Forbidden-pattern audit (Python)

When an agent's workflow calls for a forbidden-pattern audit, run these against the **changed `.py` files** and report **integer counts, not adjectives**. Empty findings are a claim made under audit, not an exemption: report the number, not "all clean."

```bash
# Bare / swallowing except
grep -nE 'except\s*:' <changed .py files>            | wc -l   # bare except:
grep -nEA1 'except[^:]*:' <changed .py files> | grep -cE '^\s*pass\b'   # except ...: pass

# Re-raise that drops the cause (heuristic; inspect each `raise` inside an
# `except` block: a re-raise with no `from` is a finding)
grep -nE '(^|\s)raise\b' <changed .py files>

# print() used as logging (each hit is a finding unless it is deliberate CLI stdout)
grep -nE '\bprint\(' <changed .py files>             | wc -l

# Any escape hatch
grep -nE ':\s*Any\b|->\s*Any\b' <changed .py files>  | wc -l

# Mutable default arguments
grep -nE 'def .*=\s*(\[\]|\{\}|set\(\))' <changed .py files> | wc -l
```

Also review by eye (not greppable) and report a count for:

- **Non-PEP-257 docstring shape.** One-line docstrings whose closing `"""` is on its own line, a docstring on a leading-underscore method, "Returns..."-style non-imperative one-liners, or a public module, class, or method with no docstring at all.
- **Un-awaited coroutines.** In `async` code, a coroutine called without `await` and without being scheduled as a task. It never runs and the type checker will not catch it.

---

## Forbidden-pattern audit: report format (Python)

Emit the audit as this section, with the real integer counts filled in:

```
## Forbidden-Pattern Audit (Python)
- bare `except:`: 0 occurrences
- `except ...: pass`: 0 occurrences
- re-raise missing `from`: 0 (or list file:line)
- `print(` as logging: 0 (or list file:line + justification)
- `: Any` / `-> Any`: 0 occurrences
- mutable default arguments: 0 occurrences
- non-PEP-257 docstrings: 0 (or list file:line)
- un-awaited coroutines: 0 (or list file:line)
```

Any count above zero must be fixed before reporting, or carried with a per-occurrence justification. "All clean" is not acceptable phrasing; report numbers. If the target repo's `CLAUDE.md` names additional forbidden patterns, add them to this audit for that repo.

---

## Async Python

Applies when the changed code uses `async def`. These are properties of the language and its standard-library event loop, not of any framework.

- **Every coroutine is awaited.** A coroutine called without `await` and without being scheduled as a task never runs. It produces a `RuntimeWarning` at best and a silent no-op at worst, and no type checker catches it. This is the most common async defect there is.
- **Never block the event loop.** A synchronous file, network, or subprocess call, or `time.sleep`, inside `async def` stalls every other task on that loop. Use the async equivalent, or hand the blocking call to an executor.
- **A fire-and-forget task needs a live reference.** The event loop holds only a weak reference to a task, so a bare `create_task(...)` whose result is discarded can be garbage collected mid-flight. Keep the reference until it finishes, and retrieve its exception so a failure is not swallowed.
- **Cancellation is not an error to swallow.** Since Python 3.8, `asyncio.CancelledError` inherits from `BaseException`, so `except Exception` correctly passes it through, but a bare `except:` swallows it and breaks cancellation. Cleanup in a `finally` block must itself tolerate being cancelled.
- **Do not drive coroutines by hand in tests.** Use whatever async support the repo's test runner provides rather than calling `asyncio.run` or stepping the loop inside a test body.

---

## What does not belong in this file

The test for anything in this file: **would this rule be true of ANY repo in this language?** If it is only true of repos that happen to use a particular library, ORM, test framework, queue, or architecture, it is a stack fact, not a language fact, and it must not be here. Putting it here means every Python repo gets lectured about libraries it does not use.

The following categories are **deliberately absent** and belong in the target repo's own `CLAUDE.md`:

| Category | Examples of what belongs there instead |
|----------|----------------------------------------|
| Layer architecture and directory layout | Package structure, what may depend on what, where the composition root lives |
| The project's chosen test framework | Test runner, parametrization form, async plugin and mode, fixtures, file placement, coverage targets |
| Shared test infrastructure | Named fixtures, factories, and fakes the repo already ships |
| Data-modeling and validation libraries | Model construction and validation calls, config style, alias and field conventions, mutable-default idioms specific to that library |
| HTTP client libraries and their test doubles | Which client, which mocking layer, how outbound requests are asserted |
| Logging setup and conventions | Which logger, structured versus stdlib, event naming, field schema, redaction policy |
| Serialization choices | Which JSON or binary serializer, and when a faster one is worth the dependency |
| ORM and query-builder usage | Query idioms, session and transaction handling, migration rules |
| Message-queue and job semantics | Retry, idempotency, visibility timeouts, concurrency defaults |
| Deployment and configuration | Settings loading, secrets handling, environment conventions |
| "Verify before flagging" facts | Codebase-specific facts that defuse a finding, such as which layer already validated an input |

If a rule you want to add would be false in another Python project, it is a repo rule, and it goes in that repo's `CLAUDE.md`.
