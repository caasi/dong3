# Constraint Plugin Design

**Date:** 2026-04-12
**Plugin:** `constraint` (new, v0.1.0)
**Skills:** `constraint-write`, `constraint-generate`, `constraint-enforce`

## Philosophy

Coding agent 讓開發者做的事情本質上是 **metaprogramming in natural language**——用自然語言寫「產生程式碼的程式」。

人類做**深度、聚焦**的事——用自然語言定義什麼是正確的。
Agent 做**廣度、平行**的事——用 deterministic 工具大規模 enforce。

Agent 的不確定性只存在於「決定呼叫什麼工具」這一步。一旦決定了，後面全是確定性的。而「呼叫對了嗎」這件事，工具自己就能驗證（type error、lint error、test failure）。

> Bottleneck 不是 agent 的能力，而是**你手上有多少 deterministic 工具可以讓 agent 操作**。

Constraint 是暫態的（agent 讀一次），artifact 是永久的（進 CI，每次跑）。Constraint 描述意圖，artifact 是機械化的 enforcement——兩者分離，各司其職。

出發點：人類用自然語言書寫法律，由法官（智能體）執行。

## Scope

### In Scope (v0.1.0)

- 三個 skills（`constraint-write`、`constraint-generate`、`constraint-enforce`），Guided Flow
- Constraint 格式：Markdown + frontmatter，Given/When/Then/Unless/Examples/Properties
- `constraints/` 目錄放在 repo root
- `constraint-generate` 先支援 TypeScript（Biome、Typia、fast-check、Stryker）
- 其他語言的 toolchain-matrix 先列出但標註 planned

### Out of Scope

- CI integration（使用者自己把產出的 test artifact 加進 CI）
- Constraint 之間的 cross-reference / dependency
- 自動偵測 code 違反 constraint（由 enforce 跑 test 來驗證）
- Constraint versioning（靠 git）
- 多語言支援（OCaml、Rust、Python）— planned
- `constraint-audit` skill：掃描 codebase 找沒被 constraint 覆蓋的 trust boundary — planned

## Constraint Format

檔案位置：`constraints/<RULE_ID>-<slug>.md`

### Frontmatter

| 欄位 | 必填 | 說明 |
|---|---|---|
| `rule` | 是 | 唯一識別碼（如 `USER_003`），方便 cross-reference |
| `kind` | 是 | `permission` / `prohibition` / `obligation` / `invariant` / `protocol` |
| `scope` | 是 | glob pattern，指定涵蓋的程式碼範圍 |
| `subject` | 否 | 涉及的 domain entity |
| `enforce` | 否 | 建議的 enforcement 手段（`lint`、`ast-grep`、`validation`、`pbt`、`mutation`）。省略時由 `constraint-generate` 自行判斷 |

### Kind 分類

| Kind | 語意 | 典型 enforce |
|---|---|---|
| `permission` | 某條件下允許做某事 | validation, guard |
| `prohibition` | 禁止做某事 | lint, ast-grep |
| `obligation` | 必須做某事 | lint, validation |
| `invariant` | 數學性質，恆為真 | pbt |
| `protocol` | 操作順序/流程約束 | pbt (state machine) |

### Body Sections

採用法律/BDD 混合結構，直接映射到 test 產生：

| Section | 用途 | 映射到 |
|---|---|---|
| **Given** | 前置條件 / 狀態 | test setup (arrange) |
| **When** | 觸發動作 | test action (act) |
| **Then** | 預期結果 | test assertion (assert) |
| **Unless** | 例外條件 + 例外行為（用 `→` 標示結果） | additional test branch |
| **Examples** | 具體的 input → expected output 表格 | parameterized unit test (`it.each`) |
| **Properties** | `forall X where 條件: 性質` 半形式化語法 | fast-check `fc.property()` |

### Example: Domain/State Constraint

