# Arrow DSL Grammar Reference

## EBNF

```ebnf
program     = { ";" } , [ stmt , { ";" , { ";" } , stmt } , { ";" } ] ;

stmt        = let_expr | pipeline ;

let_expr    = "let" , ident , "=" , seq_expr , "in" , stmt ;

lambda  = "\" , ident , { "," , ident } , "->" , seq_expr ;
                                                    (* body is seq_expr, not stmt;
                                                       let_expr is only valid at stmt level
                                                       or inside grouping parens *)

pipeline = seq_expr ;

seq_expr = alt_expr , ">>>" , seq_expr              (* sequential — infixr 1 *)
         | lambda
         | alt_expr ;
alt_expr = par_expr , "|||" , alt_expr              (* branch — infixr 2 *)
         | par_expr ;
par_expr    = typed_term , ( "***" | "&&&" ) , par_expr (* parallel / fanout — infixr 3 *)
            | typed_term ;

typed_term  = term , [ "::" , type_expr ] ;

type_expr   = type_name , "->" , type_name ;
type_name   = ident | "(" , ")" ;

term     = ident , [ "(" , [ call_args ] , ")" ] , [ "?" ]
                                                    (* ident with optional args and question *)
         | string , [ "?" ]                        (* string literal, optionally followed by "?";
                                                      only the postfix-"?" form (expr?) becomes
                                                      Question(expr) in the AST *)
         | "(" , ")" , [ "?" ]                     (* unit value, with optional question *)
         | "loop" , "(" , seq_expr , ")"            (* feedback loop *)
         | "(" , stmt , ")"                        (* grouping — allows let bindings
                                                      but not semicolons inside parens *)
         ;

call_args = call_arg , { "," , call_arg } ;
                                                    (* empty call_args in f() produces
                                                       [Positional Unit], not an empty list;
                                                       zero-arg application is eliminated *)
call_arg  = arg_key , ":" , value                   (* Named — per-arg disambiguation via key ":" *)
          | seq_expr                                (* Positional — any expression *)
          ;
arg_key   = ident | "in" ;                          (* reserved word "in" allowed as named arg key *)

value    = string
         | number
         | ident
         | "[" , [ value , { "," , value } ] , "]"
         ;

ident       = ident_start , { ident_char } - reserved ;
                (* reserved words are excluded at the lexer level *)
reserved    = "let" | "loop" | "in" ;
ident_start = ? any valid UTF-8 codepoint that is not an ASCII digit,
                not ASCII whitespace, and not one of ( ) [ ] : , > * | & - " .
                ! # $ % ^ + = { } < ; ' ` ~ / QUESTION_MARK @ \ ? ;
ident_char  = ? any valid UTF-8 codepoint that is not ASCII whitespace,
                and not one of ( ) [ ] : , > * | & " .
                ! # $ % ^ + = { } < ; ' ` ~ / QUESTION_MARK @ \ ? ;
                (* note: "-" is a valid ident_char, but the lexer stops
                   before "->" so that the arrow token is recognized
                   even without surrounding whitespace *)

string   = '"' , { ? any valid UTF-8 codepoint except '"' ? } , '"' ;

digit    = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
number   = [ "-" ] , digit , { digit } , [ "." , digit , { digit } ] , [ ident_start , { ident_char } ] ;

