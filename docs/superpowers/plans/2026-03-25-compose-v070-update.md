# Compose Plugin v0.7.0 Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the `compose` plugin with upstream `ocaml-compose-dsl` v0.7.0, adding type annotation syntax support and the new `?` as `|||` operand warning to all documentation, plus updating `frontend-project.arr`.

**Architecture:** Documentation-only update across 5 files. No runtime code changes. The binary installer already fetches latest. Changes: version bumps → grammar docs → SKILL.md → new example → existing example update. Each task validated by running `ocaml-compose-dsl` against `.arr` files.

**Tech Stack:** Arrow DSL (`.arr` files), Markdown documentation, `ocaml-compose-dsl` binary (v0.7.0)

---

## Prerequisites

Before starting, upgrade the local binary to v0.7.0:

```bash
plugins/compose/skills/compose/scripts/install.sh
ocaml-compose-dsl --version  # expect: ocaml-compose-dsl 0.7.0
```

Create a feature branch (code changes must not go on main):

```bash
git checkout -b feat/compose-v070-update
```

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `.claude-plugin/marketplace.json` | Version bump `0.6.1` → `0.7.0` |
| Modify | `plugins/compose/skills/compose/SKILL.md` | Version check, type annotations section, checker warnings, examples list |
| Modify | `plugins/compose/skills/compose/references/dsl-grammar.md` | EBNF grammar, combinator table, examples |
| Create | `plugins/compose/skills/compose/examples/type-annotations.arr` | New example showcasing type annotation syntax |
| Modify | `plugins/compose/skills/compose/examples/frontend-project.arr` | Restructure handoff, add type annotations throughout |

---

### Task 1: Upgrade Binary and Create Feature Branch

**Files:** None (environment setup)

- [ ] **Step 1: Upgrade ocaml-compose-dsl to v0.7.0**

```bash
plugins/compose/skills/compose/scripts/install.sh
```

Expected output includes: `Installing ocaml-compose-dsl v0.7.0`

- [ ] **Step 2: Verify version**

```bash
ocaml-compose-dsl --version
```

Expected: `ocaml-compose-dsl 0.7.0`

- [ ] **Step 3: Create feature branch**

```bash
git checkout -b feat/compose-v070-update
```

---

### Task 2: Version Bumps

**Files:**
- Modify: `.claude-plugin/marketplace.json:22` — change `"version": "0.6.1"` to `"version": "0.7.0"`
- Modify: `plugins/compose/skills/compose/SKILL.md:18` — change `**v0.6.1**` to `**v0.7.0**`

- [ ] **Step 1: Bump marketplace.json version**

In `.claude-plugin/marketplace.json`, change the compose plugin version:

```json
"version": "0.7.0"
```

- [ ] **Step 2: Bump SKILL.md version check**

In `plugins/compose/skills/compose/SKILL.md` line 18, change:

```markdown
This skill requires **v0.7.0** or later.
```

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json plugins/compose/skills/compose/SKILL.md
git commit -m "chore(compose): bump version to 0.7.0"
```

---

### Task 3: Update EBNF Grammar (`references/dsl-grammar.md`)

**Files:**
- Modify: `plugins/compose/skills/compose/references/dsl-grammar.md`

- [ ] **Step 1: Add `typed_term` and `type_expr` rules to EBNF**

In the EBNF section, update `par_expr` to reference `typed_term` instead of `term`, and add the two new rules between `par_expr` and `question_term`:

```ebnf
par_expr = typed_term , ( "***" | "&&&" ) , par_expr      (* parallel / fanout — infixr 3 *)
         | typed_term ;

typed_term = term , [ "::" , type_expr ] ;             (* optional type annotation *)

type_expr  = ident , "->" , ident ;
```

- [ ] **Step 2: Add Type Annotation entry to Combinator table**

Add a row to the Combinator table after the Group entry:

```markdown
| Type Ann | `term :: A -> B` | — | Documentation annotation | No direct expansion |
```

- [ ] **Step 3: Add Type Annotations examples subsection**

After the existing "Question Operator" examples subsection (around line 166), add:

```markdown
### Type Annotations

Nodes and terms can carry optional type annotations using `::`:

