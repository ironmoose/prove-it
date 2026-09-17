---
description: "Optional setup wizard for prove-it. Interactive: choose an express path (sensible defaults, under a minute) or a guided walkthrough with one-line explanations. Detects the target repo's language(s) and which built-in convention overlays apply, offers to draft repo-specific conventions, lets you pick a review-comment style, and optionally installs the binding quality-gate enforcement hook with folder exemptions. Persists every choice to ~/.claude/prove-it/config.json, so re-running the wizard is a fast targeted edit instead of a full re-walk. prove-it works out of the box; this wizard is convenience only."
argument-hint: "(no arguments)"
---

# prove-it Setup Wizard

You are running the optional setup wizard for prove-it. Walk through each step sequentially, one interaction at a time: show the result, then move to the next step.

Every step here is OPTIONAL. This is a convenience wizard, not a requirement. Do not gate any real prove-it functionality on having run it.

Your choices are persisted to `~/.claude/prove-it/config.json` (mechanics in "Config Persistence" below). That is what makes this wizard safe and fast to re-run: it shows you what is already set and lets you change one thing at a time instead of starting over.

## Step 0: Check for an Existing Config (return-user fast path)

Before anything else, check whether `~/.claude/prove-it/config.json` exists. `GATE_DIR = ~/.claude/prove-it`.

- If it does NOT exist, or exists but fails to parse, this is a first-time run. Skip this step and continue to Step 1 for the full wizard.
- If it exists and parses, this is a returning user. Read it and show the current settings in plain language, then offer a menu. For example:

  ```
  prove-it is already set up here. Current config:

    Languages detected last time : TypeScript, Python
    Quality-gate hook            : installed
    Exempt folders               : notes
    Comment style                : what-fix-why (default)

  What do you want to change?

    1. Detected languages (re-run detection)
    2. Exempt folders (gate)
    3. Comment style
    4. Quality-gate hook (install / uninstall)
    5. Run the full wizard again from scratch
    6. Nothing, just run a review  ->  /prove-it:review

  Pick a number, or describe what you want changed.
  ```

  Route each pick to a direct, single-step edit, then stop (do not fall through to the rest of the wizard):

  - **1**: Re-run the detection logic in Step 2, show the new result, update `languages` in the config.
  - **2**: Ask "Exempt folders today: `<current list, or none>`. Add, remove, or replace?" then persist the resulting `exempt_folders`.
  - **3**: Jump straight to Step 5 (Review Comment Style) below, skipping every other step, then return here.
  - **4**: If currently installed, ask "Uninstall the gate hook? (yes/no)". If yes, surgically remove the `PreToolUse` entry whose `command` contains `gate-check.sh` from `~/.claude/settings.json` (leave every other key and every other hook entry untouched) and set `hook_installed` to `false` in the config. If not currently installed, jump to Step 4 below to offer installing it.
  - **5**: Proceed as a first-time run from Step 1 onward. You may pre-fill each default from the existing config instead of the blank defaults, since the user already has values on record.
  - **6**: Print a one-line pointer to `/prove-it:review` and stop. Nothing to change; setup already ran.

  After completing edit 1-4, re-print the resulting current config for confirmation and stop there.

First-time users (no existing config): move to Step 1.

## Step 1: Welcome, Then Express or Guided

Print:

```
prove-it is a standalone code-review + verification harness: a panel of
parallel reviewers finds issues, and no finding counts until a script
reproduces it (repro-verify -> fix -> confirm-fix -> promote to a regression
test).

It works out of the box with no setup. This wizard is optional customization:
it tells you which convention overlays apply to this repo, shows you where to
put project-specific rules, lets you pick how review comments read, and can
install the binding quality-gate hook. Your choices are saved so you can
re-run this wizard later and change just one thing.

Let's go.
```

Then ask, once, up front:

```
Two ways to do this:

  express  - accept sensible defaults, done in under a minute
  guided   - walk through each choice with a one-line explanation of what
             it does for you and what it costs, before you decide

Which one? [default: express]
```

Remember the answer for the rest of the wizard:

- **Guided mode**: before each real decision, give a one-line "what this does for you" then "what it costs" explanation, in that order, before asking the question. Introduce a term in one plain sentence the first time it comes up (sub-agent, repro-verify, Confirmed / Proven-safe / Inconclusive, the quality gate, a convention overlay). If the user says "tell me more" (or similar) about any of these, give a fuller explanation before moving on; otherwise keep it to the one sentence.
- **Express mode**: move straight to the default for each choice, only stopping at the handful of real decisions (express/guided fork, gate install, comment style). Skip the optional conventions-drafting offer in Step 3 entirely. The goal is a working config in under a minute.

Move to Step 2.

## Step 2: Detect Language(s) and Report Applicable Overlays

prove-it ships two baseline convention overlays that its language-sensitive reviewer agents read before judging a change:

- `reference/typescript-conventions.md` applies to `.ts` / `.tsx` files.
- `reference/python-conventions.md` applies to `.py` files.

First, make sure the wizard is pointed at a single repo, not a workspace root:

