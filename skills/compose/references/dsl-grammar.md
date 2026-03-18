# Arrow DSL Grammar Reference

## EBNF

```ebnf
pipeline = expr ;

expr     = term , { operator , term } ;

operator = ">>>"                        (* sequential composition *)
         | "***"                        (* parallel composition *)
         | "|||"                        (* branch / fallback *)
         ;

term     = node
         | "loop" , "(" , expr , ")"    (* feedback loop *)
         | "(" , expr , ")"            (* grouping *)
         ;

node     = ident , [ "(" , [ args ] , ")" ] ;

args     = arg , { "," , arg } ;

arg      = ident , ":" , value ;

value    = string
         | ident
         | "[" , [ value , { "," , value } ] , "]"
         ;

ident    = ( letter | "_" ) , { letter | digit | "-" | "_" } ;

string   = '"' , { any char - '"' } , '"' ;

comment  = "--" , { any char - newline } ;
```

Comments can appear after any term and are attached to the preceding node as purpose descriptions or reference tool annotations.

## Combinators

| Combinator | Syntax | Semantics | Expands To |
|------------|--------|-----------|------------|
| Sequential | `>>>` | Run left, then right | Sequential tool calls |
| Parallel | `***` | Run both sides concurrently | Multiple tool calls in one message |
| Branch | `\|\|\|` | Try left; if it fails, run right | Fallback logic |
| Loop | `loop(expr)` | Repeat until evaluation passes | Retry / iterative refinement |
| Group | `(expr)` | Precedence grouping | No direct expansion |

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

### Cross-Agent Portability

The same node can be expanded differently by different agents:

```
read(source: "data.csv")

  Claude Code  →  Read tool
  shell agent  →  cat data.csv
  browser agent → fetch("/api/data.csv")
```

## Structural Rules

The checker validates:

- Balanced parentheses
- `***` branches eventually merge
- `|||` branches both produce output
- `loop` contains an evaluation node (termination condition)
- Every node has a purpose (name or comment)

The checker does NOT validate:

- Semantic compatibility between nodes
- Whether reference tools exist
- Tool parameter formats
- Anything requiring execution
