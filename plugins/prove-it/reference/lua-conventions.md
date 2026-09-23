# Lua conventions overlay

Language baseline for Lua work. The orchestrator injects this file into the prompts of language-sensitive agents (implementer, test-writer, code-reviewer, code-smells-reviewer, test-reviewer, edge-case-qa) when the changed files are `.lua`. It carries only rules that are true of the *language*. Anything true of a particular host (WoW, Neovim, Roblox, LOVE, OpenResty), repo, or deployment belongs in that repo's own `CLAUDE.md`.

---

## Precedence: this is the baseline; the target repo's CLAUDE.md wins

This overlay is a floor, not a ceiling, and it never displaces a committed standard.

- **Read the target repo's `CLAUDE.md` first**, root plus the nearest nested one relative to the changed files, and defer to it wherever it speaks.
- **Do not go rogue.** If the repo says something different, the repo is right for that repo. Follow it and flag the divergence rather than silently overriding.
- **State the Lua version you are targeting.** 5.1, 5.2, 5.3, 5.4 and LuaJIT differ in ways that change correct code (integer subtype, `goto`, `_ENV` vs `setfenv`, `//`, bitwise operators). Embedded hosts are often pinned to an old one: WoW and many game engines are 5.1, Neovim is LuaJIT (5.1 with extensions), Roblox is a 5.1 derivative. Never assume 5.4 semantics in an embedded codebase.

| Priority | Source |
|----------|--------|
| 1 | Session override from the user |
| 2 | Target repo `CLAUDE.md` (root plus nearest nested) |
| 3 | This overlay |
| 4 | General good practice for the detected stack |

Two invariants hold **within this overlay**:

- **No size caps on CODE.** No function-length or file-length limit. Readability is hops, not lines. This exemption covers code only, not comments.
- **No host rules live here.** Guidance for a specific engine's API is a stack fact and belongs in the target repo's `CLAUDE.md`.

---

## The scope rule, and why it is the first thing in this file

**A local's scope begins at the first statement AFTER its declaration.** This is not style, it is the language definition, and in a dynamically-scoped-looking language with implicit globals it is the single most damaging Lua footgun.

From the reference manual: *"The scope of a local variable begins at the first statement after its declaration and lasts until the last non-void statement of the innermost block that includes the declaration."*

The consequence is what hurts. A name that is not a local in scope is **a global**, and reading an unset global is not an error, it yields `nil`. So a local referenced above its own declaration does not fail loudly at the reference; it silently becomes a different variable holding `nil`, and fails later at the point of use, with a message pointing at the wrong place.

```lua
local function draw()
  return SIZE * 2      -- SIZE here is a GLOBAL, nil, not the local below
end

local SIZE = 10        -- too late for draw()
```

If that reference sits at **file scope** rather than inside a function body, the arithmetic on `nil` throws while the chunk is loading, and in many embedded hosts the entire file is then discarded. The symptom is not an error near the mistake; it is a whole module silently not existing.

**Rules:**

- **Declare constants in one block at the top of the file**, above every consumer.
- **Forward-declare any local function used above its definition.** The idiom is in PIL 6.2:
  ```lua
  local f, g    -- forward declarations

  function g() ... f() ... end
  function f() ... g() ... end
  ```
  Note the definitions use `function g()` and not `local function g()`; a second `local` would create a *new* variable and leave the forward declaration nil.
- **`local function f` is the correct form for self-recursion.** It is sugar for `local f; f = function() ... end`, so the name is in scope inside the body. `local f = function() ... f() ... end` is NOT: the `f` inside the body is a global.
- **A syntax-only parse check cannot catch any of this.** The file is valid Lua that means something else. Static analysis that resolves names is required: `luacheck` reports it as "accessing undefined variable".

---

## Multiple returns are truncated almost everywhere

A function call yields all its results only when it is **the last element** of an expression list. Everywhere else, and anywhere a single expression is expected, the result list is adjusted to exactly one value (reference manual 3.4.12).

The trap is the idiomatic guard, which reads as safe and silently loses data:

```lua
local parts = obj.GetParts and obj:GetParts() or {}   -- WRONG: one part, not all
```

`obj:GetParts()` sits inside an `and`, which expects a single expression, so every result after the first is discarded. Write it out:

```lua
local parts = {}
if obj.GetParts then parts = { obj:GetParts() } end    -- table constructor keeps them all
```

Related consequences to watch for in review:

- `f(g())` passes all of `g()`'s results; `f(g(), x)` passes only the first.
- `{f()}` captures all results; `{f(), nil}` captures one.
- Parentheses force exactly one result: `(f())`. Use them deliberately, and never by accident around a call whose extra returns matter.
- `select("#", ...)` counts varargs **including embedded nils**; `#{...}` does not.

