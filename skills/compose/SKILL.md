---
name: compose
description: This skill should be used when the user asks to "describe a workflow", "compose a pipeline", "write a pipeline in DSL", "plan tool composition", "validate a pipeline", "check DSL syntax", mentions Arrow DSL or `.arr` files, or wants to structure multi-step agent workflows before execution. Also triggers when the user asks to install `ocaml-compose-dsl`.
---

# Compose — Arrow DSL for Agent Workflow Composition

Describe multi-step workflows using an Arrow-style DSL, then validate them structurally with the `ocaml-compose-dsl` binary. The DSL is a **planning language, not an execution engine** — the agent itself expands the DSL into concrete tool calls.

## Prerequisites

The `ocaml-compose-dsl` binary must be installed at `~/.local/bin/ocaml-compose-dsl`. If not found, inform the user and offer to run the install script bundled with this skill at `scripts/install.sh`. The script downloads the correct pre-built binary from [caasi/ocaml-compose-dsl releases](https://github.com/caasi/ocaml-compose-dsl/releases) for the current platform (Linux x86_64, macOS x86_64, macOS arm64) and places it in `~/.local/bin/`.

Ensure `~/.local/bin` is in `PATH`.

## Core Concepts

### Arrow Combinators

| Syntax | Meaning | Tool Call Expansion |
|--------|---------|---------------------|
| `>>>` | Sequential — run left then right | Sequential tool calls |
| `***` | Parallel — run both concurrently | Multiple tool calls in one message |
| `\|\|\|` | Branch — try left, fallback to right | Conditional fallback |
| `loop()` | Feedback — repeat until evaluation passes | Retry / iterative refinement |
| `()` | Grouping | Precedence control |

### Node Design

Nodes describe **purpose**, not specific tools:

```
read(source: "data.csv")  -- ref: Read, cat, fetch
```

- The node name and arguments express intent
- Comments (`--`) annotate purpose or suggest reference tools
- The expanding agent chooses which concrete tool to use

For detailed grammar (EBNF), combinators, and examples, consult **`references/dsl-grammar.md`**.

## Workflow

### 1. Plan the Pipeline

When given a multi-step task, draft the workflow as DSL before executing:

```
read(source: "config.yaml")
  >>> validate(schema: app_config)
  >>> (extract(section: database) *** extract(section: logging))
  >>> apply(target: environment)
```

### 2. Validate Structure

Write the DSL to a `.arr` file and validate with the checker:

```bash
echo 'read(source: "config.yaml") >>> validate(schema: app_config)' | ocaml-compose-dsl
```

Or from a file:

```bash
ocaml-compose-dsl pipeline.arr
```

The binary exits `0` with `OK` on valid input, `1` with error messages on structural problems. Fix any structural errors before proceeding.

### 3. Expand and Execute

After validation, expand each node into concrete tool calls based on available tools. The DSL is the plan; execution follows the plan's structure:

- `>>>` nodes → execute sequentially
- `***` nodes → execute as parallel tool calls in one message
- `|||` nodes → try first branch, use second on failure
- `loop()` → repeat the body until the evaluation node passes

### 4. Save Successful Pipelines

Store validated, successfully-executed pipelines as `.arr` files for reuse. Include comments describing the use case:

```
-- Deploy config update: validate then apply to staging
read(source: "config.yaml")       -- ref: Read
  >>> validate(schema: app_config) -- ref: Bash("yq")
  >>> apply(target: staging)       -- ref: Bash("kubectl apply")
```

When a similar task arises, load and modify the existing pipeline instead of reasoning from scratch.

## Common Patterns

### Data Processing

```
read(source: input) >>> parse(format: fmt) >>> transform(mapping: m) >>> write(dest: output)
```

### Resilient Fetch

```
(fetch(url: primary) ||| fetch(url: mirror)) >>> process
```

### Test-Fix Loop

```
loop(
  edit(target: code, change: fix)
    >>> test(suite: relevant)
    >>> evaluate(criteria: all_pass)
)
```

### Parallel Analysis

```
read(source: file)
  >>> (lint *** typecheck *** test(suite: unit))
  >>> report(format: summary)
```

## Additional Resources

### Reference Files

- **`references/dsl-grammar.md`** — Full EBNF grammar, combinator table, node design principles, structural rules, and extended examples

### Scripts

- **`scripts/install.sh`** — Platform-aware installer for `ocaml-compose-dsl` binary. Downloads from GitHub Releases to `~/.local/bin/`

### External

- [caasi/ocaml-compose-dsl](https://github.com/caasi/ocaml-compose-dsl) — Source repository with parser, checker, and CI/CD
- [Plan 000: Arrow DSL Design](https://github.com/caasi/ocaml-compose-dsl/blob/main/docs/superpowers/plans/000-dsl.md) — Original design document
