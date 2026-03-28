# compose

A Claude Code skill for describing multi-step agent workflows using an Arrow-style DSL and validating them structurally with the `ocaml-compose-dsl` binary.

## What it does

- Teaches AI agents to plan workflows as Arrow-style pipelines before executing them
- Validates pipeline structure with a pre-built binary checker (parse errors, unbalanced branches) and emits warnings (`?` without `|||`)
- Saves successful pipelines as `.arr` files for reuse across conversations
- Provides common patterns: sequential, parallel, branch/fallback, and feedback loops
- Supports abstraction with lambda (`\x -> expr`) and let bindings (`let x = expr in body`) for naming and reusing workflow fragments
- Validates arrow blocks embedded in Markdown files via literate mode (`--literate`)
- Supports multiple independent pipelines in one file via semicolon `;` separator

## Arrow Combinators

| Syntax | Meaning | Precedence |
|--------|---------|------------|
| `>>>` | Sequential — run left then right | infixr 1 |
| `\|\|\|` | Branch — try left, fallback to right | infixr 2 |
| `***` | Parallel — run both concurrently | infixr 3 |
| `&&&` | Fanout — run both on same input | infixr 3 |
| `loop()` | Feedback — repeat body iteratively | — |
| `?` | Question — marks step as producing Either | — |
| `(expr)` | Grouping | — |
| `\x -> expr` | Lambda — parameterized fragment | — |
| `let x = expr in body` | Let binding — named fragment | — |
| `()` | Unit — no-input value | — |
| `;` | Statement separator | — |

## Examples

```
read(source: "data.csv")
  >>> parse(format: csv)
  >>> filter(condition: "age > 18")
  >>> (count *** collect(fields: [email]))
  >>> format(as: report)
```

```
(lint &&& test)
  >>> gate(require: [pass, pass])
  >>> (build_linux(profile: static) *** build_macos(profile: release))
  >>> upload(tag: "v0.1.0")
```

```
読み込み(ソース: "データ.csv")
  >>> フィルタ(条件: "年齢 > 18")
  >>> 出力
```

```arrow
let review = \trigger, fix ->
  loop(trigger >>> (pass ||| fix))
in
let phase1 = gather >>> review(check?, rework) in
let phase2 = build >>> review(test?, fix) in
phase1 >>> phase2
```

21 examples in `examples/` — including a meta-workflow that describes how this skill updates itself from the upstream repo.

## Install

```bash
claude plugin marketplace add caasi/dong3
claude plugin install compose@caasi-dong3
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