---

## `and`/`or` is not a ternary

`a and b or c` yields `c` whenever `b` is `nil` or `false`, not only when `a` is falsy. It is correct only when `b` can never be falsy. A boolean-valued `b` makes it a bug:

```lua
local visible = enabled and false or true   -- always true
```

Use an `if`. Only `nil` and `false` are falsy in Lua: `0` and `""` are both **true**, which is the opposite of C, Python and JavaScript.

---

## Globals are opt-in discipline, not a default

An assignment to an undeclared name creates a global. There is no error and no warning.

- **Everything is `local` unless it must be shared.** Locals are register or upvalue accesses; globals are a hash lookup in `_ENV` every time.
- **Localize hot library functions** at the top of a module when they are called in a loop: `local floor, insert = math.floor, table.insert`. Do this for measured hot paths, not reflexively.
- **A module returns a table.** `local M = {} ... return M`. Do not write into `_G` to publish an API.
- **Run a linter that flags implicit globals.** A typo in an assignment target creates a new global and the old one silently keeps its value; nothing else will catch it.

---

## Tables

- **`#t` is only defined for sequences** (keys 1..n with no holes). On a table with a hole it may return any border. Keep an explicit count when the table can be sparse.
- **`ipairs` stops at the first `nil`.** If a list can contain holes, iterate `for i = 1, n` with a count you maintain.
- **`pairs` order is unspecified** and varies between runs. Never rely on it for anything the user sees; sort the keys when order matters.
- **Removing entries while iterating with `pairs` is allowed only for the current key.** Assigning to other fields during traversal is undefined.
- **Build strings with `table.concat`, not `..` in a loop.** Repeated concatenation is quadratic because strings are immutable and interned.
- **`table.insert(t, v)` and `t[#t + 1] = v` are equivalent** for appends; prefer the latter in hot paths and the former when the intent is clearer.

---

## Strings

- **Lua patterns are not regular expressions.** There is no alternation, no `\d`, and no arbitrary repetition of groups. Character classes are `%a %d %s %w`, the escape is `%` and not `\`, and `-` is the lazy quantifier. Do not port a regex; rewrite it.
- **Escape user input before using it as a pattern.** `("%W")` handling: `s:gsub("(%W)", "%%%1")` makes an arbitrary string literal-safe.
- **`string.format` over concatenation** for anything with more than two pieces, both for readability and for `%d`/`%.2f` control.

---

## Errors

- **`error(msg, level)` and `pcall`/`xpcall` are the mechanism.** `error` with level 2 blames the caller, which is usually what a library wants.
- **An error value need not be a string.** A table carries structured detail; a string loses it.
- **Do not wrap everything in `pcall`.** A `pcall` that swallows and continues turns a crash into corrupted state and a support ticket. Catch where you can genuinely recover, and let the rest propagate.
- **Some embedded hosts forbid `pcall` in sandboxed callbacks.** If the target repo says so, believe it; that is a host fact and belongs in its `CLAUDE.md`.

---

## Hygiene

- **A comment states intent, in three sentences at most.** One or two is the norm. Say what the code is for, or what constraint the next edit must not break. No derivations, no measured numbers, no rejected alternatives, no ticket references. Evidence that outlives the line belongs in the commit message.
- **Name modules for their subject, never their role.** Banned: `utils`, `helpers`, `common`, `misc`, `base`.
- **`nil` means absent; `false` means the value false.** Do not use `nil` to mean "off" when the field is a boolean, or a reader cannot distinguish unset from disabled.
- **Prefer `:` method syntax consistently** within a type. Mixing `obj.method(obj)` and `obj:method()` in one file makes the implicit `self` invisible.
- **Metatables are earned, not assumed.** `__index` for inheritance or defaults is fine; a metatable that makes ordinary field access do something surprising is a debugging tax on everyone after you.
- **Do not use `setfenv`/`getfenv` in new code** (removed after 5.1); use `_ENV` on 5.2+, or explicit tables.

---

## Static analysis, and what it can and cannot prove

- **`luacheck` is the standard linter.** It catches the things this file warns about that a human review misses: undefined globals (which is what the scope bug looks like to a checker), unused locals, shadowing, and accidental global assignment. If the repo has no `.luacheckrc`, that is a gap worth flagging, especially for an embedded host whose API globals must be declared or every call reads as undefined.
- **A syntax-only gate proves almost nothing.** "It parses" and "the names resolve" are different questions, and every bug in the scope section above parses cleanly.
- **Lua rarely has a runnable unit-test harness in an embedded host.** Where the code cannot be executed outside its host (a game addon, an engine script), say so plainly rather than reporting untested code as verified. `busted` and `luaunit` work for pure-logic modules; extract logic away from host API calls so that at least that part is testable.