```markdown
# constraints/USER_003-soft-deleted-no-login.md
---
rule: USER_003
kind: permission
scope: src/auth/**, src/user/**
subject: User
enforce: validation, pbt
---

## Given
- user.state = soft_deleted

## When
- password login attempted

## Then
- deny login
- return AUTH_DENIED

## Unless
- user.state = recoverable AND deleted_at <= 30 days
- → allow recovery flow only, return RECOVERY_REQUIRED

## Examples
| user.state | deleted_at | action | expected |
|---|---|---|---|
| soft_deleted | 60 days ago | login | AUTH_DENIED |
| hard_deleted | 90 days ago | login | AUTH_DENIED |
| recoverable | 10 days ago | login | RECOVERY_REQUIRED |
| recoverable | 45 days ago | login | AUTH_DENIED |
| active | - | login | SUCCESS |

## Properties
- forall user where state = soft_deleted AND NOT recoverable:
  login(user) → AUTH_DENIED
- forall user where state = hard_deleted:
  search(query) never contains user
```

### Example: Code-Level Constraint

```markdown
# constraints/MONEY_001-no-float-money.md
---
rule: MONEY_001
kind: prohibition
scope: src/billing/**, src/payment/**
enforce: ast-grep, pbt
---

## Given
- 任何處理金額的程式碼

## When
- 宣告變數、函式參數、回傳值涉及金額

## Then
- 必須使用 Decimal 型別
- 乘除運算必須指定 rounding mode

## Unless
- 顯示用途的格式化函式（toDisplayString）可回傳 string
- 測試中的 fixture 資料可用 literal number

## Examples
| context | type used | valid |
|---|---|---|
| calculateTotal() return | Decimal | yes |
| calculateTotal() return | number | no |
| invoice.amount field | Decimal | yes |
| invoice.amount field | float | no |
| toDisplayString() return | string | yes |
| test fixture | 19.99 (literal) | yes |

## Properties
- forall (a: Decimal, b: Decimal, c: Decimal):
  (a + b) + c === a + (b + c)
- forall (amount: Decimal, currency: Currency):
  toUSD(toTWD(amount)) - amount < 0.01
```

## Skills

### `constraint-write`

**Trigger:**
- `/constraint-write`
- 「幫我寫 constraint」、「定義 constraint」
- Agent 在對話中辨識到 constraint 語句時主動建議（「X 不能 Y」、「所有 Z 都必須 W」）

**Behavior:**
1. 如果使用者描述了一個規則 → agent 用對話釐清 Given/When/Then/Unless/Examples/Properties
2. 讀 `references/constraint-format.md` 確認格式規範
3. 產出 `constraints/<RULE_ID>-<slug>.md`
4. 如果 `constraints/` 不存在，自動建立
5. 完成後建議下一步：「constraint 已寫好，要我用 `/constraint-generate` 產生 test artifact 嗎？」

**Agent 主動建議的辨識：** 使用者在對話中說出 prohibition（「不能」、「禁止」、「must not」）、obligation（「必須」、「一定要」、「always」）、或 invariant（「恆等」、「roundtrip」、「idempotent」）語句時，agent 提議寫成 constraint。

### `constraint-generate`

**Trigger:**
- `/constraint-generate`
- 「產生 constraint 的 test」、「generate artifact」

**Behavior:**
1. 掃描 `constraints/*.md`
2. 偵測 repo 的語言和工具鏈：
   - `package.json` / `tsconfig.json` → TypeScript
   - `dune-project` → OCaml
   - `Cargo.toml` → Rust
   - `pyproject.toml` / `setup.py` → Python
3. 查 `references/toolchain-matrix.md` 決定每條 constraint 該用什麼工具
4. Per constraint 產生 artifact：
   - Examples table → parameterized unit test file
   - Properties → fast-check PBT file
   - Prohibition + ast-grep → ast-grep rule YAML
   - Validation → Typia/ArkType/Zod schema（視現有 stack 決定）
5. 產出的 artifact 放在 repo 的既有測試目錄（遵循 repo 的 test 結構）
6. 完成後建議下一步：「artifact 已產生，要我用 `/constraint-enforce` 跑驗證嗎？」

### `constraint-enforce`

**Trigger:**
- `/constraint-enforce`
- 「跑 constraint 驗證」、「enforce constraints」

