# Property-Based Testing Patterns

A catalog of common PBT patterns for writing the `Properties` section of constraint files. Each pattern includes a semi-formal template and a concrete TypeScript fast-check example.

## Roundtrip

Encoding followed by decoding (or vice versa) returns the original value.

**Template:** `forall x: decode(encode(x)) === x`

**Typical domains:** JSON serialization, API request/response mapping, URL encoding, base64.

```typescript
import * as fc from "fast-check";

fc.assert(
  fc.property(fc.jsonValue(), (original) => {
    const serialized = JSON.stringify(original);
    const deserialized = JSON.parse(serialized);
    expect(deserialized).toEqual(original);
  })
);
```

## Idempotent

Applying a function twice yields the same result as applying it once.

**Template:** `forall x: f(f(x)) === f(x)`

**Typical domains:** formatting, normalization, deduplication, cache warming.

```typescript
import * as fc from "fast-check";

function normalize(s: string): string {
  return s.trim().replace(/\s+/g, " ").toLowerCase();
}

fc.assert(
  fc.property(fc.string(), (input) => {
    const once = normalize(input);
    const twice = normalize(once);
    expect(twice).toBe(once);
  })
);
```

## Invariant

A measurable property is preserved across a transformation.

**Template:** `forall xs: sort(xs).length === xs.length`

**Typical domains:** collection operations, tree transformations, data migrations.

```typescript
import * as fc from "fast-check";

fc.assert(
  fc.property(fc.array(fc.integer()), (xs) => {
    const sorted = [...xs].sort((a, b) => a - b);
    const expected = [...xs].sort((a, b) => a - b);
    // Length is preserved
    expect(sorted.length).toBe(xs.length);
    // Every original element is present
    expect(sorted).toEqual(expected);
  })
);
```

## Commutative

The order of operands does not affect the result.

**Template:** `forall a, b: f(a, b) === f(b, a)`

**Typical domains:** set union/intersection, config merging, permission combination.

```typescript
import * as fc from "fast-check";

function mergeConfigs(
  a: Record<string, number>,
  b: Record<string, number>
): Record<string, number> {
  // A commutative merge: take the max value for each key
  const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
  const result: Record<string, number> = {};
  for (const k of keys) {
    result[k] = Math.max(a[k] ?? 0, b[k] ?? 0);
  }
  return result;
}

const configArb = fc.dictionary(
  fc.string({ minLength: 1, maxLength: 5 }),
  fc.integer({ min: 0, max: 100 })
);

fc.assert(
  fc.property(configArb, configArb, (a, b) => {
    expect(mergeConfigs(a, b)).toEqual(mergeConfigs(b, a));
  })
);
```

## Model-Based

An implementation under test agrees with a simpler reference implementation on all inputs.

**Template:** `forall input: impl(input) === reference(input)`

**Typical domains:** refactored code vs original, optimized path vs naive path, new parser vs legacy parser.

```typescript
import * as fc from "fast-check";

// Reference: simple but correct
function fibNaive(n: number): number {
  if (n <= 1) return n;
  return fibNaive(n - 1) + fibNaive(n - 2);
}

// Implementation: optimized
function fibFast(n: number): number {
  let a = 0, b = 1;
  for (let i = 0; i < n; i++) {
    [a, b] = [b, a + b];
  }
  return a;
}

fc.assert(
  fc.property(fc.integer({ min: 0, max: 30 }), (n) => {
    expect(fibFast(n)).toBe(fibNaive(n));
  })
);
```

## State Machine

A sequence of arbitrary transitions, applied from an initial state, always lands in a valid state.

**Template:** `forall transitions: apply(transitions, initial).state ∈ validStates`

**Typical domains:** entity lifecycle (order status, user account state), protocol handshakes, UI state.

```typescript
import * as fc from "fast-check";

type OrderStatus = "draft" | "placed" | "shipped" | "delivered" | "cancelled";
type OrderAction = "place" | "ship" | "deliver" | "cancel";

const validTransitions: Record<OrderStatus, Partial<Record<OrderAction, OrderStatus>>> = {
  draft:     { place: "placed", cancel: "cancelled" },
  placed:    { ship: "shipped", cancel: "cancelled" },
  shipped:   { deliver: "delivered" },
  delivered: {},
  cancelled: {},
};

const validStates = new Set<OrderStatus>(["draft", "placed", "shipped", "delivered", "cancelled"]);

function applyAction(state: OrderStatus, action: OrderAction): OrderStatus {
  return validTransitions[state][action] ?? state;
}

const actionArb = fc.constantFrom<OrderAction>("place", "ship", "deliver", "cancel");

fc.assert(
  fc.property(fc.array(actionArb, { minLength: 1, maxLength: 20 }), (actions) => {
    let state: OrderStatus = "draft";
    for (const action of actions) {
      state = applyAction(state, action);
      expect(validStates.has(state)).toBe(true);
    }
  })
);
```

## Common Pitfalls

### Trivially True Properties

A property that can never fail provides zero value. Watch for:

- **Tautologies:** `forall x: x === x` — always true, tests nothing.
- **Vacuous preconditions:** `forall x where false: anything` — the precondition filters out all inputs, so the property never runs.
- **Weak assertions:** `forall x: typeof f(x) === "object"` — almost any function returning an object passes this; it does not test behavior.

**How to detect:** If a property still passes after you deliberately break the code under test, the property is trivially true.

### Mutation Testing as a Safety Net

Mutation testing (Layer 4 in the enforcement pipeline) systematically catches trivially true properties:

1. Stryker introduces small code mutations (e.g., `+` to `-`, `>` to `>=`, remove a statement).
2. If your property still passes after a mutation, the mutant **survives** — meaning your property did not detect the change.
3. A surviving mutant signals either a **weak property** (strengthen the assertion) or a **missing property** (add a new one covering the mutated code path).

**Rule of thumb:** A property that does not kill any mutants is suspect. Aim for each property to kill at least one mutant that no other property catches.
