<div align="center">

<pre>
  $ shell run scout shimmer agent --headless "review PR #50"
  scout

  $ shell status scout
  running

  $ shell history scout
  Reading src/handler.rs...
  Found 3 issues in error handling.
  Posted review to #scout-report.

  $ shell wait scout
  $
</pre>

# shell

**Persistent named shells for AI agents.**

Agents get ephemeral tool calls that die after each invocation.
Shell gives them named sessions that survive — launch a process,
come back later, read its output, send it input.

![lang: bash](https://img.shields.io/badge/lang-bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![tests: 34 passing](https://img.shields.io/badge/tests-34%20passing-brightgreen?style=flat)](test/)
[![backend: zmx](https://img.shields.io/badge/backend-zmx-blue?style=flat)](https://github.com/neurosnap/zmx)
![license: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat)

</div>

<br />

## Quick start

```bash
# Install
shiv install shell

# Launch a background process
shell run my-task make build

# Check on it
shell status my-task          # running / exited (0)
shell history my-task         # scrollback output

# Wait for completion
shell wait my-task
```

## How it works

Shell wraps [zmx](https://github.com/neurosnap/zmx) — a lightweight session manager that gives processes persistent PTYs. Each `shell run` creates a named zmx session, runs your command inside it, and returns immediately. The process keeps running in the background. You interact with it by name.

The wrapping layer adds what zmx doesn't provide: input validation, session name rules, idle/busy detection, working directory control, JSON output for scripting, and clear error messages when things go wrong.

### Session reuse

`shell run` on an existing session checks its state. If the previous command finished (idle), it sends a new command to the same shell. If a command is still running (busy), it errors and tells you to use `shell send` instead. This means you can treat a session like a workspace — run a task, wait, run the next one.

```bash
shell run dev make build
shell wait dev
shell run dev make test       # reuses the same session
shell wait dev
shell history dev             # full scrollback from both commands
```

### Working directory

zmx spawns shells in its own directory, ignoring the caller's cwd. The `--cwd` flag wraps the command with `cd` so the process starts where you need it. This matters for agent spawning — without it, tools that depend on the working directory (like loading a CLAUDE.md) won't find their files.

```bash
shell run agent-task --cwd ~/project shimmer agent --headless "run the tests"
```

### Input injection

`shell send` delivers raw text to a session's PTY. Whatever process owns the terminal receives it as stdin. Use this for interactive programs — typing into a running prompt, answering a confirmation, or sending commands to a REPL.

```bash
shell run repl python3
shell send repl "print('hello from the outside')"
shell history repl
```

## Spawning agents

Shell is one layer in a stack where agents launch other agents. Each layer has a single job:

```
  sessions wake            orchestration — session lifecycle
    └─ shell run           persistence — named zmx sessions
         └─ shimmer agent  identity — system prompt, chat attribution
              └─ pi        harness — processes the message, exits
```

A typical spawn: `sessions wake` calls `shell run` with the right identity and session file. The agent runs headlessly in a zmx session, posts results to a chat channel, and exits. The caller monitors progress via `shell status` and `shell history`, or reads the session transcript directly.

```bash
# Spawn a background agent to review a PR
shell run scout --cwd ~/project shimmer agent --headless "review PR #50, post to #reviews"

# Monitor from the outside
shell status scout              # running
shell history scout             # what it's doing right now
chat read reviews               # what it reported

# When it's done
shell wait scout
shell status scout              # exited (0)
```

Environment passes through — identity, API keys, PATH, tool configuration. The spawned agent inherits the caller's full environment, so `shimmer as` and `den agent:env` carry into the session automatically.

## Development

```bash
git clone https://github.com/KnickKnackLabs/shell.git
cd shell && mise trust && mise install
mise run test
```

**34 tests** across 8 suites, using [BATS 1.13.0](https://github.com/bats-core/bats-core). Tests create real zmx sessions and clean them up — each test gets an isolated socket directory so nothing bleeds between runs.

Requires [zmx](https://github.com/neurosnap/zmx) to be installed separately. See [zmx.sh](https://zmx.sh) for installation.

<br />

<div align="center">

---

<sub>
Named sessions. Background processes. Persistent by default.<br />
<br />
This README was generated from <a href="https://github.com/KnickKnackLabs/readme">README.tsx</a>.
</sub></div>