comment  = "--" , { any char - newline } ;
```

All operators are right-associative (matching Haskell Arrow fixity). Comments can appear after any term and are attached to the preceding node as purpose descriptions or reference tool annotations.

Identifiers and unit suffixes support full UTF-8 codepoints, including non-ASCII characters (CJK, Greek, accented Latin, etc.), so the DSL works naturally with non-Latin scripts. Error positions report codepoint-level columns, not byte offsets.

`typed_term` sits at the `par_expr` level, but since `seq_expr` and `alt_expr` both bottom out through `par_expr → typed_term → term`, every term position in the grammar can carry a `:: TypeName -> TypeName` annotation. Type names can be identifiers or `()` (unit). Annotations are documentation-only; the checker does not validate types.

`program` is the top-level production. A program contains zero or more statements (`stmt`) separated by semicolons. Each statement is either a `let_expr` or a `pipeline`. Semicolons between statements are required; leading and trailing semicolons are optional.

`reserved` words (`let`, `loop`, `in`) are excluded from `ident` at the lexer level — they cannot be used as node names. `in` is allowed as a named argument key via the `arg_key` production.

`call_arg` supports both named (`key: value`) and positional (`seq_expr`) arguments in the same call. `f()` produces a single positional Unit argument — it is not an empty argument list.

## Combinators

| Combinator | Syntax | Precedence | Type | Expands To |
|------------|--------|------------|------|------------|
| Sequential | `>>>` | infixr 1 | `Arrow a b → Arrow b c → Arrow a c` | Sequential tool calls |
| Branch | `\|\|\|` | infixr 2 | `Arrow a c → Arrow b c → Arrow (Either a b) c` | Fallback logic |
| Parallel | `***` | infixr 3 | `Arrow a b → Arrow c d → Arrow (a,c) (b,d)` | Multiple tool calls in one message |
| Fanout | `&&&` | infixr 3 | `Arrow a b → Arrow a c → Arrow a (b,c)` | Multiple tool calls, same input |
| Loop | `loop(expr)` | — | `Arrow (a,s) (b,s) → Arrow a b` | Retry / iterative refinement |
| Question | `node?` / `"string"?` | — | `Arrow a (Either a a)` | Marks step as producing Either for `\|\|\|` |
| Group | `(expr)` | — | Precedence grouping | No direct expansion |
| Type Ann | `term :: A -> B` | — | Documentation annotation | No direct expansion |
| Lambda | `\x -> expr` | — | `Arrow a b` | Parameterized workflow fragment |
| Let | `let x = expr in body` | — | Named binding | Abstraction (not a combinator) |
| Unit | `()` | — | Unit value / type | No-input value or trigger |
| Semicolon | `;` | — | Statement separator | Multiple independent pipelines |

`***` is right-associative: `a *** b *** c` types as `(A, (B, C))`.

`***` and `&&&` share the same precedence. When mixed without grouping, the rightmost operator binds first:

```arrow
a *** b &&& c;        -- parses as: a *** (b &&& c)
a &&& b *** c         -- parses as: a &&& (b *** c)
```

Use explicit parentheses when mixing them to make intent clear:

```arrow
(a *** b) &&& c;      -- parallel a,b then fanout with c
a *** (b &&& c)       -- fanout b,c then parallel with a
```

## Node Design

Nodes describe **purpose**, not specific tools. Each node may include:

- **Name** — what this step accomplishes (required)
- **Arguments** — key-value parameters (optional)
- **Comment** — purpose description or reference tool annotation (optional, via `--`)

The agent expanding the pipeline decides which concrete tool to use based on the node's purpose and available tools. Reference tools in comments are hints, not constraints.

## Examples

### Sequential Pipeline

```arrow
read(source: "data.csv")          -- read the data source
  >>> parse(format: csv)          -- structure raw data
  >>> filter(condition: "age > 18")
  >>> format(as: report)
```

### Parallel Composition

```arrow
read(source: "data.csv")
  >>> parse(format: csv)
  >>> (count *** collect(fields: [email]))  -- parallel: count & collect
  >>> format(as: report)
```

### Fanout

```arrow
(lint &&& test)
  >>> gate(require: [pass, pass])
  >>> (build_linux(profile: static) *** build_macos(profile: release))
  >>> upload(tag: "v0.1.0")
```

`&&&` feeds the same input to both sides. `***` feeds separate inputs to each side.

### Branch / Fallback

```arrow
(fetch(url: endpoint)             -- try remote first
  ||| load(from: cache, key: k))  -- fall back to cache
  >>> transform(mapping: schema_v2)
  >>> write(dest: "output.json")
```

### Feedback Loop

```arrow
loop(
  generate(artifact: code, from: spec)  -- produce code from spec
    >>> verify(method: test_suite)       -- run tests
    >>> "all tests pass"?               -- check pass/fail
    >>> (done ||| fix_and_retry)         -- branch on result
)
```

### Question Operator

`?` marks a step as producing Either, feeding into `|||` for branching:

```arrow
fetch(url: primary)?
  >>> (process ||| (fetch(url: mirror) >>> process))
```

`?` can also appear upstream in a `>>>` chain that feeds into `|||`:

```arrow
loop(
  generate >>> verify >>> "all tests pass"?
  >>> (done ||| fix_and_retry)
)
```

Only the "try" side (left operand of `|||`, or the upstream step producing Either) gets `?`. The fallback side does not.

The checker emits a warning (to stderr, exit code unaffected) if `?` appears without a matching `|||` in scope.

### Type Annotations

Nodes and terms can carry optional type annotations using `::`:

```arrow
fetch(url: "https://example.com") :: URL -> HTML
  >>> parse :: HTML -> Data
  >>> format(as: report) :: Data -> Report
```

Annotations document intended data flow for humans and agents. The checker parses them into the AST but performs **no type checking** — they are purely documentation.

Type names can be identifiers or `()` (unit): `:: () -> Server`, `:: Input -> ()`.

Type annotations bind at the `par_expr` level (tighter than all infix operators):

```arrow
-- annotation attaches to the preceding term, not the whole chain
read :: File -> CSV >>> parse :: CSV -> Data;

