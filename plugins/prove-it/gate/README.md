# prove-it verification gate

The prove-it workflow says a code-review finding is not settled until an
executable repro has proven it. This directory holds the two files that
*enforce* that, so the enforcement mechanism ships with the plugin instead of
living only on whichever machine it was first written on.

- `gate-check.sh`: the `PreToolUse` hook that blocks edits.
- `prove-it-gate`: the CLI that opens, verifies, and closes a gate cycle.

Both are plain bash and need `jq`, `sha256sum`, and `realpath`. They also use
`flock` (util-linux) to serialize concurrent state writes -- see
[Concurrency](#concurrency) below for what happens if it's missing.

## What the gate does

`gate-check.sh` is registered as a `PreToolUse` hook matching
`Edit|Write|MultiEdit|NotebookEdit`. While a quality gate is open with findings
that have not been verified by execution, the hook returns
`permissionDecision: deny` and the edit does not happen. The reason it prints
names the specific finding ids that are blocking and the exact command to clear
them.

The hook **fails open**: a missing `jq`, malformed state, or any unexpected
error allows the edit through. It must never be the reason ordinary editing
gets stuck. It also exempts its own state directory, anything under `/tmp`,
and any actual `scratchpad` directory (a path ending in `/scratchpad`, or
with `/scratchpad/` as a path segment) so a repro script can be written
while the gate is closed against application code. The scratchpad match is
an anchored directory-component match, not a substring match, a real
project file merely named e.g. `scratchpad-ideas.md`, or living under a
directory like `scratchpad-notes/`, is not exempt. `/tmp/*` is already a
prefix match anchored at the start of the path, so it has no equivalent
substring gap.

## Configuration (config.json)

An optional shared config file lives at `$GATE_DIR/config.json` (the same
directory as `gate-state.json`, i.e. `~/.claude/prove-it/config.json` by
default). It is written by the setup wizard and read by both the wizard
and the review command; `gate-check.sh` itself reads only one field out of
it, `exempt_folders`. The other fields exist here for completeness, but the
gate does not consume them.

```json
{
  "version": 1,
  "languages": ["typescript", "python"],
  "hook_installed": true,
  "exempt_folders": ["notes"],
  "comment_style": { "template": "what-fix-why", "custom_body": null }
}
```

- `version`: schema version of this file. Not read by the gate.
- `languages`: the languages the setup wizard configured for this project.
  Not read by the gate.
- `hook_installed`: whether the wizard has registered this hook in
  `~/.claude/settings.json`. Not read by the gate.
- `exempt_folders`: additional folders the gate should always allow edits
  to, on top of the built-in exemptions described above. This is the only
  field `gate-check.sh` reads.
- `comment_style`: the review command's comment template and optional
  custom body text. Not read by the gate.

### exempt_folders matching rule

Each entry is matched with the same anchored path-component discipline as
the built-in scratchpad exemption above, never a plain substring match:

- A trailing slash on the entry is stripped before matching.
- An entry that starts with `/` is treated as an absolute path: it exempts
  the target file when the target path equals that entry, or begins with
  `<entry>/`.
- Any other entry (a bare name like `notes`, or a relative path like
  `docs/generated`) is treated as a path-component sequence: it exempts the
  target file when that sequence appears as a whole path component in the
  target path, i.e. the path contains `/<entry>/` or ends with `/<entry>`. It
  also exempts the target when the target path itself has no leading path
  component and either equals the entry or starts with `<entry>/`, i.e. a
  relative path passed through as-is (with nothing before the entry to match
  a leading `/` against).

So `"notes"` exempts `.../notes/a.md` and `.../project/notes`, but does NOT
exempt `.../notes-ideas.md` or `.../project/notes-archive/x.md`, because
`notes-ideas` and `notes-archive` are different path components than
`notes`, not the same one with extra characters tacked on. It also exempts a
bare relative target of `notes` or `notes/a.md` (no directory prefix at all).

### Fails open

`config.json` is entirely optional. If it does not exist, cannot be read,
or is not valid JSON, `gate-check.sh` behaves exactly as it would with no
config file at all: only the built-in exemptions apply, nothing errors,
and no edit is denied because of it. This follows the same fail-open
discipline documented above for a missing `jq` or malformed
`gate-state.json`.

## The cycle

### Open

```
prove-it-gate open --target <description> --finding <ID>:<FILE>:<SUMMARY> [--finding ...]
```

Records the findings and flips the state to `findings-open`. From this moment
edits are blocked. `FILE` is normalized to an absolute path; it is the file the
verification will later be bound to.

### Verify

```
prove-it-gate verify <ID> --repro <path> [--proven-safe | --inconclusive] [--reason <text>]
```

This **executes** the repro. It does not take your word for the verdict.

- Default (**Confirmed**) requires the repro to exit **non-zero**. A repro that
  passes does not demonstrate a defect, so a zero exit is rejected outright.
- `--proven-safe` requires the repro to exit **zero**. This drops the finding
  and explicitly does *not* authorize edits to the file, nothing is being
  fixed, the concern was shown to be unfounded.
- `--inconclusive` requires `--reason` and keeps the finding blocking. An
  inconclusive verification without a documented reason is not a verification.

The repro is run directly if executable, otherwise via `bash` for `.sh` and
`python3` for `.py`. Anything else is refused rather than guessed at.

### Digest binding

Every Confirmed verification records the SHA-256 of the finding's file at the
moment of verification. The hook re-checks that digest on each edit and denies
on mismatch. A verification therefore goes stale the instant the file changes,
you cannot verify a finding once and then keep editing the file indefinitely on
the strength of it. Proven-safe entries are exempt, since they authorize no
edits and so have nothing to bind.

A confirmed fix (`confirm-fix`, below) re-digests the file *after* the fix and
records that as a second digest alongside the original. The hook accepts
either digest as current, the pre-fix one (nothing has changed yet) or the
post-fix one (the fix landed and was confirmed), so a properly confirmed fix
does not immediately re-lock its own file. Only a file that matches *neither*
digest is treated as stale.

### Confirm the fix

```
prove-it-gate confirm-fix <ID>
```

Re-runs the repro that was recorded for that finding and requires it to now
**pass** (exit zero). This is the confirm-fix step: it closes the red-green
loop that `verify` opened. If the repro still fails, nothing is recorded and the
work goes back to the fix step.

A green repo test suite does not substitute for this. Those tests did not catch
the defect in the first place, so their passing says nothing about whether it is
gone.

### Repro scratch dir

```
prove-it-gate repro-dir [ID]
```

Prints the canonical durable directory for a repro-verifier's scratch work and
creates it if missing: `~/.claude/prove-it/repros/<ID>/` with an ID, or the
`repros/` root with none. This is the fix for a real gap: a repro script
written to `/tmp` or a session-scoped scratchpad survives only that one Claude
session, and `confirm-fix` needs the *same* script to still exist whenever the
fix eventually lands, which is often a different session entirely. Rooting the
dir under `$GATE_DIR` means it is already outside the repo working tree (the
repro-verifier is correctly forbidden from writing inside the target repo) and
already exempt from `gate-check.sh`'s edit-blocking hook, the same as the rest
of this tool's state.

The orchestrator resolves this path once, at the point it first spawns the
repro-verifier, and inlines the absolute path into that agent's prompt. Every
later re-spawn against the same finding, including `confirm-fix`'s in a later
session, is handed that same resolved path, so a missing repro under it is a
real anomaly to surface, not an expected consequence of time passing.

In a prove-it review, the orchestrator passes a stable identifier for the
change under review (for example the pull request number or the branch name)
as ID, so every repro-verifier spawn against a given review resolves to the
same durable directory regardless of session.

ID is sanitized to `[A-Za-z0-9._-]` only (it becomes a path component); the
literal strings `.` and `..` are rejected outright, and a leading `-` is
rejected so the id can never be mistaken for a flag.

### Close

```
prove-it-gate close
```

Archives the cycle to `history/<timestamp>/`. It **refuses** while any
Confirmed finding has no confirmed fix, and it **refuses** while any finding
has no Confirmed or Proven-safe verification at all (UNVERIFIED, or stuck at
Inconclusive), `close` is not a way to silently clear a gate the hook is
still actively blocking on. Both refusals point at the exact command to
resolve them, or at `override` (below) as the logged, archived bypass.

### Status and override

```
prove-it-gate status
prove-it-gate override --reason <text>
```

`status` prints every finding with its verdict, whether its fix has been
re-verified, and whether its digest is still current. It also previews
whether `close` would currently refuse, and why.

`override` is the escape hatch. If a gate is open, it **archives** the
bypassed `gate-state.json` / `gate-verdicts.json` to `history/<timestamp>/`
exactly like `close` does (so which findings and verdicts were bypassed can
be reconstructed later, not just that a bypass happened), prints a loud
banner, and appends a permanent timestamped entry to `override-log.txt` that
records the reason and the archive path. It is deliberately noisy and
deliberately durable. If no gate is open, `override` is a **no-op**: it says
so and does not touch `override-log.txt`, there is nothing to bypass, so
nothing is logged.

## Installation

The files here are the canonical source. The live copies belong at
`~/.claude/prove-it/`:

1. Copy `prove-it-gate` and `gate-check.sh` to `~/.claude/prove-it/`, keeping the
   executable bit on both.
2. Put `prove-it-gate` on `PATH` (a symlink from `~/.local/bin/prove-it-gate` works).
3. Register `gate-check.sh` as a `PreToolUse` hook in `~/.claude/settings.json`,
   matching `Edit|Write|MultiEdit|NotebookEdit`.

Runtime state (`gate-state.json`, `gate-verdicts.json`, `history/`,
`override-log.txt`) is created in `~/.claude/prove-it/` on first use and is
not part of this directory.

## Concurrency

**Fixed 2026-08-26** (previously an unfixed known limitation, discovered
2026-08-25 when two agents drove this gate simultaneously against the same
`~/.claude/prove-it/` state and corrupted it -- see `prove-it-gate`'s header
for the full provenance and design writeup). Every read-modify-write of
`gate-state.json` / `gate-verdicts.json` in `prove-it-gate` (`open`, `verify`,
`confirm-fix`, `close`, `override`) is now serialized by a single `flock` on
`GATE_DIR/gate.lock`. Read-only `status` takes a shared lock (excludes
writers, doesn't block concurrent readers); `repro-dir` takes no lock at all
(it only creates directories, never touches the JSON state).
`gate-check.sh` takes its own bounded-wait shared lock on the same lock file
before reading, so it never observes the pair of files mid one of
`prove-it-gate`'s multi-step writes.

Both tools use a *bounded* wait, not an indefinite one, and both degrade to
the pre-fix unlocked behavior if `flock` (util-linux; notably absent on stock
macOS) isn't on PATH, or the lock can't be acquired in time. `prove-it-gate`, as
an interactive/agent-driven CLI, warns to stderr on that degrade;
`gate-check.sh` degrades silently, which follows from its fail-open design
(see below): it is a `PreToolUse` hook, it emits nothing on the allow path,
and a lock must never become a new way for it to hang or to block an edit. A
rare unlocked race is a better failure mode than either tool refusing to run.

A regression repro for this lives at
`~/.claude/prove-it/repros/gatelock-2026-08-26/repro-gate-lock-race.sh`: it
fires N concurrent `prove-it-gate verify --inconclusive` calls against a scratch
gate state and fails if fewer than N verdicts survive.

## Known limitations

**The hook binds only the main session's tool calls.** It intercepts `Edit`,
`Write`, `MultiEdit`, and `NotebookEdit` in the session it is registered for. It
does **not** constrain a subagent's tool calls, and it does not see anything
done through `Bash`, a `sed -i` or a heredoc write sails straight past it. The
gate is a discipline aid for the main driver, not a sandbox.
