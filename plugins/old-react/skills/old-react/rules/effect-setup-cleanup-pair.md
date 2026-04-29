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
```tsx
function ChatRoom({ roomId }: { roomId: string }) {
  useEffect(() => {
    const conn = createConnection(roomId);
    conn.connect();
    // no cleanup; old conn leaks every time roomId changes
  }, [roomId]);
}
```

**Correct** (setup returns its cleanup):
```tsx
function ChatRoom({ roomId }: { roomId: string }) {
  useEffect(() => {
    const conn = createConnection(roomId);
    conn.connect();
    return () => conn.disconnect();
  }, [roomId]);
}
```

A useful test: read the effect body and ask *"if `roomId` changes, does this still hold?"*. If the answer requires the cleanup to run first, the cleanup must be in the same effect.
