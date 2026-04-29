# old-react Skill v0.1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `old-react` plugin v0.1.0 — a doc-only Claude Code skill that reviews and refactors pre-RSC React code using 14 FP-thinking rules grounded in render purity, immutable updates, and the Elm Architecture.

**Architecture:** Single plugin at `plugins/old-react/` with one skill (`old-react`), one slash command (`/old-react`), 14 rule files (2 per category × 7 categories), 5 reference docs, and a POSIX-shell rule validator. No build system — pure Markdown + JSON + bash. Marketplace registers the plugin at v0.1.0; `metadata.version` bumps from `1.1.0` → `1.2.0`.

**Tech Stack:** Markdown (rules, references, SKILL.md, README.md), JSON (plugin.json, marketplace.json), POSIX shell (validator).

**Spec:** `docs/superpowers/specs/001-old-react-skill-design.md`

---

## Pre-flight

### Task 0: Create feature branch

**Files:**
- N/A (git only)

- [ ] **Step 1: Verify current branch is `main` and clean**

```bash
git status
git branch --show-current
```

Expected: branch `main`, working tree clean (after the spec commit).

- [ ] **Step 2: Create and check out feature branch**

```bash
git checkout -b feat/old-react-skill
```

Expected: `Switched to a new branch 'feat/old-react-skill'`

---

## Phase 1: Plugin scaffold

### Task 1: Plugin manifest

**Files:**
- Create: `plugins/old-react/.claude-plugin/plugin.json`

- [ ] **Step 1: Create plugin directory and manifest**

```bash
mkdir -p plugins/old-react/.claude-plugin
```

Write `plugins/old-react/.claude-plugin/plugin.json`:

```json
{
  "name": "old-react",
  "description": "FP-thinking review and refactor rules for pre-RSC React projects",
  "author": {
    "name": "caasi"
  },
  "homepage": "https://github.com/caasi/dong3",
  "repository": "https://github.com/caasi/dong3",
  "license": "MIT",
  "keywords": [
    "react",
    "functional-programming",
    "elm-architecture",
    "redux",
    "code-review",
    "refactor",
    "pre-rsc"
  ],
  "skills": "./skills/",
  "commands": "./commands/"
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/old-react/.claude-plugin/plugin.json
git commit -m "feat(old-react): scaffold plugin manifest"
```

---

## Phase 2: Validator (TDD)

The validator is shipped before rules so each rule file can be checked as authored. We TDD it: write a bad fixture, write the validator that catches the bad fixture, then write a good fixture, then assert the validator accepts it.

### Task 2: Validator fixtures and failing test

**Files:**
- Create: `plugins/old-react/skills/old-react/scripts/validate-rules.sh`
- Create: `plugins/old-react/skills/old-react/scripts/fixtures/bad-missing-frontmatter.md`
- Create: `plugins/old-react/skills/old-react/scripts/fixtures/bad-missing-correct-block.md`
- Create: `plugins/old-react/skills/old-react/scripts/fixtures/good-minimal.md`
- Create: `plugins/old-react/skills/old-react/scripts/test-validator.sh`

- [ ] **Step 1: Create scripts directory**

```bash
mkdir -p plugins/old-react/skills/old-react/scripts/fixtures
```

- [ ] **Step 2: Write the bad fixture (missing frontmatter)**

`plugins/old-react/skills/old-react/scripts/fixtures/bad-missing-frontmatter.md`:

```markdown
## Some Rule

This rule has no frontmatter at all.

**Incorrect**:
\`\`\`tsx
const bad = true;
\`\`\`

**Correct**:
\`\`\`tsx
const good = true;
\`\`\`
```

- [ ] **Step 3: Write the bad fixture (missing Correct block)**

`plugins/old-react/skills/old-react/scripts/fixtures/bad-missing-correct-block.md`:

```markdown
---
title: Missing Correct
slug: purity-missing-correct
category: purity
impact: HIGH
tags: [render]
---

## Missing Correct

This rule has Incorrect but no Correct block.

**Incorrect**:
\`\`\`tsx
const bad = true;
\`\`\`
```

- [ ] **Step 4: Write the good fixture**

`plugins/old-react/skills/old-react/scripts/fixtures/good-minimal.md`:

```markdown
---
title: Good Minimal
slug: purity-good-minimal
category: purity
impact: HIGH
tags: [render]
---

## Good Minimal

A minimal valid rule used to smoke-test the validator.

**Incorrect** (mutates state):
\`\`\`tsx
state.x = 1;
\`\`\`

**Correct** (returns new state):
\`\`\`tsx
return { ...state, x: 1 };
\`\`\`
```

- [ ] **Step 5: Write the test runner**

`plugins/old-react/skills/old-react/scripts/test-validator.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/validate-rules.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

echo "Test 1: validator rejects file with missing frontmatter"
if "$VALIDATOR" "$FIXTURES/bad-missing-frontmatter.md" >/dev/null 2>&1; then
  fail "validator accepted bad-missing-frontmatter.md"
fi
pass "rejected missing frontmatter"

echo "Test 2: validator rejects file with missing Correct block"
if "$VALIDATOR" "$FIXTURES/bad-missing-correct-block.md" >/dev/null 2>&1; then
  fail "validator accepted bad-missing-correct-block.md"
fi
pass "rejected missing Correct block"

echo "Test 3: validator accepts good-minimal.md"
if ! "$VALIDATOR" "$FIXTURES/good-minimal.md" >/dev/null 2>&1; then
  fail "validator rejected good-minimal.md"
fi
pass "accepted good-minimal"

echo "All validator tests passed."
```

```bash
chmod +x plugins/old-react/skills/old-react/scripts/test-validator.sh
```

- [ ] **Step 6: Run test runner — expect FAIL because validator does not exist yet**

```bash
plugins/old-react/skills/old-react/scripts/test-validator.sh
```

Expected: failure (the validator script does not exist yet — `bash: …/validate-rules.sh: No such file or directory`).

- [ ] **Step 7: Commit fixtures and test runner**

```bash
git add plugins/old-react/skills/old-react/scripts/
git commit -m "test(old-react): add validator fixtures and failing test"
```

### Task 3: Implement validator

**Files:**
- Create: `plugins/old-react/skills/old-react/scripts/validate-rules.sh`

- [ ] **Step 1: Write the validator**

`plugins/old-react/skills/old-react/scripts/validate-rules.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# validate-rules.sh — verifies a rule file (or all rule files in rules/) has:
#   1. YAML frontmatter with required keys: title, slug, category, impact, tags
#   2. category in the closed set
#   3. impact in the closed set
#   4. slug starts with category prefix and matches filename basename
#   5. body has "## <title>" heading
#   6. body has both **Incorrect** and **Correct** markers
#   7. body has at least one fenced code block after each marker
#
# Usage:
#   validate-rules.sh <file.md>           # validate a single file
#   validate-rules.sh --all <rules-dir>   # validate every non-underscore file under rules/

ALLOWED_CATEGORIES="purity immutable model message effect hooks compose"
ALLOWED_IMPACTS="CRITICAL HIGH MEDIUM LOW"

die() { echo "FAIL: $1: $2" >&2; exit 1; }

extract_frontmatter_value() {
  local file="$1" key="$2"
  awk -v k="$key" '
    BEGIN { in_fm = 0 }
    NR == 1 && /^---$/ { in_fm = 1; next }
    in_fm && /^---$/ { in_fm = 0; exit }
    in_fm && $1 == k":" { sub(/^[^:]+:[[:space:]]*/, ""); print; exit }
  ' "$file"
}

validate_file() {
  local file="$1"
  local base
  base="$(basename "$file" .md)"

  # 1. Has frontmatter
  head -1 "$file" | grep -q '^---$' || die "$file" "missing frontmatter (no leading ---)"

  # 2. Required keys
  for key in title slug category impact tags; do
    local value
    value="$(extract_frontmatter_value "$file" "$key")"
    [ -n "$value" ] || die "$file" "missing frontmatter key '$key'"
  done

  local title slug category impact
  title="$(extract_frontmatter_value "$file" title)"
  slug="$(extract_frontmatter_value "$file" slug)"
  category="$(extract_frontmatter_value "$file" category)"
  impact="$(extract_frontmatter_value "$file" impact)"

  # 3. category in allowed set
  echo "$ALLOWED_CATEGORIES" | tr ' ' '\n' | grep -qx "$category" \
    || die "$file" "category '$category' not in allowed set: $ALLOWED_CATEGORIES"

  # 4. impact in allowed set
  echo "$ALLOWED_IMPACTS" | tr ' ' '\n' | grep -qx "$impact" \
    || die "$file" "impact '$impact' not in allowed set: $ALLOWED_IMPACTS"

  # 5. slug starts with category prefix
  case "$slug" in
    "$category"-*) ;;
    *) die "$file" "slug '$slug' does not start with category prefix '$category-'" ;;
  esac

  # 6. slug matches filename basename
  [ "$slug" = "$base" ] || die "$file" "slug '$slug' does not match filename basename '$base'"

  # 7. Body has the title heading
  grep -qF "## $title" "$file" || die "$file" "missing '## $title' heading in body"

  # 8. Has Incorrect and Correct markers
  grep -q '\*\*Incorrect\*\*' "$file" || die "$file" "missing **Incorrect** marker"
  grep -q '\*\*Correct\*\*' "$file" || die "$file" "missing **Correct** marker"

  # 9. Has at least two fenced code blocks (one per Incorrect/Correct)
  local fence_count
  fence_count="$(grep -c '^```' "$file" || true)"
  if [ "$fence_count" -lt 4 ]; then
    die "$file" "expected at least 2 fenced code blocks (4 fence lines), got $fence_count fence lines"
  fi

  echo "OK: $file"
}