- Check whether the current directory is itself inside a git work tree with `git rev-parse --is-inside-work-tree 2>/dev/null`.
- If it is NOT a work tree but the directory contains nested git repos (probe with `find . -maxdepth 2 -name .git -type d 2>/dev/null`), this is a workspace root, not a single target repo. Do NOT run per-repo language detection against the whole tree: the bounded `find` fallback below can be huge at a workspace root, and the results would mix unrelated repos. Instead, either tell the user to re-run the wizard from inside the specific target repo, or enumerate the nested repos you found and let them pick one to point the rest of setup at.

Once you are inside a single repo, detect what it uses:

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

   In guided mode, on first mention add one sentence: "This is called a convention overlay: a baseline style guide the review agents read before judging your diff." Express mode skips that sentence.

3. State clearly that the target repo's own `CLAUDE.md` (if present) is authoritative and wins over these overlays. Check for one:
   - Look in three places, because the authoritative `CLAUDE.md` for the target repo may not sit exactly where the wizard was run: the repo root (`git rev-parse --show-toplevel`, or the cwd if this is not a git repo), the nearest nested `CLAUDE.md` relative to where work happens, and one directory UP from the cwd (the target-repo `CLAUDE.md` sometimes lives one level above the directory you launched the wizard in).
   - If found, print: `This repo has a CLAUDE.md; its rules are authoritative and win over the shipped overlays.`
   - If not found, print: `No repo CLAUDE.md found. The shipped overlays plus general good practice will be the baseline.`

4. Persist the detected language list to `languages` in the config (see Config Persistence).

Move to Step 3.

## Step 3: Convention Precedence (guided: offer to draft; express: informational only)

**Guided mode:** print the full explanation and offer to draft.

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

**Express mode:** print only the short version and do not ask to draft anything:

```
Convention precedence: session override > repo CLAUDE.md > shipped language
overlay > general good practice. Add project rules to your own CLAUDE.md;
you don't need to touch plugin files.
```

Do NOT direct the user to edit the shipped overlay files under the plugin's `reference/`. Those are the baseline; project-specific rules belong in the repo's CLAUDE.md.

Move to Step 4.

## Step 4: Quality-Gate Enforcement Hook (OPTIONAL, defaults to NOT installing) and Exemptions

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

If **no** (or the user presses Enter): persist `hook_installed: false` and move to Step 5.

If **yes**, perform the install exactly as the gate's own README specifies (`gate/README.md`, "Installation"):

**1. Install the scripts (idempotent):**
- `GATE_DIR = ~/.claude/prove-it`. This is not a choice; both `prove-it-gate` and `gate-check.sh` hardcode it, so installing anywhere else would leave the scripts unable to find their own state.
- Create `$GATE_DIR` if it does not exist, then copy `${CLAUDE_PLUGIN_ROOT}/gate/prove-it-gate` and `${CLAUDE_PLUGIN_ROOT}/gate/gate-check.sh` into it. For each script: if a deployed copy does NOT already exist, or is byte-identical to the plugin's copy, copy it in without prompting. If a deployed copy DOES exist and DIFFERS from the plugin's copy (`diff "$GATE_DIR/<script>" "${CLAUDE_PLUGIN_ROOT}/gate/<script>"`), show the diff and ask the user to confirm before overwriting, so a local modification to a deployed script is never silently clobbered by a plugin-version update. Do NOT touch any runtime state that already lives alongside them (`gate-state.json`, `gate-verdicts.json`, `history/`, `override-log.txt`, `repros/`, `config.json`).
- `chmod +x` both copied files.
- Stamp the deployed version so `prove-it-gate version` can report it: read the plugin's version from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` (`jq -r .version "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"`, or a `grep`/`sed` fallback if `jq` is absent) and write it to `$GATE_DIR/VERSION`.

**2. Put `prove-it-gate` on PATH:**
- Symlink `~/.local/bin/prove-it-gate` to `$GATE_DIR/prove-it-gate`, creating `~/.local/bin` if it does not exist.
- If something already exists at `~/.local/bin/prove-it-gate` and it is not already this symlink, do NOT overwrite it. Print a warning naming the conflict and skip this step; the CLI still works when invoked by its full path (`~/.claude/prove-it/prove-it-gate`).

**3. Register the PreToolUse hook (surgical merge, never clobber):**
- If `~/.claude/settings.json` exists, read and parse it as JSON. If it does not exist, start from `{}`.
- Idempotency check: inspect every string under `hooks.PreToolUse[*].hooks[*].command` for the substring `prove-it`. If any match is found, the hook is already installed. Print `prove-it quality-gate hook already installed at: ~/.claude/settings.json. Skipping.` and continue to the exemption question below.
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

Then ask about exemptions:

```
Is there a folder we should exempt from the gate's edit-block? (for example
a run-log, notes, or bookkeeping directory you edit outside of reviewed
changes)

Built-ins are always exempt regardless of this answer: ~/.claude/prove-it/,
/tmp/, and any actual */scratchpad directory.

Folder(s) to exempt (comma-separated), or Enter for none:
```