-- annotate grouped expressions
(read >>> parse) :: File -> Data
```

### Numeric Literals

Numbers can be integers, floats, negative, or carry unit suffixes:

```arrow
resize(width: 1920, height: 1080)     -- integers
  >>> compress(quality: 85)
  >>> dose(amount: 100mg)             -- unit suffix
  >>> adjust(offset: -3.14)           -- negative float
```

Numbers appear wherever a value is expected — as arguments or inside lists:

```arrow
mix(volumes: [100ml, 250ml, 50ml])
  >>> heat(temp: 72.5c, duration: 30min)
```

Note: leading-dot (`.5`) and trailing-dot (`5.`) forms are **not** valid — use `0.5` and `5.0` respectively.

### Unicode Identifiers

Node names, argument keys, and unit suffixes can use non-Latin scripts:

```arrow
読み込み(ソース: "データ.csv")
  >>> フィルタ(条件: "年齢 > 18")
  >>> 出力
```

```arrow
加熱(溫度: 72.5℃, 時間: 30分鐘)
  >>> 冷卻(目標: 4℃)
```

```arrow
dose(amount: 500ミリ秒)            -- unicode unit suffix
  >>> measure(area: 100m2)         -- digit within unit suffix
```

### Cross-Agent Portability

The same node can be expanded differently by different agents:

```
read(source: "data.csv")

  Claude Code  →  Read tool
  shell agent  →  cat data.csv
  browser agent → fetch("/api/data.csv")
```

### Lambda Expressions

Lambda creates parameterized workflow fragments:

```arrow
\name -> hello(to: name) >>> respond
```

Multi-parameter lambda:

```arrow
\trigger, fix -> loop(trigger >>> (pass ||| fix))
```

Lambda with type annotations:

```arrow
\url -> fetch(url: url) :: URL -> HTML
  >>> parse :: HTML -> Data
```

Bare lambdas are syntactically valid statements, but in practice they are most useful when bound via `let` and applied. See [Let Bindings](#let-bindings) for complete usage.

### Let Bindings

`let` names a workflow fragment for reuse:

```arrow
let greet = \name -> hello(to: name) >>> respond in
greet(alice) >>> greet(bob)
```

Nested lets — multi-phase workflow:

```arrow
let review = \trigger, fix ->
  loop(trigger >>> (pass ||| fix))
in
let phase1 = gather >>> review(check?, rework) in
let phase2 = build >>> review(test?, fix) in
phase1 >>> phase2
```

Let inside parentheses:

```arrow
(let x = fetch(url: primary) in x)
  ||| fetch(url: mirror)
```

### Unit

`()` is a value representing "no input" or "trigger":

```arrow
() >>> start_server :: () -> Server
```

`()` is also valid as a type name in annotations:

```arrow
healthcheck :: () -> Status
```

`f()` passes Unit as a positional argument — it is not an empty argument list:

```arrow
noop() >>> continue
```

### Multi-Statement

A program can contain multiple independent pipelines separated by `;`:

```arrow
planning :: Doc -> Commit
  >>> commit(branch: main);

implementation :: Code -> Commit
  >>> branch(pattern: "feature/*") :: Code -> Branch
  >>> commit :: Branch -> Commit
```

Trailing semicolon is optional on the last statement.

### Literate Arrow Documents

Arrow DSL is designed to work inside Markdown documents. Use fenced code blocks with the `arrow` (or `arr`) language tag to embed workflow definitions alongside prose. Any Markdown file can be a literate Arrow document. Both LF and CRLF line endings are supported.

````markdown
## Deployment

Build artifacts must pass CI before release.

```arrow
build :: Source -> Artifact
  >>> test :: Artifact -> Verified
  >>> deploy(env: production) :: Verified -> Released
```
````

Convention: `.arr` for standalone DSL files. For literate documents, use regular `.md` — the `arrow` code blocks speak for themselves.

Validate with `ocaml-compose-dsl --literate doc.md`.

### Mixed Call Arguments

Named and positional arguments can be freely mixed in the same call:

```arrow
let v = some_pipeline in
push(remote: origin, v)
```

Named arguments (`key: value`) provide static configuration; positional arguments pass pipeline expressions.

## Structural Rules

The checker validates **syntax structure** only, and emits warnings:

- Balanced parentheses
- Valid operator usage and precedence
- Well-formed node definitions
- Semicolons separate top-level statements only — they are not valid inside parentheses

The checker does NOT validate:

- Semantic compatibility between nodes
- Whether `***` branches eventually merge (data flow analysis)
- Whether `|||` branches both produce output
- Whether `loop` contains a termination condition
- Whether reference tools exist
- Tool parameter formats
- Anything requiring execution

### Warnings

The checker also emits **warnings** (to stderr, without affecting exit code):

- `?` without matching `|||` in scope — the Either has no consumer
- `?` as operand of `|||` — `?` already implies `|||` with an implicit empty branch; using both is redundant
