# prove-it

A standalone Claude Code plugin: a code review harness where a finding is not real until a script reproduces it.

The plugin itself lives under [`plugins/prove-it/`](plugins/prove-it/README.md), including its own README with the full pitch, how it works, and install instructions. This repo is also a single-plugin marketplace, so it can be added directly:

```
/plugin marketplace add ironmoose/prove-it
/plugin install prove-it@prove-it
```

## Status

v0.1.0, early. Skeleton in place; agents and commands land in a later phase.