Split the answer on commas, trim whitespace, drop empties, and persist the result as `exempt_folders` (an empty answer persists `[]`). Persist `hook_installed: true`.

Then print:

```
Quality-gate hook installed at: ~/.claude/settings.json
prove-it-gate CLI: ~/.local/bin/prove-it-gate (or ~/.claude/prove-it/prove-it-gate directly)
Deployed gate version: <version>   (check anytime with: prove-it-gate version)
Exempt folders: <list, or "none">
Read gate/README.md (in the plugin source) for the open / verify / confirm-fix / close cycle.
Override a block anytime with: prove-it-gate override --reason "..."
```

Move to Step 5.

## Step 5: Review Comment Style

Guided mode, one line first: "What this does for you: review comments come back in a shape you actually want to read. What it costs: nothing, just a pick." Express mode skips straight to the question.

Ask:

```
How do you want review comments to read? The review command applies
whichever style you pick.

  1. what-fix-why (default) - "<prefix>: <one scope line>", then what: / fix:
     / why: lines. One prefix from must/should/nit/opinion/idea/question/
     praise. Short plain sentences, inline, no summary body.
  2. one-liner               - a single "<prefix>: <message>" line.
  3. detailed                - what/fix/why plus room for evidence and
     references.
  4. custom                  - describe or paste your own format.

Pick 1-4 [default: 1]:
```

- **1 (or Enter)**: persist `comment_style.template = "what-fix-why"`, `comment_style.custom_body = null`.
- **2**: persist `comment_style.template = "one-liner"`, `comment_style.custom_body = null`.
- **3**: persist `comment_style.template = "detailed"`, `comment_style.custom_body = null`.
- **4**: ask "Describe or paste the format you want review comments to follow:", then persist `comment_style.template = "custom"` and `comment_style.custom_body = <what they gave, verbatim>`.

Note plainly: `/prove-it:review` reads this setting and applies it; nothing else to do here.

Move to Step 6.

## Step 6: First-Review Hand-Hold (OPTIONAL)

Ask:

```
First time running prove-it? (yes / no)
```

If **yes**, explain briefly before anything runs:

```
/prove-it:review dispatches a panel of single-purpose reviewer sub-agents
(a sub-agent is a focused, disposable worker Claude spawns for one job) at
your diff, a PR, or a path. Each finding then goes through repro-verify: a
script actually reproduces the bug before it counts. A finding lands as
Confirmed (the repro failed, it's real), Proven-safe (the repro passed, the
concern didn't hold up), or Inconclusive (couldn't prove it either way).

The result line reads like "3 of 7 real": 7 raised, 3 Confirmed by a repro.
Only Confirmed findings are must-fix. Run it with:

  /prove-it:review
```

If **no**: skip with a one-line pointer: "Fine, jump in anytime with `/prove-it:review`."

Move to Step 7.

## Step 7: Quickstart

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

Your choices are saved in ~/.claude/prove-it/config.json. Run
/prove-it:setup again anytime to change one thing, no need to redo it all.

That's it. Setup is complete (and optional to re-run; it's idempotent).
```

Setup is complete.

## Config Persistence (applies throughout)

Every step above that says "persist" writes to `~/.claude/prove-it/config.json` (`GATE_DIR = ~/.claude/prove-it`). Persist each decision right after the user makes it, not batched at the end, so a wizard interrupted partway through still leaves earlier choices saved.

The schema:

```json
{
  "version": 1,
  "languages": ["typescript", "python"],
  "hook_installed": true,
  "exempt_folders": ["notes"],
  "comment_style": { "template": "what-fix-why", "custom_body": null }
}
```

Mechanics:

- Create `GATE_DIR` if it does not already exist.
- If `jq` is available, read the existing `config.json` (or start from `{}` if absent), set only the field(s) this step changed with `jq`, and write the result back. If `jq` is not available, fall back to a careful heredoc that reads and reconstructs the whole object; do not hand-splice JSON with `sed`.
- Always MERGE: a write from one step must never clobber fields another step already set (for example, changing `comment_style` must not reset `exempt_folders`). Read-modify-write, never blind-overwrite.
- Keep the file pretty-printed (2-space indent) so a user can read or hand-edit it.
- Writing `config.json` must never fail the wizard. If the write fails for any reason (permissions, disk, malformed existing file), report it plainly and continue; a persistence failure is a warning, not a blocker.

## Style Rules

- No em-dashes in running text.
- Each step is one interaction: show the result, then move on.
- Every step is optional; never block prove-it usage on setup having run.
- Idempotent: re-running setup MUST NOT duplicate hook entries or clobber existing settings or config. Always merge, never overwrite.
- Never direct the user to edit the shipped `reference/` overlay files; project rules go in the repo's CLAUDE.md.
- Returning users (existing `config.json`) get the Step 0 fast-path menu, not a forced full re-walk.
- In guided mode, lead every real decision with what it does for the user, then what it costs, before asking. In express mode, default straight through except at the express/guided fork, the gate install question, and the comment-style pick.
