---
description: "Optional setup wizard for prove-it. Detects the target repo's language(s) and which built-in convention overlays apply, offers to customize conventions (via your repo's CLAUDE.md), and optionally installs the binding quality-gate enforcement hook. prove-it works out of the box; this wizard is convenience only."
argument-hint: "(no arguments)"
---

# prove-it Setup Wizard

You are running the optional setup wizard for prove-it. Walk through each step sequentially. Show results as you go, then move to the next step.

Every step here is OPTIONAL. This is a convenience wizard, not a requirement. Do not gate any real prove-it functionality on having run it.

## Step 1: Welcome

Print:

```
prove-it is a standalone code-review + verification harness: a panel of
parallel reviewers finds issues, and no finding counts until a script
reproduces it (repro-verify -> fix -> confirm-fix -> promote to a regression
test).

It works out of the box with no setup. This wizard is optional customization:
it tells you which convention overlays apply to this repo, shows you where to
put project-specific rules, and can install the binding quality-gate hook.

Let's go.
```

Move to Step 2.

## Step 2: Detect Language(s) and Report Applicable Overlays

prove-it ships two baseline convention overlays that its language-sensitive reviewer agents read before judging a change:

- `reference/typescript-conventions.md` applies to `.ts` / `.tsx` files.
- `reference/python-conventions.md` applies to `.py` files.

Detect what the target repo uses:

1. From the current working directory, sample the repo's tracked files. A cheap probe:
   - `git ls-files '*.ts' '*.tsx' '*.py' 2>/dev/null | head -n 50` if this is a git repo, otherwise a bounded `find . -maxdepth 4 \( -name '*.ts' -o -name '*.tsx' -o -name '*.py' \)`.
   - Also note presence of `tsconfig.json`, `package.json`, `pyproject.toml`, `setup.py`, or `requirements.txt` as corroborating signals.
2. Report which overlays apply. For example:

   ```
   Detected: TypeScript (.ts/.tsx) and Python (.py).

   Overlays that will apply during review:
     - TypeScript conventions overlay  -> .ts / .tsx files
     - Python conventions overlay      -> .py files
   ```

   If only one language is present, report just that one. If neither is present, say so plainly: prove-it still reviews the change; it just has no baked language overlay for it, and falls back to the target repo's own conventions plus general good practice.

3. State clearly that the target repo's own `CLAUDE.md` (if present) is authoritative and wins over these overlays. Check for one:
   - `git rev-parse --show-toplevel` (or the cwd) plus the nearest nested `CLAUDE.md` relative to where work happens.
   - If found, print: `This repo has a CLAUDE.md; its rules are authoritative and win over the shipped overlays.`
   - If not found, print: `No repo CLAUDE.md found. The shipped overlays plus general good practice will be the baseline.`

Move to Step 3.

## Step 3: Customize Conventions (OPTIONAL)

