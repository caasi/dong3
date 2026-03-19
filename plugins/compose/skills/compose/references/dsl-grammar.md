# Arrow DSL Grammar Reference

## EBNF

```ebnf
pipeline = seq_expr ;

seq_expr = alt_expr , ">>>" , seq_expr              (* sequential — infixr 1 *)
         | alt_expr ;
alt_expr = par_expr , "|||" , alt_expr              (* branch — infixr 2 *)
         | par_expr ;
par_expr = term , ( "***" | "&&&" ) , par_expr      (* parallel / fanout — infixr 3 *)
         | term ;

term     = node
         | "loop" , "(" , seq_expr , ")"            (* feedback loop *)
         | "(" , seq_expr , ")"                    (* grouping *)
         ;

node     = ident , [ "(" , [ args ] , ")" ] ;

args     = arg , { "," , arg } ;

arg      = ident , ":" , value ;

value    = string
         | number
         | ident
         | "[" , [ value , { "," , value } ] , "]"
         ;

ident    = ( letter | "_" ) , { letter | digit | "-" | "_" } ;

string   = '"' , { any char - '"' } , '"' ;

number   = [ "-" ] , digit , { digit } , [ "." , digit , { digit } ] , { letter } ;

comment  = "--" , { any char - newline } ;
```

All operators are right-associative (matching Haskell Arrow fixity). Comments can appear after any term and are attached to the preceding node as purpose descriptions or reference tool annotations.

## Combinators

| Combinator | Syntax | Precedence | Type | Expands To |
|------------|--------|------------|------|------------|
| Sequential | `>>>` | infixr 1 | `Arrow a b → Arrow b c → Arrow a c` | Sequential tool calls |
| Branch | `\|\|\|` | infixr 2 | `Arrow a c → Arrow b c → Arrow (Either a b) c` | Fallback logic |
| Parallel | `***` | infixr 3 | `Arrow a b → Arrow c d → Arrow (a,c) (b,d)` | Multiple tool calls in one message |
| Fanout | `&&&` | infixr 3 | `Arrow a b → Arrow a c → Arrow a (b,c)` | Multiple tool calls, same input |
| Loop | `loop(expr)` | — | `Arrow (a,s) (b,s) → Arrow a b` | Retry / iterative refinement |
| Group | `(expr)` | — | Precedence grouping | No direct expansion |

`***` is right-associative: `a *** b *** c` types as `(A, (B, C))`.

`***` and `&&&` share the same precedence. When mixed without grouping, the rightmost operator binds first:

```
a *** b &&& c        -- parses as: a *** (b &&& c)
a &&& b *** c        -- parses as: a &&& (b *** c)
```

Use explicit parentheses when mixing them to make intent clear:

```
(a *** b) &&& c      -- parallel a,b then fanout with c
a *** (b &&& c)      -- fanout b,c then parallel with a
```

## Node Design

Nodes describe **purpose**, not specific tools. Each node may include:

- **Name** — what this step accomplishes (required)
- **Arguments** — key-value parameters (optional)
- **Comment** — purpose description or reference tool annotation (optional, via `--`)

The agent expanding the pipeline decides which concrete tool to use based on the node's purpose and available tools. Reference tools in comments are hints, not constraints.

## Examples

### Sequential Pipeline

```
read(source: "data.csv")          -- read the data source
  >>> parse(format: csv)          -- structure raw data
  >>> filter(condition: "age > 18")
  >>> format(as: report)
```

### Parallel Composition

```
read(source: "data.csv")
  >>> parse(format: csv)
  >>> (count *** collect(fields: [email]))  -- parallel: count & collect
  >>> format(as: report)
```

### Fanout

```
(lint &&& test)
  >>> gate(require: [pass, pass])
  >>> (build_linux(profile: static) *** build_macos(profile: release))
  >>> upload(tag: "v0.1.0")
```

`&&&` feeds the same input to both sides. `***` feeds separate inputs to each side.

### Branch / Fallback

```
(fetch(url: endpoint)             -- try remote first
  ||| load(from: cache, key: k))  -- fall back to cache
  >>> transform(mapping: schema_v2)
  >>> write(dest: "output.json")
```

### Feedback Loop

```
loop(
  generate(artifact: code, from: spec)  -- produce code from spec
    >>> verify(method: test_suite)       -- run tests
    >>> evaluate(criteria: all_pass)     -- check pass/fail
)
```

### Numeric Literals

Numbers can be integers, floats, negative, or carry unit suffixes:

```
resize(width: 1920, height: 1080)     -- integers
  >>> compress(quality: 85)
  >>> dose(amount: 100mg)             -- unit suffix
  >>> adjust(offset: -3.14)           -- negative float
```

Numbers appear wherever a value is expected — as arguments or inside lists:

```
mix(volumes: [100ml, 250ml, 50ml])
  >>> heat(temp: 72.5c, duration: 30min)
```

Note: leading-dot (`.5`) and trailing-dot (`5.`) forms are **not** valid — use `0.5` and `5` respectively.

### Cross-Agent Portability

The same node can be expanded differently by different agents:

```
read(source: "data.csv")

  Claude Code  →  Read tool
  shell agent  →  cat data.csv
  browser agent → fetch("/api/data.csv")
```

## Structural Rules

The checker validates **syntax structure** only:

- Balanced parentheses
- Valid operator usage and precedence
- Well-formed node definitions

The checker does NOT validate:

- Semantic compatibility between nodes
- Whether `***` branches eventually merge (data flow analysis)
- Whether `|||` branches both produce output
- Whether `loop` contains a termination condition
- Whether reference tools exist
- Tool parameter formats
- Anything requiring execution
