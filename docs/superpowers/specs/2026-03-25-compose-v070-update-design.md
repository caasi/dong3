# Compose Plugin v0.7.0 Update Design

**Date:** 2026-03-25
**Scope:** Align `compose` plugin (dong3) with upstream `ocaml-compose-dsl` v0.7.0

## Context

Upstream [ocaml-compose-dsl v0.7.0](https://github.com/caasi/ocaml-compose-dsl/releases/tag/v0.7.0) ships two changes:

1. **PR #17 — Specific warning for `?` as `|||` operand.** The checker now warns that `?` already implies `|||` with an implicit empty branch, so using `?` as an operand of `|||` is redundant.
2. **PR #18 — Optional type annotations (`:: Ident -> Ident`).** Nodes and terms can carry type annotations for documentation purposes. The checker parses them into the AST but performs no type checking.

## Changes

### 1. Version Bumps

| File | Field | Old | New |
|------|-------|-----|-----|
| `.claude-plugin/marketplace.json` | `compose.version` | `0.6.1` | `0.7.0` |
| `plugins/compose/skills/compose/SKILL.md` | Version check text (line 18) | `v0.6.1` | `v0.7.0` |

### 2. EBNF Grammar (`references/dsl-grammar.md`)

Add type annotation syntax. The key grammar change:

```ebnf
typed_term  = term , [ "::" , type_expr ] ;
type_expr   = ident , "->" , ident ;
```

Update `par_expr` to reference `typed_term` instead of `term`:

```ebnf
par_expr = typed_term , ( "***" | "&&&" ) , par_expr
         | typed_term ;
```

Note: `typed_term` sits at the `par_expr` level, but since `seq_expr` and `alt_expr` both bottom out through `par_expr → typed_term → term`, every term position in the grammar can carry an annotation. This is consistent with upstream.

Add a new section explaining:
- `::` introduces an optional type annotation on any term
- `type_expr` is `Ident -> Ident` (input type → output type)
- Annotations are documentation-only; the checker does not validate types
- Annotations bind at the `par_expr` level — they attach to the preceding term before `***`/`&&&`/`|||`/`>>>` are considered

Add a Type Annotations entry to the Combinator table and a dedicated examples subsection.

### 3. SKILL.md Updates

#### 3a. Core Concepts — New "Type Annotations" subsection

After the Node Design section, add:

```markdown
### Type Annotations

Nodes and terms can carry optional type annotations using `::`:

    fetch(url: "https://example.com") :: URL -> HTML
      >>> parse :: HTML -> Data
      >>> format(as: report) :: Data -> Report

Annotations document intended data flow for humans and agents reading the pipeline. The checker parses them but performs no type checking.
```

#### 3b. Checker Warnings — Add new warning

Extend the existing warnings list:

```markdown
- `?` without matching `|||` — the Either produced by `?` has no consumer
- `?` as operand of `|||` — `?` already implies `|||` with an implicit empty branch; using both is redundant
```

#### 3c. Examples list — Add new entry

Add to the examples list:

```markdown
- **`examples/type-annotations.arr`** — Type annotation syntax (`:: Ident -> Ident`) on sequential, parallel, fanout, loop, and question terms
```

### 4. New Example: `examples/type-annotations.arr`

A focused example demonstrating type annotations across all combinator forms:

- Sequential: `node :: A -> B >>> node :: B -> C`
- Parallel: `(node :: A -> B *** node :: C -> D)`
- Fanout: `(node :: A -> B &&& node :: A -> C)`
- Loop: `loop(node :: State -> State)`
- Question: `node? :: Input -> Either`
- Grouping: `(node >>> node) :: A -> C`
- With comments: annotations + comments coexisting
- Unicode: annotations on unicode-named nodes

### 5. `frontend-project.arr` Updates

#### 5a. Restructure Handoff Section (lines 121–149 of `frontend-project.arr`)

Replace the Phase 3 Handoff block from `-- Phase 3: Handoff` (line 120) through the `Handoff會議QA紀錄` line (line 150). The critical change is in the AI-generation-vs-manual-handoff fallback (original lines 126–140):

**Before (triggers v0.7.0 warning — `?` as `|||` operand):**
```
>>> Figma(任務: Dev_Mode啟用)
>>> (
  Figma(任務: 元件文件撰寫, 含: Props與Variants) &&& Figma(任務: Design_Token匯出, 格式: JSON)
)
>>> (
  Figma_MCP(任務: 讀取元件規格)
    >>> (
      Cursor(任務: 生成元件程式碼) &&& Claude(任務: 程式碼品質檢查)
    )
    >>> Cursor(任務: 修正生成結果)? -- known false positive: ? matches ||| below
  |||
  (
    Zeplin(任務: 標註匯出)
    >>> (
      Notion(文件: 元件規格)
      &&& Notion(文件: 互動行為描述)
      &&& Notion(文件: 邊界情況清單)
    )
  )
)
```

**After (clean, no warning):**
```
>>> Figma(任務: Dev_Mode啟用)
>>> (
  Figma(任務: 元件文件撰寫, 含: Props與Variants) &&& Figma(任務: Design_Token匯出, 格式: JSON)
)
>>> Figma_MCP(任務: 讀取元件規格)
>>> AI生成品質評估?
>>> (
  (Cursor(任務: 生成元件程式碼) &&& Claude(任務: 程式碼品質檢查))
    >>> Cursor(任務: 修正生成結果)
  |||
  Zeplin(任務: 標註匯出)
    >>> (Notion(文件: 元件規格) &&& Notion(文件: 互動行為描述) &&& Notion(文件: 邊界情況清單))
)
```

The decision point (`AI生成品質評估?`) is now an explicit node producing Either, consumed by the `|||` below. The `-- known false positive` comment is removed because the pattern is no longer present.

#### 5b. Add Type Annotations Throughout

Add `:: Ident -> Ident` annotations to as many nodes as possible across all 5 phases. Goals:

- Stress-test parser handling of `::` mixed with `>>>`, `***`, `&&&`, `|||`, `?`, `loop()`
- Exercise annotations on unicode-named nodes
- Exercise annotations adjacent to comments
- Exercise annotations on grouped expressions

Approximate annotation density: every node or grouped expression that has a clear input/output type gets one. Expected ~80+ annotations across the 230-line file.

### 6. Files Not Changed

- `scripts/install.sh` — Already fetches latest release; no changes needed.
- `plugin.json` — No metadata changes needed (version lives in marketplace.json).
- Other examples — Not modified; type annotations are opt-in documentation.

## Validation

After all changes, run:

```bash
ocaml-compose-dsl examples/type-annotations.arr
ocaml-compose-dsl examples/frontend-project.arr
```

Both must exit 0 with no warnings. (The old `?` as `|||` operand warning must be gone from `frontend-project.arr`.)
