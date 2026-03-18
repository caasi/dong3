# compose

A Claude Code skill for describing multi-step agent workflows using an Arrow-style DSL and validating them structurally with the `ocaml-compose-dsl` binary.

## What it does

- Teaches AI agents to plan workflows as Arrow-style pipelines before executing them
- Validates pipeline structure with a pre-built binary checker (parse errors, unbalanced branches, missing evaluation nodes)
- Saves successful pipelines as `.arr` files for reuse across conversations
- Provides common patterns: sequential, parallel, branch/fallback, and feedback loops

## Arrow Combinators

| Syntax | Meaning |
|--------|---------|
| `>>>` | Sequential — run left then right |
| `***` | Parallel — run both concurrently |
| `\|\|\|` | Branch — try left, fallback to right |
| `loop()` | Feedback — repeat until evaluation passes |

## Example

```
read(source: "data.csv")
  >>> parse(format: csv)
  >>> filter(condition: "age > 18")
  >>> (count *** collect(fields: [email]))
  >>> format(as: report)
```

## Install

```bash
claude plugin marketplace add caasi/dong3
claude plugin install dong3@caasi-dong3
```

The skill includes an install script that downloads the `ocaml-compose-dsl` binary to `~/.local/bin/`. On first use, Claude will offer to run it for you.

### Supported platforms

- Linux x86_64
- macOS x86_64
- macOS arm64

## How it works

1. **Plan** — Draft the workflow as DSL
2. **Validate** — Run `ocaml-compose-dsl` to check structure
3. **Expand** — Agent expands each node into concrete tool calls
4. **Save** — Store validated pipelines as `.arr` files for reuse

The DSL is a planning language, not an execution engine. The agent itself is the interpreter.

## Related

- [caasi/ocaml-compose-dsl](https://github.com/caasi/ocaml-compose-dsl) — Source repository for the parser and checker

## License

MIT