\`\`\`
fetch(url: "https://example.com") :: URL -> HTML
  >>> parse :: HTML -> Data
  >>> format(as: report) :: Data -> Report
\`\`\`

Annotations document intended data flow for humans and agents. The checker parses them into the AST but performs **no type checking** — they are purely documentation.

Type annotations bind at the `par_expr` level (tighter than all infix operators):

\`\`\`
-- annotation attaches to the preceding term, not the whole chain
read :: File -> CSV >>> parse :: CSV -> Data

-- annotate grouped expressions
(read >>> parse) :: File -> Data
\`\`\`
```

- [ ] **Step 4: Update Warnings subsection**

In the "Warnings" section at the bottom (around line 242), add the new warning:

```markdown
- `?` as operand of `|||` — `?` already implies `|||` with an implicit empty branch; using both is redundant
```

- [ ] **Step 5: Add note about type annotation scope to the explanatory text after EBNF**

After the existing paragraph about identifiers/UTF-8 (around line 56), add:

```markdown
`typed_term` sits at the `par_expr` level, but since `seq_expr` and `alt_expr` both bottom out through `par_expr → typed_term → term`, every term position in the grammar can carry a `:: Ident -> Ident` annotation. Annotations are documentation-only; the checker does not validate types.
```

- [ ] **Step 6: Commit**

```bash
git add plugins/compose/skills/compose/references/dsl-grammar.md
git commit -m "docs(compose): add type annotation syntax and new warning to grammar reference"
```

---

### Task 4: Update SKILL.md (Type Annotations, Warnings, Examples List)

**Files:**
- Modify: `plugins/compose/skills/compose/SKILL.md`

- [ ] **Step 1: Add Type Annotations subsection**

After the "Node Design" section (after line 53), add:

```markdown
### Type Annotations

Nodes and terms can carry optional type annotations using `::`:

\`\`\`
fetch(url: "https://example.com") :: URL -> HTML
  >>> parse :: HTML -> Data
  >>> format(as: report) :: Data -> Report
\`\`\`

Annotations document intended data flow for humans and agents reading the pipeline. The checker parses them but performs no type checking.
```

- [ ] **Step 2: Update Checker Warnings section**

Replace the existing single-item warnings list (around line 113) with:

```markdown
- `?` without matching `|||` — the Either produced by `?` has no consumer
- `?` as operand of `|||` — `?` already implies `|||` with an implicit empty branch; using both is redundant
```

- [ ] **Step 3: Add type-annotations.arr to Examples list**

In the examples list (around line 202), add after the `question-operator.arr` entry:

```markdown
- **`examples/type-annotations.arr`** — Type annotation syntax (`:: Ident -> Ident`) on sequential, parallel, fanout, loop, and question terms
```

- [ ] **Step 4: Commit**

```bash
git add plugins/compose/skills/compose/SKILL.md
git commit -m "docs(compose): add type annotations and new checker warning to SKILL.md"
```

---

### Task 5: Create `type-annotations.arr` Example

**Files:**
- Create: `plugins/compose/skills/compose/examples/type-annotations.arr`

- [ ] **Step 1: Write the example file**

```
-- Type annotations: optional :: Ident -> Ident on any term
-- Annotations document data flow; the checker does not validate types

-- Sequential with annotations
fetch(url: "https://example.com") :: URL -> HTML
  >>> parse :: HTML -> Data
  >>> filter(condition: "age > 18") :: Data -> Data
  >>> format(as: report) :: Data -> Report

-- Parallel with annotations
(resize(width: 1920) :: Image -> Image *** compress(quality: 85) :: Audio -> Audio)
  >>> package :: Assets -> Bundle

-- Fanout with annotations
(lint :: Code -> Result &&& test(suite: unit) :: Code -> Result)
  >>> gate(require: [pass, pass]) :: Results -> Verdict

-- Loop with annotation
loop(
  generate(from: spec) :: Spec -> Code
    >>> verify(method: tests) :: Code -> Result
    >>> "all tests pass"?
    >>> (done :: Result -> Output ||| fix :: Result -> Spec)
)

-- Question with annotation
fetch(url: primary)? :: URL -> Either
  ||| fetch(url: mirror) :: URL -> Response

-- Grouped expression with annotation
(read(source: "data.csv") >>> parse(format: csv)) :: File -> Data
  >>> (count :: Data -> Stats &&& collect(fields: [email]) :: Data -> List)
  >>> format(as: report) :: Pair -> Report

-- Annotations with comments
fetch(url: endpoint) :: URL -> JSON  -- ref: WebFetch
  >>> validate(schema: v2) :: JSON -> ValidJSON  -- ref: Bash("ajv")
  >>> store(dest: db) :: ValidJSON -> Ack  -- ref: Bash("psql")

-- Unicode nodes with annotations
読み込み(ソース: "データ.csv") :: ファイル -> 生データ
  >>> フィルタ(条件: "年齢 > 18") :: 生データ -> フィルタ済み
  >>> 出力 :: フィルタ済み -> レポート
```