Explain the precedence, then point the user at the recommended path (their repo's CLAUDE.md), not editing plugin files.

Print:

```
Convention precedence during a review (first match wins):

  1. Session override you give at review time
  2. Target repo CLAUDE.md (root plus the nearest nested one)
  3. The shipped language overlay (TypeScript / Python)
  4. General good practice for the detected stack

Recommended way to add project-specific rules: put them in your repo's own
CLAUDE.md. That keeps them versioned with the code, shared with your team, and
authoritative over the shipped overlays. You do NOT need to edit any plugin
files.

Want help drafting a conventions section for this repo's CLAUDE.md? (yes / no)
```

If **yes**:
- If the repo has a `CLAUDE.md`, read it and propose an appended "## Conventions" (or project-appropriate) section, showing the user the draft before writing. Only write it after they approve.
- If the repo has no `CLAUDE.md`, offer to create one at the repo root with a conventions section, again showing the draft first.
- Keep the draft grounded in what you actually observe in the repo (lint config, existing style, framework), not generic boilerplate.

If **no**: skip.

Do NOT direct the user to edit the shipped overlay files under the plugin's `reference/`. Those are the baseline; project-specific rules belong in the repo's CLAUDE.md.

Move to Step 4.

## Step 4: Quality-Gate Enforcement Hook (OPTIONAL, defaults to NOT installing)

This is the piece that makes prove-it's repro-verification BINDING instead of advisory. It installs the `prove-it-gate` CLI and the `gate-check.sh` PreToolUse hook. While a review has an open gate with findings that have not been verified by an executable repro, the hook DENIES `Edit`, `Write`, `MultiEdit`, and `NotebookEdit`, and the edit does not happen.

It is opt-in and defaults to NOT installing, because it gates edits machine-wide (in this Claude session) while a review gate is open, not just in this repo.

Print:

```
Want to install the quality-gate enforcement hook? [default: no]

  What it does: while a prove-it review has findings not yet verified by an
  executable repro, it DENIES Edit/Write/MultiEdit/NotebookEdit until those
  findings are verified (prove-it-gate verify ...) or the gate is closed. This
  turns repro-verification from advice into enforcement.

  Scope: it installs to ~/.claude/settings.json and its state lives in
  ~/.claude/prove-it/. There is no project-scoped variant; both scripts
  hardcode that state directory. So it applies to every repo you edit in a
  session while a gate is open, not only this one.

  Escape hatch: you can always override a block with
    prove-it-gate override --reason "..."
  which is loud and logged (archived to history/ with the reason).

  One honest limitation: the hook binds only THIS session's own tool calls. It
  does not constrain a subagent's edits, and it does not see Bash writes (a
  sed -i or heredoc sails past it). It is a discipline aid for the main driver,
  not a sandbox.

  Install it? (yes / no)   [default: no]
```

If **no** (or the user presses Enter): skip to Step 5.

If **yes**, perform the install exactly as the gate's own README specifies (`gate/README.md`, "Installation"):

**1. Install the scripts (idempotent):**
- `GATE_DIR = ~/.claude/prove-it`. This is not a choice; both `prove-it-gate` and `gate-check.sh` hardcode it, so installing anywhere else would leave the scripts unable to find their own state.
- Create `$GATE_DIR` if it does not exist, then copy `${CLAUDE_PLUGIN_ROOT}/gate/prove-it-gate` and `${CLAUDE_PLUGIN_ROOT}/gate/gate-check.sh` into it. Overwrite existing copies so re-running setup picks up a plugin-version update, but do NOT touch any runtime state that already lives alongside them (`gate-state.json`, `gate-verdicts.json`, `history/`, `override-log.txt`, `repros/`).
- `chmod +x` both copied files.

**2. Put `prove-it-gate` on PATH:**
- Symlink `~/.local/bin/prove-it-gate` to `$GATE_DIR/prove-it-gate`, creating `~/.local/bin` if it does not exist.
- If something already exists at `~/.local/bin/prove-it-gate` and it is not already this symlink, do NOT overwrite it. Print a warning naming the conflict and skip this step; the CLI still works when invoked by its full path (`~/.claude/prove-it/prove-it-gate`).

**3. Register the PreToolUse hook (surgical merge, never clobber):**
- If `~/.claude/settings.json` exists, read and parse it as JSON. If it does not exist, start from `{}`.
- Idempotency check: inspect every string under `hooks.PreToolUse[*].hooks[*].command` for the substring `prove-it`. If any match is found, the hook is already installed. Print `prove-it quality-gate hook already installed at: ~/.claude/settings.json. Skipping.` and proceed to Step 5.
- If not found, merge this entry into `hooks.PreToolUse` (append if the array exists, create if it does not). Preserve all pre-existing keys:
  ```json
  {
    "matcher": "Edit|Write|MultiEdit|NotebookEdit",
    "hooks": [
      { "type": "command", "command": "~/.claude/prove-it/gate-check.sh", "timeout": 10 }
    ]
  }
  ```
  The `matcher` is load-bearing: `gate-check.sh` does not filter by tool name itself, so an entry without this matcher (or one that omits any of the four tools) would run the hook unscoped or leave a tool unguarded.
- Write the merged JSON back to `~/.claude/settings.json`, pretty-printed.

Then print:

```
Quality-gate hook installed at: ~/.claude/settings.json
prove-it-gate CLI: ~/.local/bin/prove-it-gate (or ~/.claude/prove-it/prove-it-gate directly)
Read gate/README.md (in the plugin source) for the open / verify / confirm-fix / close cycle.
Override a block anytime with: prove-it-gate override --reason "..."
```

Move to Step 5.

## Step 5: Quickstart

Print:

```
prove-it is ready.

Run a review:
  /prove-it:review                 Review your local uncommitted diff
  /prove-it:review <PR number|url> Review an open pull request
  /prove-it:review <path>          Review a specific path

Each review runs the loop: parallel reviewers -> repro-verify (Confirmed /
Proven-safe / Inconclusive) -> only Confirmed findings are real.

Then:
  1. Fix the MUST-FIX (Confirmed) findings.
  2. /prove-it:follow-up          Re-runs each Confirmed finding's own repro
                                  against the fixed code to confirm the fix,
                                  and promotes confirmed fixes into permanent
                                  regression tests.

A green repo test suite is NOT accepted as proof a fix worked; the finding's
own repro flipping from fail to pass is.

That's it. Setup is complete (and optional to re-run; it's idempotent).
```

Setup is complete.

## Style Rules

- No em-dashes in running text.
- Each step is one interaction: show the result, then move on.
- Every step is optional; never block prove-it usage on setup having run.
- Idempotent: re-running setup MUST NOT duplicate hook entries or clobber existing settings. Always merge, never overwrite.
- Never direct the user to edit the shipped `reference/` overlay files; project rules go in the repo's CLAUDE.md.