if [ "${1:-}" = "--all" ]; then
  rules_dir="${2:?--all requires a rules directory argument}"
  found_any=0
  for f in "$rules_dir"/*.md; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
      _*) continue ;;
    esac
    found_any=1
    validate_file "$f"
  done
  [ "$found_any" -eq 1 ] || die "$rules_dir" "no rule files found"
else
  [ -n "${1:-}" ] || { echo "Usage: $0 <file.md> | --all <rules-dir>" >&2; exit 2; }
  validate_file "$1"
fi
```

```bash
chmod +x plugins/old-react/skills/old-react/scripts/validate-rules.sh
```

- [ ] **Step 2: Run test runner — expect PASS**

```bash
plugins/old-react/skills/old-react/scripts/test-validator.sh
```

Expected: all three tests pass.

- [ ] **Step 3: Commit**

```bash
git add plugins/old-react/skills/old-react/scripts/validate-rules.sh
git commit -m "feat(old-react): implement rule file validator"
```

---

## Phase 3: Rule template and sections metadata

### Task 4: Rule template

**Files:**
- Create: `plugins/old-react/skills/old-react/rules/_template.md`
- Create: `plugins/old-react/skills/old-react/rules/_sections.md`

- [ ] **Step 1: Create rules directory**

```bash
mkdir -p plugins/old-react/skills/old-react/rules
```

- [ ] **Step 2: Write `_template.md`**

`plugins/old-react/skills/old-react/rules/_template.md`:

```markdown
---
title: <human-readable rule title>
slug: <prefix>-<kebab-slug>     # must match filename basename
category: <one of: purity | immutable | model | message | effect | hooks | compose>
impact: <one of: CRITICAL | HIGH | MEDIUM | LOW>
tags: [<two-to-four tags from the closed set in spec §8>]
---

## <title>

<1–3 sentence why-it-matters, FP-grounded. State the principle, not the rule.>

**Incorrect** (<what's wrong, in <=8 words>):
\`\`\`tsx
// minimal example showing the violation
\`\`\`

**Correct** (<what's right, in <=8 words>):
\`\`\`tsx
// minimal example showing the FP-shaped fix
\`\`\`

<Optional 1–2 paragraph deeper context. May reference `references/*.md`.>

<!--
Author notes:
  - Rule body uses pattern vocabulary only (reducer, action, dispatch, store, message,
    command, subscription, selector, state machine, observable as a concept,
    tagged union, effect handler).
  - Library brand names (Redux, MobX, RxJS, TanStack, SWR, Reselect, Immer, XState, ...)
    are NOT allowed in the rule body. Reference `references/lib-suggestions.md` instead.
  - RxJS operator names (switchMap, mergeMap, debounceTime, ...) count as brand-adjacent.
-->
```

- [ ] **Step 3: Write `_sections.md`**

`plugins/old-react/skills/old-react/rules/_sections.md`:

```markdown
# Section metadata

This file documents the seven rule categories used by `old-react`. Files starting
with `_` are excluded from rule validation and from the rule index.

| Prefix | TEA / mechanism element | Concern | Impact range |
|--------|--------------------------|---------|--------------|
| `purity-` | `view`/`update` are pure | Render and update are pure functions; no `Date.now`, `Math.random`, storage, `setState`, ref reads in render. | CRITICAL–HIGH |
| `immutable-` | `Model` is immutable | Update mechanics: spread, structural sharing, Immer-shape. Never mutate in place. | CRITICAL–HIGH |
| `model-` | `Model` = single tree | State architecture: SSOT, push down, lift to LCA, derive don't store, normalize. | HIGH–MEDIUM |
| `message-` | `Msg` = labeled event | State transitions are discrete tagged values; reducer-shape; replayable from log. | HIGH–MEDIUM |
| `effect-` | `Cmd Msg` / `Sub Msg` | Effects are descriptions; setup/cleanup pair; honest deps; event vs effect. | HIGH–MEDIUM |
| `hooks-` | React mechanism (slot table) | Top-level only, exhaustive deps, custom-hook extraction, no defensive memo. | HIGH–MEDIUM |
| `compose-` | Structure | Function composition over HOC pyramids; custom hooks not render props; leaf purity. | MEDIUM–LOW |
```

- [ ] **Step 4: Commit**

```bash
git add plugins/old-react/skills/old-react/rules/_template.md \
        plugins/old-react/skills/old-react/rules/_sections.md
git commit -m "feat(old-react): add rule template and sections metadata"
```

---

## Phase 4: Rules (14 rules in 7 commits)

Each task creates two rule files for one category, runs the validator over the new files, and commits.

### Task 5: `purity-` rules (2)

**Files:**
- Create: `plugins/old-react/skills/old-react/rules/purity-no-nondeterminism-in-render.md`
- Create: `plugins/old-react/skills/old-react/rules/purity-no-setstate-in-render.md`

- [ ] **Step 1: Write `purity-no-nondeterminism-in-render.md`**

```markdown
---
title: No non-determinism in render
slug: purity-no-nondeterminism-in-render
category: purity
impact: CRITICAL
tags: [render, purity, idempotence]
---

## No non-determinism in render

Components are pure projections of inputs to output: `view = f(props, state)`. Reading wall-clock time, random sources, or external mutable state during render breaks idempotence — the same inputs no longer produce the same output, replay-from-log is broken, and the framework's assumption that re-render is safe collapses.

**Incorrect** (reads wall clock during render):
\`\`\`tsx
function Greeting({ name }: { name: string }) {
  const now = Date.now();
  return <p>Hello {name}, it is {new Date(now).toISOString()}</p>;
}
\`\`\`

**Correct** (time enters as a prop or state):
\`\`\`tsx
function Greeting({ name, now }: { name: string; now: number }) {
  return <p>Hello {name}, it is {new Date(now).toISOString()}</p>;
}
\`\`\`

The same applies to `Math.random()`, `localStorage.getItem`, and any read of an external mutable register. If you need such a value, capture it in state at a known boundary (event handler, effect, props from a parent that itself sourced the value) and pass it in.
```

- [ ] **Step 2: Write `purity-no-setstate-in-render.md`**

```markdown
---
title: No setState in render
slug: purity-no-setstate-in-render
category: purity
impact: CRITICAL
tags: [render, purity, state, update]
---

## No setState in render

Render must produce output without scheduling further state transitions. Calling a setter during render reorders the update graph, can loop, and prevents the framework from treating render as idempotent. State changes belong in event handlers and effects — not in the function body of the component itself.

**Incorrect** (setter called during render):
\`\`\`tsx
function Counter({ initial }: { initial: number }) {
  const [count, setCount] = useState(0);
  if (count < initial) setCount(initial); // schedules an update during render
  return <p>{count}</p>;
}
\`\`\`

**Correct** (initial value handled at state creation):
\`\`\`tsx
function Counter({ initial }: { initial: number }) {
  const [count, setCount] = useState(initial);
  return <p>{count}</p>;
}
\`\`\`

When the dependency really must drive a transition, dispatch the change in a handler or effect, never inline. See `references/hooks-as-slot-table.md` if you need the slot-table mechanics behind why this is enforced rather than merely advised.
```

- [ ] **Step 3: Run validator over new files**

```bash
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/purity-no-nondeterminism-in-render.md
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/purity-no-setstate-in-render.md
```

Expected: `OK: …` for both.

- [ ] **Step 4: Commit**

```bash
git add plugins/old-react/skills/old-react/rules/purity-*.md
git commit -m "feat(old-react): add purity- rules (no-nondeterminism, no-setstate)"
```

### Task 6: `immutable-` rules (2)

**Files:**
- Create: `plugins/old-react/skills/old-react/rules/immutable-spread-not-mutate.md`
- Create: `plugins/old-react/skills/old-react/rules/immutable-no-array-index-mutation.md`

- [ ] **Step 1: Write `immutable-spread-not-mutate.md`**

```markdown
---
title: Spread, do not mutate
slug: immutable-spread-not-mutate
category: immutable
impact: CRITICAL
tags: [state, mutation, update]
---

## Spread, do not mutate

A new state must be a new value. Reference equality on persistent data is what selectors and reconcilers use to decide whether to re-render or recompute; in-place mutation makes the previous and next state indistinguishable. Treat update as a copy-on-write shape, even when the language permits assignment.

**Incorrect** (mutates the existing object):
\`\`\`tsx
function reducer(state: { count: number }, action: { type: 'inc' }) {
  state.count += 1;
  return state;
}
\`\`\`

**Correct** (returns a new object):
\`\`\`tsx
function reducer(state: { count: number }, action: { type: 'inc' }) {
  return { ...state, count: state.count + 1 };
}
\`\`\`

For deeply nested updates a copy-on-write helper that uses Proxies and structural sharing keeps the syntax mutation-shaped while preserving the immutability invariant. The choice of which helper is in `references/lib-suggestions.md`.
```

- [ ] **Step 2: Write `immutable-no-array-index-mutation.md`**

```markdown
---
title: No array index mutation
slug: immutable-no-array-index-mutation
category: immutable
impact: HIGH
tags: [state, mutation, update]
---

## No array index mutation

`xs[i] = v`, `xs.push(v)`, `xs.splice(i, 1)`, and `xs.sort()` all mutate in place. Each one breaks reference equality silently — the array still points to the same allocation, so memoized selectors and reconcilers will not notice the change. Build a new array.

**Incorrect** (mutates in place):
\`\`\`tsx
function addTodo(todos: Todo[], todo: Todo) {
  todos.push(todo);
  return todos;
}
\`\`\`

**Correct** (returns a new array):
\`\`\`tsx
function addTodo(todos: Todo[], todo: Todo) {
  return [...todos, todo];
}
\`\`\`

For sorting, prefer `toSorted` (or a manual `[...xs].sort(cmp)`). For splicing, use `slice` plus spread. The point is not "never write the mutation form anywhere" — it is "never let a mutation cross a state boundary."
```

- [ ] **Step 3: Validate and commit**

```bash
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/immutable-spread-not-mutate.md
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/immutable-no-array-index-mutation.md

git add plugins/old-react/skills/old-react/rules/immutable-*.md
git commit -m "feat(old-react): add immutable- rules (spread-not-mutate, no-array-index-mutation)"
```

### Task 7: `model-` rules (2)

**Files:**
- Create: `plugins/old-react/skills/old-react/rules/model-single-source-of-truth.md`
- Create: `plugins/old-react/skills/old-react/rules/model-derive-dont-store.md`

- [ ] **Step 1: Write `model-single-source-of-truth.md`**

```markdown
---
title: Single source of truth
slug: model-single-source-of-truth
category: model
impact: HIGH
tags: [state, ssot, replay]
---

## Single source of truth

A piece of state should live in one place. If two components hold the "same" value in two pieces of local state, they will drift, and there is no longer a meaningful answer to *"what is the current state?"*. Replay, time-travel, and reasoning about the application as a whole all depend on a single canonical source.

**Incorrect** (the value is mirrored into local state):
\`\`\`tsx
function Form({ user }: { user: User }) {
  const [name, setName] = useState(user.name); // shadow copy
  return <input value={name} onChange={e => setName(e.target.value)} />;
}
\`\`\`

**Correct** (the parent owns the value; the child is a controlled view):
\`\`\`tsx
function Form({ user, onChange }: { user: User; onChange: (u: User) => void }) {
  return (
    <input
      value={user.name}
      onChange={e => onChange({ ...user, name: e.target.value })}
    />
  );
}
\`\`\`

When two siblings need the same value, lift it to their lowest common ancestor or to a store. Mirroring is fine *only* if the mirror is genuinely transient (e.g. a draft that explicitly forks from the source on edit and rejoins on submit), and that fork must be modeled, not implicit.
```

- [ ] **Step 2: Write `model-derive-dont-store.md`**

```markdown
---
title: Derive, don't store
slug: model-derive-dont-store
category: model
impact: HIGH
tags: [state, derivation, ssot]
---

## Derive, don't store

If a value can be computed from the model, do not also keep it in the model. A stored derivation is a second source of truth waiting to drift. Derive at read time; cache only when measurement shows the derivation costs more than the cache management.

**Incorrect** (stores `total` alongside `items`):
\`\`\`tsx
type Cart = { items: Item[]; total: number };

function add(cart: Cart, item: Item): Cart {
  return { items: [...cart.items, item], total: cart.total + item.price };
}
\`\`\`

**Correct** (derives `total` from `items`):
\`\`\`tsx
type Cart = { items: Item[] };

function add(cart: Cart, item: Item): Cart {
  return { items: [...cart.items, item] };
}

function total(cart: Cart): number {
  return cart.items.reduce((sum, item) => sum + item.price, 0);
}
\`\`\`

If `total` is hot, wrap `total` in a memoized selector — that is a *cache*, not a state field, because it is recomputed automatically when its inputs change and never persisted across reloads.
```

- [ ] **Step 3: Validate and commit**

```bash
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/model-single-source-of-truth.md
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/model-derive-dont-store.md

git add plugins/old-react/skills/old-react/rules/model-*.md
git commit -m "feat(old-react): add model- rules (ssot, derive-dont-store)"
```

### Task 8: `message-` rules (2)

**Files:**
- Create: `plugins/old-react/skills/old-react/rules/message-transitions-as-events.md`
- Create: `plugins/old-react/skills/old-react/rules/message-reducer-for-correlated.md`

- [ ] **Step 1: Write `message-transitions-as-events.md`**

```markdown
---
title: Transitions as events
slug: message-transitions-as-events
category: message
impact: HIGH
tags: [events, state, replay]
---

## Transitions as events

Model state changes as discrete labeled events — tagged unions like `{ type: 'todo/added', payload }` — rather than ad hoc imperative steps. The labeled event log is what makes a session replayable: from any earlier state plus the suffix of events you can reach the current state. Inline mutations and unnamed callbacks erase that log.

**Incorrect** (transition has no name; logic and update are tangled):
\`\`\`tsx
function TodoButton({ setTodos }: Props) {
  return (
    <button
      onClick={() => {
        setTodos(prev => [...prev, { id: nextId(), text: 'New', done: false }]);
        analytics.send('todo_added');
      }}
    >
      Add
    </button>
  );
}
\`\`\`

**Correct** (transition is a named event interpreted by the reducer):
\`\`\`tsx
type TodoAction =
  | { type: 'todo/added'; payload: Todo }
  | { type: 'todo/toggled'; id: string };

function TodoButton({ dispatch }: { dispatch: (a: TodoAction) => void }) {
  return (
    <button
      onClick={() =>
        dispatch({ type: 'todo/added', payload: { id: nextId(), text: 'New', done: false } })
      }
    >
      Add
    </button>
  );
}
\`\`\`

Side effects that *accompany* an event (analytics, persistence) belong outside the reducer — see `effect-as-description-not-thunk` for how to model them as values rather than side-effecting callbacks.
```

- [ ] **Step 2: Write `message-reducer-for-correlated.md`**

```markdown
---
title: Reducer for correlated state
slug: message-reducer-for-correlated
category: message
impact: HIGH
tags: [reducer, state, update]
---

## Reducer for correlated state

When two or more state fields must change together — `loading` flips to `false` whenever `data` or `error` arrives, for instance — express them as a single state value driven by a reducer. Independent setters can interleave and produce impossible intermediate states (`loading: true, data: …`), which then become real bugs that retries cannot reproduce.

**Incorrect** (independent setters can interleave):
\`\`\`tsx
function useUser(id: string) {
  const [data, setData] = useState<User | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const [loading, setLoading] = useState(false);
  // ...
}
\`\`\`

**Correct** (a single tagged union captures the legal states):
\`\`\`tsx
type State =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'ok'; data: User }
  | { status: 'error'; error: Error };

type Action =
  | { type: 'fetch' }
  | { type: 'ok'; data: User }
  | { type: 'fail'; error: Error };

function reducer(s: State, a: Action): State {
  switch (a.type) {
    case 'fetch': return { status: 'loading' };
    case 'ok':    return { status: 'ok', data: a.data };
    case 'fail':  return { status: 'error', error: a.error };
  }
}
\`\`\`

The reducer enforces by construction that "loading with data" is unrepresentable. Tagged-union states cost a few lines and pay for themselves the first time the network is slow.
```

- [ ] **Step 3: Validate and commit**

```bash
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/message-transitions-as-events.md
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/message-reducer-for-correlated.md

git add plugins/old-react/skills/old-react/rules/message-*.md
git commit -m "feat(old-react): add message- rules (transitions-as-events, reducer-for-correlated)"
```

### Task 9: `effect-` rules (2)

**Files:**
- Create: `plugins/old-react/skills/old-react/rules/effect-as-description-not-thunk.md`
- Create: `plugins/old-react/skills/old-react/rules/effect-setup-cleanup-pair.md`

- [ ] **Step 1: Write `effect-as-description-not-thunk.md`**

```markdown
---
title: Effect as description, not thunk
slug: effect-as-description-not-thunk
category: effect
impact: HIGH
tags: [effects, replay]
---

## Effect as description, not thunk

An effect should be a value the runtime interprets — a `Cmd`-shaped record like `{ type: 'http/get', url }` — not an opaque function the runtime invokes. A described effect is testable without mocks (compare the value), replayable (re-issue the same description), and inspectable in tooling. A thunk is none of those things, because a function body is not data.

**Incorrect** (effect is an opaque callback; nothing to inspect):
\`\`\`tsx
function load(id: string) {
  return (dispatch: Dispatch) => {
    fetch(`/api/users/${id}`)
      .then(r => r.json())
      .then(u => dispatch({ type: 'user/ok', payload: u }));
  };
}
\`\`\`

**Correct** (effect is a tagged value the runtime executes):
\`\`\`tsx
type Cmd =
  | { type: 'http/get'; url: string; onOk: (data: unknown) => Action; onFail: (e: Error) => Action };

function update(state: State, action: Action): [State, Cmd[]] {
  switch (action.type) {
    case 'user/load':
      return [
        { ...state, status: 'loading' },
        [{ type: 'http/get', url: `/api/users/${action.id}`,
           onOk: data => ({ type: 'user/ok', payload: data as User }),
           onFail: error => ({ type: 'user/fail', error }) }],
      ];
    // ...
  }
}
\`\`\`

The runtime that interprets `Cmd` lives at the application edge and can be swapped out for tests, fakes, or replay drivers. The reducer remains pure, and "what happened" is fully captured by the action log plus the cmd log.
```

- [ ] **Step 2: Write `effect-setup-cleanup-pair.md`**

```markdown
---
title: Setup and cleanup belong together
slug: effect-setup-cleanup-pair
category: effect
impact: HIGH
tags: [effects, subscriptions, lifecycles]
---

## Setup and cleanup belong together

Every subscription, listener, timer, and resource acquisition has three moments: open, close, and re-open when its dependencies change. Splitting these across separate effects is how memory leaks and stale subscriptions get introduced. Co-locate setup and cleanup in a single effect whose dependency list captures *exactly* what would invalidate the subscription.

**Incorrect** (setup in one effect, teardown elsewhere or absent):
\`\`\`tsx
function ChatRoom({ roomId }: { roomId: string }) {
  useEffect(() => {
    const conn = createConnection(roomId);
    conn.connect();
    // no cleanup; old conn leaks every time roomId changes
  }, [roomId]);
}
\`\`\`

**Correct** (setup returns its cleanup):
\`\`\`tsx
function ChatRoom({ roomId }: { roomId: string }) {
  useEffect(() => {
    const conn = createConnection(roomId);
    conn.connect();
    return () => conn.disconnect();
  }, [roomId]);
}
\`\`\`

A useful test: read the effect body and ask *"if `roomId` changes, does this still hold?"*. If the answer requires the cleanup to run first, the cleanup must be in the same effect.
```

- [ ] **Step 3: Validate and commit**

```bash
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/effect-as-description-not-thunk.md
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/effect-setup-cleanup-pair.md

git add plugins/old-react/skills/old-react/rules/effect-*.md
git commit -m "feat(old-react): add effect- rules (as-description, setup-cleanup-pair)"
```

### Task 10: `hooks-` rules (2)

**Files:**
- Create: `plugins/old-react/skills/old-react/rules/hooks-top-level-only.md`
- Create: `plugins/old-react/skills/old-react/rules/hooks-exhaustive-deps.md`

- [ ] **Step 1: Write `hooks-top-level-only.md`**

```markdown
---
title: Hooks at the top level only
slug: hooks-top-level-only
category: hooks
impact: CRITICAL
tags: [render, deps, purity]
---

## Hooks at the top level only

Hook calls are positional — the framework matches them across renders by call index, not by name. If a conditional or early return changes which hooks run, the indices drift and a `useState` from one render reads another hook's slot the next render. The rule "hooks are called at the top level" is the user-facing surface of that mechanism. (`references/hooks-as-slot-table.md`.)

**Incorrect** (conditional hook):
\`\`\`tsx
function Profile({ user }: { user: User | null }) {
  if (!user) return null;
  const [name, setName] = useState(user.name); // index drifts when user is null
  return <input value={name} onChange={e => setName(e.target.value)} />;
}
\`\`\`

**Correct** (hooks unconditionally; branch the render output, not the hook calls):
\`\`\`tsx
function Profile({ user }: { user: User | null }) {
  const [name, setName] = useState(user?.name ?? '');
  if (!user) return null;
  return <input value={name} onChange={e => setName(e.target.value)} />;
}
\`\`\`

Same restriction applies inside loops, `try/catch`, and nested function definitions. Custom hooks (`useFoo`) follow the same rule because they are sequences of hook calls.
```

- [ ] **Step 2: Write `hooks-exhaustive-deps.md`**

```markdown
---
title: Honest dependency arrays
slug: hooks-exhaustive-deps
category: hooks
impact: HIGH
tags: [deps, effects, memoization]
---

## Honest dependency arrays

The dependency array of `useEffect`, `useMemo`, and `useCallback` is a contract: *"these are all the values from the surrounding scope that this body reads."* Lying — omitting a dep, freezing a stale value — does not silence the framework's invalidation, it just makes the bug land somewhere unrelated. Treat the linter (`react-hooks/exhaustive-deps`) as advisory but believe it more than your intuition.

**Incorrect** (effect closes over `userId` but does not list it):
\`\`\`tsx
function useUserData(userId: string) {
  const [data, setData] = useState<User | null>(null);
  useEffect(() => {
    fetch(`/api/users/${userId}`).then(r => r.json()).then(setData);
  }, []); // missing userId
}
\`\`\`

**Correct** (deps reflect reality):
\`\`\`tsx
function useUserData(userId: string) {
  const [data, setData] = useState<User | null>(null);
  useEffect(() => {
    fetch(`/api/users/${userId}`).then(r => r.json()).then(setData);
  }, [userId]);
}
\`\`\`

If a dep is technically required but you genuinely do not want re-runs, the fix is at the data shape — extract a stable identity, lift state, or move the effect into a handler. Silencing the linter is not a fix.
```

- [ ] **Step 3: Validate and commit**

```bash
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/hooks-top-level-only.md
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/hooks-exhaustive-deps.md

git add plugins/old-react/skills/old-react/rules/hooks-*.md
git commit -m "feat(old-react): add hooks- rules (top-level-only, exhaustive-deps)"
```

### Task 11: `compose-` rules (2)

**Files:**
- Create: `plugins/old-react/skills/old-react/rules/compose-no-inline-components.md`
- Create: `plugins/old-react/skills/old-react/rules/compose-leaf-purity.md`

- [ ] **Step 1: Write `compose-no-inline-components.md`**

```markdown
---
title: No inline component definitions
slug: compose-no-inline-components
category: compose
impact: HIGH
tags: [render, composition, refs]
---

## No inline component definitions

Defining a component inside another component creates a new component identity on every render. The reconciler treats each render's nested component as a different type, throws away its state and DOM, and remounts. State is lost, animations restart, focus is lost, and effects fire again as if the subtree just appeared.

**Incorrect** (`Item` is redefined on every render of `List`):
\`\`\`tsx
function List({ items }: { items: Item[] }) {
  function Row({ value }: { value: Item }) {
    return <li>{value.name}</li>;
  }
  return <ul>{items.map(i => <Row key={i.id} value={i} />)}</ul>;
}
\`\`\`

**Correct** (`Row` defined once at module scope):
\`\`\`tsx
function Row({ value }: { value: Item }) {
  return <li>{value.name}</li>;
}

function List({ items }: { items: Item[] }) {
  return <ul>{items.map(i => <Row key={i.id} value={i} />)}</ul>;
}
\`\`\`

If the inner component genuinely needs to close over the parent's data, pass that data as props rather than capturing it lexically.
```

- [ ] **Step 2: Write `compose-leaf-purity.md`**

```markdown
---
title: Keep leaf components pure
slug: compose-leaf-purity
category: compose
impact: MEDIUM
tags: [composition, purity, render]
---

## Keep leaf components pure

Leaf components — the buttons, rows, badges, fields — should accept everything they need as props and return JSX. They should not fetch data, talk to a store directly, or read globals. This is the "presentational" half of the old container/presenter split, and it survives because pure leaves are trivially testable, trivially memoizable, and trivially reusable.

**Incorrect** (leaf reaches into a store):
\`\`\`tsx
function UserBadge() {
  const user = useUserStore(s => s.current); // direct store access
  return <span>{user.name}</span>;
}
\`\`\`

**Correct** (leaf takes its data as a prop):
\`\`\`tsx
function UserBadge({ user }: { user: User }) {
  return <span>{user.name}</span>;
}

function CurrentUserBadge() {
  const user = useUserStore(s => s.current);
  return <UserBadge user={user} />;
}
\`\`\`

The container component (`CurrentUserBadge`) is the only one that knows about the store. Replacing the store, or rendering `UserBadge` from a fixture in a test or storybook, costs nothing.
```

- [ ] **Step 3: Validate and commit**

```bash
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/compose-no-inline-components.md
plugins/old-react/skills/old-react/scripts/validate-rules.sh \
  plugins/old-react/skills/old-react/rules/compose-leaf-purity.md

git add plugins/old-react/skills/old-react/rules/compose-*.md
git commit -m "feat(old-react): add compose- rules (no-inline-components, leaf-purity)"
```

### Task 12: Validate every rule together

**Files:**
- N/A (verification only)

- [ ] **Step 1: Run `--all` over rules directory**

```bash
plugins/old-react/skills/old-react/scripts/validate-rules.sh --all \
  plugins/old-react/skills/old-react/rules
```

Expected: 14 lines `OK: …`, exit 0.

---

## Phase 5: Reference docs

Each reference doc is one task: write the file, then commit. Reference docs are not validated by `validate-rules.sh`; they are free-form prose.

### Task 13: `references/fp-thinking.md`

**Files:**
- Create: `plugins/old-react/skills/old-react/references/fp-thinking.md`

- [ ] **Step 1: Create references directory**

```bash
mkdir -p plugins/old-react/skills/old-react/references
```

- [ ] **Step 2: Write `fp-thinking.md`**

```markdown
# FP thinking, applied to React

> React wants to be Elm. The closer you write code to TEA shape, the more you get for free: Single Source of Truth, time-travel debugging, hot-reloadable logic, replay-from-log. The further you drift, the more rules-of-hooks you need to memorize.

This reference defines the lens that the rules in this skill apply. It is short on history (see `tea-as-backbone.md`) and short on libraries (see `lib-suggestions.md`); the goal here is the lens.

## Three pillars

### 1. Pure leaves

`view = f(model)`. A component is a pure projection of its inputs to JSX. Reading wall-clock time, random sources, storage, or external mutable state during render breaks idempotence and replay.

### 2. Immutable updates

A new state is a new value. Reference equality on persistent data is what selectors, reconcilers, and time-travel use to know that something changed. In-place mutation makes "before" and "after" indistinguishable.

### 3. Effects at the edges

Effects are descriptions interpreted by a runtime, not callbacks invoked from inside business logic. The reducer is pure; the world is not; the boundary between them is explicit.

## Why these three reinforce each other

Drop any one and the others lose value. Mutable state defeats time-travel even with pure render. Pure render with effects-as-callbacks loses replay. Effects-as-data with mutable state cannot reach a known earlier state by replay because "earlier state" is not preserved.

The TEA shape — `Model`, `Msg`, `update`, `view`, `Cmd`, `Sub` — fixes all three at once. That is why every category in this skill traces back to it.

## What FP thinking *is not*

It is not a religion against MobX-style transparent FRP. Mutable observable state with auto-tracked subscriptions is a coherent alternative; the trade is ergonomics for replay. `references/scoreboard.md` makes the trade-off explicit.

It is not a religion against thunks or callbacks in tiny apps either. The cost of effects-as-data shows up at scale, in tests, and in tooling — not in a 50-line prototype.

## How to read a rule

Every rule names: a principle, a concrete failure mode, a concrete fix. The fix is not the only fix; it is the simplest fix that keeps the FP lens intact.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/old-react/skills/old-react/references/fp-thinking.md
git commit -m "docs(old-react): add fp-thinking reference"
```

### Task 14: `references/tea-as-backbone.md`

**Files:**
- Create: `plugins/old-react/skills/old-react/references/tea-as-backbone.md`

- [ ] **Step 1: Write the file**

```markdown
# TEA as the backbone

The Elm Architecture (TEA) is the structural shape behind every category in this skill: `purity-`, `immutable-`, `model-`, `message-`, `effect-`, `hooks-`, `compose-`. Map each category to a TEA element and the rules become legible as one consistent design.

## TEA, in one paragraph

```
type Model     = ...
type Msg       = ...
update         : Msg -> Model -> (Model, Cmd Msg)
view           : Model -> Html Msg
subscriptions  : Model -> Sub Msg
```

`Model` is immutable state. `Msg` is a tagged union of events. `update` is pure: takes a message and the current state, returns the next state and a list of commands to execute. `view` is pure: takes the state and returns a description of the UI. `Cmd` and `Sub` are effect descriptions interpreted by the runtime.

Every TEA element is data. Pure functions never perform effects directly; the runtime does, on values it can inspect and replay.

## Mapping to React idioms

| TEA | React analogue | Rules covering it |
|-----|---------------|-------------------|
| `Model` immutable | one source of state per slice | `model-`, `immutable-` |
| `Msg` tagged union | reducer action types | `message-` |
| `update` pure | reducer / functional setState | `purity-`, `message-` |
| `view = Model -> Html Msg` | function component | `purity-`, `compose-` |
| `Cmd Msg` | effect described as data and dispatched | `effect-` |
| `Sub Msg` | declarative subscription via effect | `effect-` |
| (substrate) | hooks are the slot-table that approximates this | `hooks-` |

The first six rows are language-level concepts in Elm; in React they are conventions. The last row — hooks — is a React-specific mechanism. That is why `hooks-` rules look different in shape (procedural discipline) from the rest (architectural discipline).

## Lineage: Bret Victor → Elm → Redux

The chain is causal, not coincidental.

1. **February 2012** — Bret Victor, *Inventing on Principle*. Live coding demos. Principle: *"creators need an immediate connection to what they're creating."* The time-scrubbing UI is the motivating image. ([Transcript](https://jamesclear.com/great-speeches/inventing-on-principle-by-bret-victor); [video](https://www.youtube.com/watch?v=EGqwXt90ZqA).)
2. **Late 2013 → April 2014** — Laszlo Pandy and Evan Czaplicki, Elm time-travelling debugger. First production-grade implementation; depends on **immutability + purity + TEA shape**. ([Elm news, April 2014](https://elm-lang.org/news/time-travel-made-easy); [Wadler's blog, May 2014](https://wadler.blogspot.com/2014/05/elms-time-travelling-debugger.html).)
3. **Mid-2015** — Dan Abramov and Andrew Clark, Redux. TEA ported to JavaScript with weaker types. `(state, action) → state` is Elm's `update : Msg → Model → Model` minus `Cmd`. Time-travel via Redux DevTools. ([Redux history](https://redux.js.org/understanding/history-and-design/history-of-redux); [interview](https://survivejs.com/blog/redux-interview/); [The Redux Journey, React Europe 2016](https://www.youtube.com/watch?v=uvAXVMwHJXU).)

Each step preserves the substrate that makes time-travel possible: pure functions, immutable state, discrete labeled events. Drop any one and time-travel breaks.

## What "drifts away from TEA" looks like

- State stored in a `useState` *and* mirrored in a parent — no longer a single `Model`.
- A thunk that mutates a global, then dispatches — no longer a `Cmd Msg`.
- A reducer that calls `Math.random()` — no longer a pure `update`.
- A component that reads `localStorage` during render — no longer a pure `view`.
- A subscription set up in `componentDidMount` and never torn down — no longer a `Sub Msg`.

Each is the failure mode of a category in this skill.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/old-react/skills/old-react/references/tea-as-backbone.md
git commit -m "docs(old-react): add tea-as-backbone reference"
```

### Task 15: `references/hooks-as-slot-table.md`

**Files:**
- Create: `plugins/old-react/skills/old-react/references/hooks-as-slot-table.md`

- [ ] **Step 1: Write the file**

```markdown
# Hooks as a slot table

Hooks are not algebraic effects. They are an *approximation* of algebraic effects, implemented as a position-indexed slot table backed by a render-time mutable global. Knowing this is the difference between memorizing the Rules of Hooks and being able to debug a violation from principles.

## What hooks actually are

1. A module-level mutable dispatcher pointer (`ReactCurrentDispatcher.current`) that React swaps on entry and exit of a component render.
2. A per-fiber linked list of hook records (`memoizedState.next.next.next…`).
3. An integer cursor that advances by one for every hook call within a single render.
4. A discipline (the Rules of Hooks) that ensures the cursor stays in lockstep across renders, so the *N*th hook call refers to the same hook record each time.

Drop the discipline and the cursor drifts: a `useState` at slot 2 last render is now at slot 1 and reads someone else's state.

## Why the rules look weird

- "Only call hooks at the top level" — because slot indices are implicit in source position.
- "Only call hooks from React function components or other custom hooks" — because the dispatcher pointer is only set during the render of such functions.
- "Honest dependency arrays" — because the framework cannot inspect the body of an effect to see what it reads; it can only compare the dep array you wrote.

These are *not* arbitrary stylistic preferences. They are the user-visible surface of a slot-table mechanism that has no language-level enforcement.

## What this means for rule design

`hooks-` rules in this skill are procedural: *do this, not that*. Other categories (`purity-`, `model-`, `message-`, `effect-`) are architectural: *shape your code this way and the procedural rules largely take care of themselves*. The two complement each other.

If you find yourself fighting `hooks-exhaustive-deps`, the fix is almost always at a different level — extract a stable identity, lift state, move logic into an event handler — not silence the linter.

## Further reading inside this skill

- `tea-as-backbone.md` — why architecture beats discipline.
- `fp-thinking.md` — the lens behind the architecture.
- `scoreboard.md` — how hooks compare to the original (algebraic effects).
```

- [ ] **Step 2: Commit**

```bash
git add plugins/old-react/skills/old-react/references/hooks-as-slot-table.md
git commit -m "docs(old-react): add hooks-as-slot-table reference"
```

### Task 16: `references/lib-suggestions.md`

**Files:**
- Create: `plugins/old-react/skills/old-react/references/lib-suggestions.md`

- [ ] **Step 1: Write the file**

```markdown
# Library suggestions

The rules in this skill are library-agnostic by design. This reference maps common pre-RSC libraries to the FP principles they embody, so an agent or reader can translate a rule to a concrete tool.

The columns are: TEA fidelity (how closely the library expresses `Model`, `Msg`, `update`, `Cmd`/`Sub`), and immutability discipline (how it handles updates).

## Stores and reducers

| Library | TEA fidelity | Immutability | Notes |
|---------|--------------|--------------|-------|
| **Redux Toolkit** | High (Model + Msg + update; `Cmd` is bolted on as middleware) | High (Immer underneath `createSlice`) | Closest mainstream port of TEA to JS. Time-travel via Redux DevTools. |
| **MobX** | Low (Model + setters + computed; no `Msg`) | Low (mutable observables) | Coherent alternative — TFRP. Trades replay for ergonomics. |
| **Zustand / Jotai** | Medium (small store + setters; reducer optional) | Depends on the user. | Lower ceremony than Redux; FP discipline is on you. |
| **Recoil** | Medium (atoms + selectors) | Medium. | Atom-based, derived selectors are pure. |

## Effect handling

| Library | Effect-as-data | Notes |
|---------|----------------|-------|
| **redux-saga** | Yes (yielded effect descriptions) | Closest mainstream userland approximation of algebraic effect handlers. |
| **redux-observable** | Sort of (Observables) | Genuine compositionality of streams. Steep RxJS learning curve. |
| **redux-thunk** | No (opaque function) | Escape hatch *out* of the eDSL. Avoid for non-trivial flows. |
| **XState** | Yes (state machine = data) | Excellent for correlated state; pairs well with `message-reducer-for-correlated`. |

## Server state

| Library | Notes |
|---------|-------|
| **TanStack Query** | Server cache, request dedup, focus revalidation, retries. The right answer for server state in 2026. |
| **SWR** | Lighter alternative to TanStack Query; same shape. |
| **Apollo / urql** | GraphQL-specific; same family. |

If you keep server state in Redux, you will rebuild a worse version of TanStack Query.

## Selectors and immutability helpers

| Library | Role |
|---------|------|
| **Reselect** | Memoized selectors. Reference-equality cache; defeated by selectors that return fresh objects every call. |
| **Immer** | Copy-on-write with mutation-shaped syntax. The right answer for 95% of "I want immutability without ceremony" cases. |
| **Immutable.js** | Persistent data structures (Map/List/Set/OrderedMap/Record). Strong theory, parallel API breaks JS interop. |

## RxJS

A genuine FRP-shaped library, used both standalone and via `redux-observable`. When you need cancellation, debouncing, racing, or switching, RxJS expresses each as one operator.

Operator names (`switchMap`, `mergeMap`, `debounceTime`, `combineLatest`, …) are RxJS-specific brand vocabulary; rule bodies in this skill do not name them. They belong here.

## Notes for rule authors

- The rule body talks about *patterns*: reducer, action, dispatch, store, message, command, subscription, selector, state machine, observable as a concept.
- This file is where library brand names live. When a rule benefits from "if you use X, see this section", link here.
- Keep the rule body intelligible to a reader who has never used any of these libraries. The pattern names from `references/tea-as-backbone.md` are the canonical vocabulary.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/old-react/skills/old-react/references/lib-suggestions.md
git commit -m "docs(old-react): add lib-suggestions reference"
```

### Task 17: `references/scoreboard.md`

**Files:**
- Create: `plugins/old-react/skills/old-react/references/scoreboard.md`

- [ ] **Step 1: Write the file**

```markdown
# Scoreboard

How each ecosystem item compares to the FP/FRP idea it descends from. Adapted and condensed from `docs/old-react.md` §10. "Degradation" is judged on type-system reflection, compositionality, and operational rigor.

| Ecosystem item | Original idea | Degradation |
|---------------|----------------|-------------|
| React component (`view = f(props, state)`) | Pure ML/Haskell function returning ADT | Mild. Purity is documented and lint-checked, not type-checked. |
| Redux (`reducer + store`) | Elm Architecture (TEA) | Moderate. No `Cmd`/`Sub` discipline; effects are bolted on as middleware. |
| redux-thunk | (none — escape hatch) | Severe. Effects are opaque function bodies. No replay, no introspection. |
| redux-saga | Algebraic effect handlers via coroutines | Moderate. Effects ARE data, handlers compose, but no effect rows in the type system. |
| redux-observable | FRP / Cycle.js with Rx | Mild. Genuine compositionality of streams. RxJS learning curve is the cost. |
| MobX | Transparent FRP | Mild on theory; not first-class in React's mental model. Trades replay for ergonomics. |
| Reselect | Memoization / Om's `=` on persistent data | Mild. Easy to defeat by returning fresh objects. |
| Immer | Copy-on-write with structural sharing | Mild. Pragmatic; not algorithmically optimal but ergonomically excellent. |
| Hooks | Algebraic effects | Severe. Slot-table approximation. Rules enforced by linter, not types. |
| Suspense ("throw a promise") | One-shot delimited continuation | Severe. No real continuation; replay-from-scratch on idempotence assumption. |

## How to use this table

It is not a ranking; it is a translation guide. When the rule body says "model state transitions as discrete labeled events", this table tells you which library expresses that idea cleanly (Redux, redux-saga, XState) and which does not (redux-thunk).

For a longer treatment of any row, see `docs/old-react.md` §3–§10.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/old-react/skills/old-react/references/scoreboard.md
git commit -m "docs(old-react): add scoreboard reference"
```

---

## Phase 6: Skill prompt and slash command

### Task 18: `SKILL.md`

**Files:**
- Create: `plugins/old-react/skills/old-react/SKILL.md`

- [ ] **Step 1: Write the file**

```markdown
---
name: old-react
description: |
  Use when reviewing or refactoring React code in pre-RSC projects (classes, hooks,
  Redux/MobX/observable, Reselect, Immer). Applies FP-thinking rules grounded in
  render purity, immutable updates, and the Elm Architecture (Model, Msg, update,
  view, Cmd, Sub).
  Triggers on phrases like "review my React code", "refactor this class component",
  "audit hooks usage", "review this reducer", or the slash command `/old-react`.
  Out of scope: React Server Components, the `use(promise)` hook, `'use client'`
  and `'use server'` boundaries.
license: MIT
---

# old-react

Review and refactor pre-RSC React code using FP-thinking rules.

## When to apply

This skill activates only when the user explicitly asks for review or refactor of pre-RSC React code, or invokes `/old-react`. Do not auto-apply during unrelated work.

The skill assumes the user is maintaining code written between roughly 2014 and 2023: classes, then hooks, with Redux, MobX, observables, RxJS, and Cycle.js orbiting around it. It deliberately excludes RSC, `use(promise)`, `'use client'`, and `'use server'`. See the **Scope check** section for how to handle files that mix the two eras.

## Core lens (FP thinking)

Three pillars. Read `references/fp-thinking.md` for the full treatment.

1. **Pure render.** `view = f(model)`. No `Date.now`, `Math.random`, storage, `setState`, or ref reads during render.
2. **Immutable updates.** A new state is a new value. Reference equality is what selectors and reconcilers use to detect change.
3. **Effects at the edges.** Effects are descriptions interpreted by a runtime, not callbacks invoked from inside business logic.

The Elm Architecture (TEA) is the shape behind all three. See `references/tea-as-backbone.md`.

## Mode: review

Read the code. Surface violations grouped by category (`purity-`, `immutable-`, `model-`, `message-`, `effect-`, `hooks-`, `compose-`), prioritized within each group by impact (CRITICAL → HIGH → MEDIUM → LOW). For each finding emit:

```
[<rule-slug>] (<impact>) <file>:<line>
  <one-sentence why>
  Before: <minimal snippet>
  After:  <minimal snippet>
```

Group ordering: report `purity-` and `immutable-` violations first; they undermine reasoning about everything else.

## Mode: refactor

Apply rules one at a time. Each refactor produces a minimal diff. If multiple rules apply to one site, fix the highest-impact one first and ask before continuing. Output unified diffs with rationale citing the rule slug.

Never modify code in a span flagged by **Scope check** as out of scope.

## Rule index

Seven categories. Two rules ship in v0.1.0 per category (14 total). The full list of v0.2.0 rules lives in the spec.

| Prefix | Concern | v0.1.0 rules |
|--------|---------|--------------|
| `purity-` | Pure render and update | `purity-no-nondeterminism-in-render`, `purity-no-setstate-in-render` |
| `immutable-` | Update mechanics | `immutable-spread-not-mutate`, `immutable-no-array-index-mutation` |
| `model-` | State architecture (SSOT) | `model-single-source-of-truth`, `model-derive-dont-store` |
| `message-` | Discrete labeled events | `message-transitions-as-events`, `message-reducer-for-correlated` |
| `effect-` | Cmd/Sub-shaped effects | `effect-as-description-not-thunk`, `effect-setup-cleanup-pair` |
| `hooks-` | React mechanism | `hooks-top-level-only`, `hooks-exhaustive-deps` |
| `compose-` | Composition | `compose-no-inline-components`, `compose-leaf-purity` |

Read individual rule files in `rules/<slug>.md` for the full why + Incorrect/Correct + deeper notes.

## Scope check

Apply the following heuristic to every file before review or refactor:

- **File-level directives.** If line 1 (after optional comments) is `'use client'` or `'use server'`, **skip the whole file** and report `out of scope: directive '<…>' at line 1`.
- **Async function components.** If a top-level component is `async function` or `export default async function`, **skip its body** but review same-file pure helpers and pure components that don't depend on its output.
- **`use(promise)` / `use(context)` calls.** Skip the enclosing component body. Annotate the skipped span with `<file>:<start-line>-<end-line>`.
- **Server actions.** Functions whose body begins with `'use server'` directive: skip the function. Surrounding pure utilities remain in scope.
- **Mixed file.** Review only in-scope functions. Emit a `Skipped` section listing each out-of-scope span.
- **Refactor mode** never modifies code inside a skipped span, even when other rules might tangentially apply.

## Vocabulary discipline

The rule bodies use FP/TEA pattern terms only: reducer, action, dispatch, store, message, command, subscription, selector, state machine, observable (as a concept), tagged union, effect handler. Library brand names — Redux, MobX, RxJS, TanStack, SWR, Reselect, Immer, XState — and RxJS operator names live in `references/lib-suggestions.md`.

When recommending a library to the user, link to that reference rather than inlining the suggestion in the finding.

## Output protocol

- **Review** = grouped findings, each citing `<rule-slug>` + impact + before/after.
- **Refactor** = unified diff per rule applied, with rationale citing the rule slug.
- For both modes, end with a one-paragraph summary: how many findings per category, top three most impactful, scope-skipped spans (if any).

## References

- `references/fp-thinking.md` — the lens.
- `references/tea-as-backbone.md` — Elm Architecture, lineage Bret Victor → Elm → Redux.
- `references/hooks-as-slot-table.md` — why Rules of Hooks exist.
- `references/lib-suggestions.md` — library brand names and trade-offs.
- `references/scoreboard.md` — how each ecosystem item degrades from its FP/FRP original.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/old-react/skills/old-react/SKILL.md
git commit -m "feat(old-react): add SKILL.md with rule index and scope check"
```

### Task 19: Slash command

**Files:**
- Create: `plugins/old-react/commands/old-react.md`

- [ ] **Step 1: Create commands directory**

```bash
mkdir -p plugins/old-react/commands
```

- [ ] **Step 2: Write the slash command**

```markdown
---
description: Review or refactor pre-RSC React code with FP-thinking rules
argument-hint: "[review|refactor] [path]"
---

# /old-react

Review or refactor pre-RSC React code using the `old-react` skill.

**Usage:**

- `/old-react` — review the current selection or open file (default mode is `review`).
- `/old-react review [path]` — review the file or directory at `[path]`.
- `/old-react refactor [path]` — apply minimal-diff refactors at `[path]`.

**Scope:**

This command applies only to pre-RSC React: classes, hooks, Redux/MobX/observable patterns, Reselect, Immer. It does not apply to React Server Components, `use(promise)`, `'use client'`, or `'use server'` boundaries; the skill skips those spans and reports them.

**Behavior:**

Invoke the `old-react` skill in the requested mode against the resolved path (default: current context). Follow the skill's output protocol — grouped findings for review, unified diffs for refactor, scope-skipped spans listed at the end.

If the user provides no mode, default to `review`. If no path is provided, use the current open file or selection.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/old-react/commands/old-react.md
git commit -m "feat(old-react): add /old-react slash command"
```

### Task 20: README.md

**Files:**
- Create: `plugins/old-react/skills/old-react/README.md`

- [ ] **Step 1: Write the file**

```markdown
# old-react

Review and refactor pre-RSC React code with FP-thinking rules. Library-agnostic in the rule body; library suggestions live in `references/lib-suggestions.md`.

## What this is

A Claude Code skill that distills a lineage-aware view of React (2014–2023) into 14 actionable rules across seven categories: render purity, immutable updates, model architecture (Single Source of Truth), discrete labeled messages, effects-as-data, hooks discipline, and composition.

The shape is grounded in the Elm Architecture (TEA): `Model`, `Msg`, `update`, `view`, `Cmd`, `Sub`. The closer your React code sits to TEA shape, the more you get for free — Single Source of Truth, time-travel debugging, hot-reloadable logic. The lineage Bret Victor → Elm → Redux is documented in `references/tea-as-backbone.md`.

## Scope

**In scope:** Class components, hooks, Redux / MobX / observables, Reselect, Immer, redux-saga, redux-observable, RxJS, XState, TanStack Query, SWR.

**Out of scope:** React Server Components, the `use(promise)` hook, `'use client'` and `'use server'` boundaries. Files containing these are skipped per the skill's **Scope check**.

## How to use

In any conversation:

```
review this React file with old-react
```

Or use the slash command:

```
/old-react review src/Foo.tsx
/old-react refactor src/Foo.tsx
```

The skill emits grouped findings (review) or unified diffs (refactor), each citing a rule slug like `purity-no-nondeterminism-in-render` so you can look up the principle.

## Categories

| Prefix | Concern |
|--------|---------|
| `purity-` | Pure render and update |
| `immutable-` | Update mechanics |
| `model-` | State architecture (SSOT) |
| `message-` | Discrete labeled events |
| `effect-` | Cmd/Sub-shaped effects |
| `hooks-` | React mechanism |
| `compose-` | Composition |

## Versioning

- v0.1.0 — 14 rules (2 per category), 5 reference docs, slash command, validator.
- v0.2.0 (planned) — fills the remaining 26 rules from the spec.

## See also

- `references/fp-thinking.md`
- `references/tea-as-backbone.md`
- `references/hooks-as-slot-table.md`
- `references/lib-suggestions.md`
- `references/scoreboard.md`
- Spec: `docs/superpowers/specs/001-old-react-skill-design.md`
- Source reference: `docs/old-react.md`
```

- [ ] **Step 2: Commit**

```bash
git add plugins/old-react/skills/old-react/README.md
git commit -m "docs(old-react): add user-facing README"
```

---

## Phase 7: Marketplace registration

### Task 21: Register plugin in marketplace.json

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Add `old-react` to `plugins` array and bump `metadata.version`**

Edit `.claude-plugin/marketplace.json`:

- Bump `metadata.version` from `"1.1.0"` to `"1.2.0"` (per project memory rule on adding plugins).
- Append to the `plugins` array:

```json
{
  "name": "old-react",
  "source": "./plugins/old-react",
  "description": "FP-thinking review and refactor rules for pre-RSC React projects",
  "version": "0.1.0"
}
```

The final relevant slice should look like:

```json
{
  "name": "caasi-dong3",
  "owner": { "name": "caasi" },
  "metadata": {
    "description": "caasi's plugin collection for Claude Code",
    "version": "1.2.0",
    "pluginRoot": "./plugins"
  },
  "plugins": [
    /* …existing entries… */
    {
      "name": "old-react",
      "source": "./plugins/old-react",
      "description": "FP-thinking review and refactor rules for pre-RSC React projects",
      "version": "0.1.0"
    }
  ]
}
```

- [ ] **Step 2: Verify JSON is valid**

```bash
python3 -m json.tool .claude-plugin/marketplace.json > /dev/null && echo "valid"
```

Expected: `valid`.

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "chore(marketplace): register old-react plugin v0.1.0"
```

