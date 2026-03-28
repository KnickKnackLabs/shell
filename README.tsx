/** @jsxImportSource jsx-md */

import { readFileSync, readdirSync } from "fs";
import { join, resolve } from "path";

import {
  Heading, Paragraph, CodeBlock, LineBreak, HR,
  Bold, Code, Link,
  Badge, Badges, Center, Section, Details,
  List, Item,
  Raw, HtmlLink, Sub,
} from "readme/src/components";

// ── Dynamic data ─────────────────────────────────────────────

const ROOT = resolve(import.meta.dirname);
const TASK_DIR = join(ROOT, ".mise/tasks");
const TEST_DIR = join(ROOT, "test");

// Count tasks (excluding hidden/meta)
const taskFiles = readdirSync(TASK_DIR).filter(
  (f) => !f.startsWith(".") && !f.startsWith("_") && f !== "test"
);
const taskCount = taskFiles.length;

// Count tests from .bats files
const testFiles = readdirSync(TEST_DIR).filter((f) => f.endsWith(".bats"));
const testSrc = testFiles
  .map((f) => readFileSync(join(TEST_DIR, f), "utf-8"))
  .join("\n");
const testCount = [...testSrc.matchAll(/@test "/g)].length;

// Extract zmx requirement from mise.toml
const miseToml = readFileSync(join(ROOT, "mise.toml"), "utf-8");
const batsVersion =
  miseToml.match(/bats\s*=\s*"([^"]+)"/)?.[1] ?? "latest";

// ── Visual hook ──────────────────────────────────────────────

const lifecycle = [
  "$ shell run scout shimmer agent --headless \"review PR #50\"",
  "scout",
  "",
  "$ shell status scout",
  "running",
  "",
  "$ shell history scout",
  "Reading src/handler.rs...",
  "Found 3 issues in error handling.",
  "Posted review to #scout-report.",
  "",
  "$ shell wait scout",
  "$",
].join("\n");

// ── Spawning stack ───────────────────────────────────────────

const stack = [
  "  sessions wake            orchestration — session lifecycle",
  "    └─ shell run           persistence — named zmx sessions",
  "         └─ shimmer agent  identity — system prompt, chat attribution",
  "              └─ pi        harness — processes the message, exits",
].join("\n");

// ── README ───────────────────────────────────────────────────

const readme = (
  <>
    <Center>
      <Heading level={1}>shell</Heading>

      <Paragraph>
        <Bold>
          Persistent named shells for AI agents.
        </Bold>
      </Paragraph>

      <Paragraph>
        {"Agents get ephemeral tool calls that die after each invocation."}
        {"\n"}
        {"Shell gives them named sessions that survive — launch a process,"}
        {"\n"}
        {"come back later, read its output, send it input."}
      </Paragraph>

      <Badges>
        <Badge label="lang" value="bash" color="4EAA25" logo="gnubash" logoColor="white" />
        <Badge label="tests" value={`${testCount} passing`} color="brightgreen" href="test/" />
        <Badge label="backend" value="zmx" color="blue" href="https://github.com/neurosnap/zmx" />
        <Badge label="license" value="MIT" color="blue" />
      </Badges>
    </Center>

    <CodeBlock>{lifecycle}</CodeBlock>

    <LineBreak />

    <Section title="Quick start">
      <CodeBlock lang="bash">{`# Install
shiv install shell

# Launch a background process
shell run my-task make build

# Check on it
shell status my-task          # running / exited (0)
shell history my-task         # scrollback output

# Wait for completion
shell wait my-task`}</CodeBlock>
    </Section>

    <Section title="How it works">
      <Paragraph>
        {"Shell wraps "}
        <Link href="https://github.com/neurosnap/zmx">zmx</Link>
        {" — a lightweight session manager that gives processes persistent PTYs. Each "}
        <Code>shell run</Code>
        {" creates a named zmx session, runs your command inside it, and returns immediately. The process keeps running in the background. You interact with it by name."}
      </Paragraph>

      <Paragraph>
        {"The wrapping layer adds what zmx doesn't provide: input validation, session name rules, idle/busy detection, working directory control, JSON output for scripting, and clear error messages when things go wrong."}
      </Paragraph>

      <Heading level={3}>Session reuse</Heading>

      <Paragraph>
        <Code>shell run</Code>
        {" on an existing session checks its state. If the previous command finished (idle), it sends a new command to the same shell. If a command is still running (busy), it errors and tells you to use "}
        <Code>shell send</Code>
        {" instead. This means you can treat a session like a workspace — run a task, wait, run the next one."}
      </Paragraph>

      <CodeBlock lang="bash">{`shell run dev make build
shell wait dev
shell run dev make test       # reuses the same session
shell wait dev
shell history dev             # full scrollback from both commands`}</CodeBlock>

      <Heading level={3}>Working directory</Heading>

      <Paragraph>
        {"zmx spawns shells in its own directory, ignoring the caller's cwd. The "}
        <Code>--cwd</Code>
        {" flag wraps the command with "}
        <Code>cd</Code>
        {" so the process starts where you need it. This matters for agent spawning — without it, tools that depend on the working directory (like loading a CLAUDE.md) won't find their files."}
      </Paragraph>

      <CodeBlock lang="bash">{`shell run agent-task --cwd ~/project shimmer agent --headless "run the tests"`}</CodeBlock>

      <Heading level={3}>Input injection</Heading>

      <Paragraph>
        <Code>shell send</Code>
        {" delivers raw text to a session's PTY. Whatever process owns the terminal receives it as stdin. Use this for interactive programs — typing into a running prompt, answering a confirmation, or sending commands to a REPL."}
      </Paragraph>

      <CodeBlock lang="bash">{`shell run repl python3
shell send repl "print('hello from the outside')"
shell history repl`}</CodeBlock>
    </Section>

    <Section title="Spawning agents">
      <Paragraph>
        {"Shell is one layer in a stack where agents launch other agents. Each layer has a single job:"}
      </Paragraph>

      <CodeBlock>{stack}</CodeBlock>

      <Paragraph>
        {"A typical spawn: "}
        <Code>sessions wake</Code>
        {" calls "}
        <Code>shell run</Code>
        {" with the right identity and session file. The agent runs headlessly in a zmx session, posts results to a chat channel, and exits. The caller monitors progress via "}
        <Code>shell status</Code>
        {" and "}
        <Code>shell history</Code>
        {", or reads the session transcript directly."}
      </Paragraph>

      <CodeBlock lang="bash">{`# Spawn a background agent to review a PR
shell run scout --cwd ~/project shimmer agent --headless "review PR #50, post to #reviews"

# Monitor from the outside
shell status scout              # running
shell history scout             # what it's doing right now
chat read reviews               # what it reported

# When it's done
shell wait scout
shell status scout              # exited (0)`}</CodeBlock>

      <Paragraph>
        {"Environment passes through — identity, API keys, PATH, tool configuration. The spawned agent inherits the caller's full environment, so "}
        <Code>shimmer as</Code>
        {" and "}
        <Code>den agent:env</Code>
        {" carry into the session automatically."}
      </Paragraph>
    </Section>

    <Section title="Development">
      <CodeBlock lang="bash">{`git clone https://github.com/KnickKnackLabs/shell.git
cd shell && mise trust && mise install
mise run test`}</CodeBlock>

      <Paragraph>
        <Bold>{`${testCount} tests`}</Bold>
        {` across ${testFiles.length} suites, using `}
        <Link href="https://github.com/bats-core/bats-core">{`BATS ${batsVersion}`}</Link>
        {". Tests create real zmx sessions and clean them up — each test gets an isolated socket directory so nothing bleeds between runs."}
      </Paragraph>

      <Paragraph>
        {"Requires "}
        <Link href="https://github.com/neurosnap/zmx">zmx</Link>
        {" to be installed separately. See "}
        <Link href="https://zmx.sh">zmx.sh</Link>
        {" for installation."}
      </Paragraph>
    </Section>

    <LineBreak />

    <Center>
      <HR />

      <Sub>
        {"Named sessions. Background processes. Persistent by default."}
        <Raw>{"<br />"}</Raw>{"\n"}
        <Raw>{"<br />"}</Raw>{"\n"}
        {"This README was generated from "}
        <HtmlLink href="https://github.com/KnickKnackLabs/readme">README.tsx</HtmlLink>
        {"."}
      </Sub>
    </Center>
  </>
);

console.log(readme);
