# shell

Persistent named shells for agent use. Wraps [zmx](https://github.com/neurosnap/zmx) with proper argument handling, validation, and a stable CLI surface.

## Install

```bash
shiv install shell
```

Requires [zmx](https://zmx.sh) to be installed separately.

## Commands

```bash
shell run <name> <command...>       # launch in background, return immediately
shell attach <name>                 # connect terminal to a running shell
shell list [--json]                 # show active shells
shell kill <name>                   # stop a shell
shell history <name> [--plain]      # scrollback output
shell wait <name> [--timeout <s>]   # block until command finishes
shell status <name>                 # is it running? exit code?
```

## Why not use zmx directly?

zmx is powerful but has sharp edges:

- No flag parsing — `zmx run --help` creates a session named `--help`
- No input validation or helpful error messages
- No JSON output for scripting
- Tight coupling — consumers shouldn't depend on a specific backend

`shell` wraps zmx with a clean interface. Consumers like `sessions wake` call `shell run` and don't care about the backend.

## Testing

```bash
mise run test
```

Requires zmx to be installed. Tests create real (lightweight) zmx sessions and clean them up.