---

## Phase 8: Final verification

### Task 22: End-to-end checks

**Files:**
- N/A (verification only)

- [ ] **Step 1: Validate every rule**

```bash
plugins/old-react/skills/old-react/scripts/validate-rules.sh --all \
  plugins/old-react/skills/old-react/rules
```

Expected: 14 lines `OK: …`, exit 0.

- [ ] **Step 2: Run validator self-test**

```bash
plugins/old-react/skills/old-react/scripts/test-validator.sh
```

Expected: all three tests pass.

- [ ] **Step 3: Confirm directory tree matches spec §4**

```bash
find plugins/old-react -type f | sort
```

Expected files (sorted):
```
plugins/old-react/.claude-plugin/plugin.json
plugins/old-react/commands/old-react.md
plugins/old-react/skills/old-react/README.md
plugins/old-react/skills/old-react/SKILL.md
plugins/old-react/skills/old-react/references/fp-thinking.md
plugins/old-react/skills/old-react/references/hooks-as-slot-table.md
plugins/old-react/skills/old-react/references/lib-suggestions.md
plugins/old-react/skills/old-react/references/scoreboard.md
plugins/old-react/skills/old-react/references/tea-as-backbone.md
plugins/old-react/skills/old-react/rules/_sections.md
plugins/old-react/skills/old-react/rules/_template.md
plugins/old-react/skills/old-react/rules/compose-leaf-purity.md
plugins/old-react/skills/old-react/rules/compose-no-inline-components.md
plugins/old-react/skills/old-react/rules/effect-as-description-not-thunk.md
plugins/old-react/skills/old-react/rules/effect-setup-cleanup-pair.md
plugins/old-react/skills/old-react/rules/hooks-exhaustive-deps.md
plugins/old-react/skills/old-react/rules/hooks-top-level-only.md
plugins/old-react/skills/old-react/rules/immutable-no-array-index-mutation.md
plugins/old-react/skills/old-react/rules/immutable-spread-not-mutate.md
plugins/old-react/skills/old-react/rules/message-reducer-for-correlated.md
plugins/old-react/skills/old-react/rules/message-transitions-as-events.md
plugins/old-react/skills/old-react/rules/model-derive-dont-store.md
plugins/old-react/skills/old-react/rules/model-single-source-of-truth.md
plugins/old-react/skills/old-react/rules/purity-no-nondeterminism-in-render.md
plugins/old-react/skills/old-react/rules/purity-no-setstate-in-render.md
plugins/old-react/skills/old-react/scripts/fixtures/bad-missing-correct-block.md
plugins/old-react/skills/old-react/scripts/fixtures/bad-missing-frontmatter.md
plugins/old-react/skills/old-react/scripts/fixtures/good-minimal.md
plugins/old-react/skills/old-react/scripts/test-validator.sh
plugins/old-react/skills/old-react/scripts/validate-rules.sh
```

- [ ] **Step 4: Confirm marketplace.json is registered**

```bash
grep -c '"name": "old-react"' .claude-plugin/marketplace.json
```

Expected: `1`.

- [ ] **Step 5: Confirm git log**

```bash
git log --oneline main..HEAD
```

Expected: 21 commits, each with a `feat(old-react)`, `docs(old-react)`, `test(old-react)`, or `chore(marketplace)` prefix.

---

## Open the PR

When all tasks are complete, push the branch and open a PR per CLAUDE.md GitHub conventions. Implementation is done at this point; v0.2.0 work is tracked in the spec under §9 (the remaining 26 rules) and is out of scope for this plan.