**Behavior:**
1. 按層級跑 artifact：
   - Layer 1: Lint（Biome / ast-grep rules）
   - Layer 2: Validation（Typia / ArkType / Zod）
   - Layer 3: PBT（fast-check property tests）
   - Layer 4: Mutation testing（Stryker）
2. 報告每層結果
3. Layer 3+4 的回饋迴圈：
   - 跑 mutation testing → 存活 mutant → 分析原因 → 補強 property → 重跑
   - 自動迴圈直到 mutation score 達標或需人工判斷
4. 最終報告：pass/fail 統計、存活 mutant 列表、建議

### Guided Flow（skills 之間的銜接）

三個 skill 獨立可 invoke，每個完成後建議下一步：

```
constraint-write → 「要我 generate artifact 嗎？」
constraint-generate → 「要我跑 enforce 嗎？」
constraint-enforce → 報告結果
```

使用者也可以跳步（例如已有 constraint 直接跑 generate）。

## Plugin Structure

```
plugins/constraint/
  .claude-plugin/plugin.json
  skills/
    constraint-write/
      SKILL.md
      README.md
      references/
        constraint-format.md        # 格式規範 + 完整範例
        property-patterns.md        # roundtrip, idempotent, invariant 等 pattern 速查
    constraint-generate/
      SKILL.md
      README.md
      references/
        toolchain-matrix.md         # 四層工具鏈 × 語言對照表
    constraint-enforce/
      SKILL.md
      README.md
```

## Plugin Registration

**`plugins/constraint/.claude-plugin/plugin.json`:**
```json
{
  "name": "constraint",
  "description": "Natural language constraints → deterministic test artifacts",
  "author": {
    "name": "caasi"
  },
  "homepage": "https://github.com/caasi/dong3",
  "repository": "https://github.com/caasi/dong3",
  "license": "MIT",
  "keywords": ["constraint", "testing", "pbt", "mutation-testing", "verification"],
  "skills": "./skills/"
}
```

**marketplace.json addition:**
```json
{
  "name": "constraint",
  "source": "./plugins/constraint",
  "description": "Natural language constraints → deterministic test artifacts. Write constraints in structured Markdown, generate unit tests / PBT / mutation tests, enforce with deterministic tools.",
  "version": "0.1.0"
}
```

## Deterministic Toolchain Matrix (v0.1.0 — TypeScript only)

| Layer | Tool | Purpose | Status |
|---|---|---|---|
| **Lint** | Biome | Static analysis + formatting | supported |
| **Lint** | ast-grep | Structural code search | supported |
| **Validation** | Typia | Runtime type validation (preferred) | supported |
| **Validation** | ArkType | Set-theory based validation | supported |
| **Validation** | Zod | Schema validation (if already in stack) | supported |
| **PBT** | fast-check | Property-based testing | supported |
| **Mutation** | Stryker | Mutation testing | supported |

Other languages (planned):

| Layer | OCaml | Rust | Python |
|---|---|---|---|
| Lint | ocamlformat | clippy | ruff |
| Validation | Gospel | — | pydantic |
| PBT | QCheck / Ortac | proptest | Hypothesis |
| Mutation | — | cargo-mutants | mutmut |

## References

### Tooling
- [Biome](https://biomejs.dev/)
- [ast-grep](https://ast-grep.github.io/)
- [Typia](https://typia.io/)
- [ArkType](https://arktype.io/)
- [Zod](https://zod.dev/)
- [fast-check](https://fast-check.dev/)
- [Stryker Mutator](https://stryker-mutator.io/docs/)

### Research
- [Anthropic PBT Agent](https://red.anthropic.com/2026/property-based-testing/)
- [Trail of Bits: Mutation Testing for the Agentic Era](https://blog.trailofbits.com/2026/04/01/mutation-testing-for-the-agentic-era/)
- [Meta ACH: LLMs Are the Key to Mutation Testing](https://engineering.fb.com/2025/09/30/security/llms-are-the-key-to-mutation-testing-and-better-compliance/)