- [ ] **Step 2: Validate with checker**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/type-annotations.arr
```

Expected: exit 0, AST output, no warnings on stderr.

- [ ] **Step 3: Fix any validation errors and re-run until clean**

- [ ] **Step 4: Commit**

```bash
git add plugins/compose/skills/compose/examples/type-annotations.arr
git commit -m "feat(compose): add type-annotations.arr example"
```

---

### Task 6: Update `frontend-project.arr` — Restructure Handoff + Add Type Annotations

**Files:**
- Modify: `plugins/compose/skills/compose/examples/frontend-project.arr`

This is the largest task. Two sub-goals: (a) restructure lines 125–140 to eliminate the `?` as `|||` operand pattern, (b) add `:: Ident -> Ident` annotations throughout all 5 phases.

- [ ] **Step 1: Restructure the Handoff fallback (lines 125–140)**

Replace lines 125–140:

```
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

With:

```
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

- [ ] **Step 2: Validate restructure only (before adding annotations)**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/frontend-project.arr
```

Expected: exit 0, no warnings. The old `?` as `|||` operand warning must be gone.

- [ ] **Step 3: Add type annotations throughout all 5 phases**

Add `:: Ident -> Ident` annotations to every node and grouped expression where input/output types are clear. Use domain-appropriate type names that mirror the node context. Examples of the annotation style:

- `Google_Meet(對象: 利害關係人, 目的: 需求訪談) :: 專案 -> 訪談紀錄`
- `Claude(任務: 會議重點摘要) :: 逐字稿 -> 摘要`
- `(lint &&& test) :: Code -> Results`
- `loop(...) :: 規格書 -> 定稿` (annotation on the whole loop expression if supported, otherwise on inner terms)

Goals:
- Every standalone node gets an annotation
- Grouped expressions (`(... &&& ...)`, `(... >>> ...)`) get annotations where they represent a meaningful unit
- Annotations inside `loop()` on the inner terms
- Annotations adjacent to `?` (e.g., `內部審查? :: 規格書 -> Either`)
- Annotations adjacent to comments (e.g., `node :: A -> B -- ref: Tool`)
- Mix of ASCII and CJK type names to stress-test the parser
- Target: ~80+ annotations across the file

- [ ] **Step 4: Validate fully annotated file**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/frontend-project.arr
```

Expected: exit 0, no warnings on stderr.

- [ ] **Step 5: Fix any validation errors and re-run until clean**

- [ ] **Step 6: Commit**

```bash
git add plugins/compose/skills/compose/examples/frontend-project.arr
git commit -m "feat(compose): restructure handoff fallback and add type annotations to frontend-project.arr"
```

---

### Task 7: Final Validation

**Files:** None (validation only)

- [ ] **Step 1: Run checker on all .arr examples**

```bash
for f in plugins/compose/skills/compose/examples/*.arr; do
  echo "=== $f ==="
  ocaml-compose-dsl "$f" > /dev/null && echo "OK" || echo "FAIL"
done
```

Expected: all files print `OK`, no FAIL.

- [ ] **Step 2: Verify no warnings on stderr for the two updated files**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/type-annotations.arr 2>&1 >/dev/null
ocaml-compose-dsl plugins/compose/skills/compose/examples/frontend-project.arr 2>&1 >/dev/null
```

Expected: empty stderr for both.

- [ ] **Step 3: Spot-check SKILL.md version string**

```bash
grep -n 'v0.7.0' plugins/compose/skills/compose/SKILL.md
```

Expected: line 18 matches.

- [ ] **Step 4: Spot-check marketplace.json version**

```bash
grep -A1 '"compose"' .claude-plugin/marketplace.json | grep version
```

Expected: `"version": "0.7.0"`
