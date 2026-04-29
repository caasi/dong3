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
```tsx
function load(id: string) {
  return (dispatch: Dispatch) => {
    fetch(`/api/users/${id}`)
      .then(r => r.json())
      .then(u => dispatch({ type: 'user/ok', payload: u }));
  };
}
```

**Correct** (effect is a tagged value the runtime executes):
```tsx
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
```

The runtime that interprets `Cmd` lives at the application edge and can be swapped out for tests, fakes, or replay drivers. The reducer remains pure, and "what happened" is fully captured by the action log plus the cmd log.

> **Footnote — action creators as data constructors.** A common refinement is to wrap each action shape in a small factory function: `const userOk = (data: User): Action => ({ type: 'user/ok', payload: data })`. These are the JS analogue of data constructors in ML/Haskell (`Just x`, `Right e`) — value-producing functions tagged by name, with the type system constraining the payload. Cmds can use them directly: `onOk: data => userOk(data as User)`. The action stays pure data; the constructor centralises the shape so call sites cannot mistype the tag.
