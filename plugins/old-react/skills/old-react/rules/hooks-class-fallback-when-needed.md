---
title: Use a class component when hooks cannot express the lifecycle
slug: hooks-class-fallback-when-needed
category: hooks
impact: MEDIUM
tags: [lifecycles, refs, effects, state]
---

## Use a class component when hooks cannot express the lifecycle

A hook is a coordinated read of a slot table during render (see `references/hooks-as-slot-table.md`). It is the right tool when a component's lifecycle decomposes into independent reactive cells. It becomes the wrong tool when React itself has no hook for the lifecycle needed, when stale-closure workarounds overwhelm the FP link "state value → render value", or when setup/teardown for a long-lived imperative resource maps cleanly to mount/unmount but fights the slot-table ordering when expressed as effects. A class component is the **simpler, more honest expression** in all three cases; the rule removes the prohibition on choosing it.

This rule does **not** contradict `react-hooks/rules-of-hooks` or `react-hooks/exhaustive-deps` — those govern hook **correctness**. This rule governs hook **applicability**: when the hook-first instinct should yield to a class.

---

### When class is the correct choice

#### Hard reasons (React itself has no hook equivalent)

1. **Error boundary.** `componentDidCatch` and `static getDerivedStateFromError` are class-only. Community hooks that expose a hook-style API still wrap a class internally.

2. **DOM snapshot before commit.** `getSnapshotBeforeUpdate(prevProps, prevState)` captures scroll position, focus, or measurements *before* the commit phase. `useLayoutEffect` runs *after* the commit — too late.

#### Soft reasons (hooks possible but lossy)

3. **Stale-closure mountain.** Three or more `useRef`s whose sole purpose is to mirror state for read-in-effect access breaks the FP link between state value and rendered value. A class with `this.state` is then more functional in spirit — one source of truth, read directly (see `references/fp-thinking.md`).

4. **1:1 lifecycle mapping for imperative resources.** Long-lived non-React resources (chart libraries, grid widgets, video players) whose setup/teardown maps cleanly to `componentDidMount` / `componentWillUnmount` gain nothing from `useEffect` + cleanup + memoized handler refs and lose execution-order clarity.

5. **Multi-phase update logic with cross-phase data.** When `componentDidUpdate` needs `prevProps`, `prevState`, and the snapshot from `getSnapshotBeforeUpdate`, the class layout reads top-to-bottom. The hook equivalent (chains of `useRef` to remember previous values) is harder to audit and easier to break under concurrent rendering.

#### Detection heuristic

A function component is a candidate for class fallback when **any** holds:

```text
- It tries to implement an error boundary (catches errors thrown by children).
- It needs to capture DOM measurements between render and commit.
- It has ≥ 3 useRef calls whose only purpose is to mirror a state/prop for effect access.
- It has ≥ 4 useEffect calls with overlapping deps that could not be merged.
- It hosts a long-lived imperative resource and the cleanup/teardown is non-trivial.
```

When any holds, prefer a class **or** a custom hook that internally encapsulates the imperative concern (so the host component stays simple). The rule does not mandate class — it removes the prohibition.

---

### When class is the WRONG choice (rule does not endorse these)

Class components are **not** justified by:

- Familiarity or habit alone.
- "Hooks have a learning curve" — a transient issue, not a code-quality argument.
- Performance — modern benchmarks show negligible difference for typical components.
- Avoiding the `useEffect` deps array — bypassing it via a class hides the same staleness bug.

---

**Incorrect** (error boundary attempted without class; no hook equivalent exists):

```tsx
function ErrorBoundary({ children }: { children: ReactNode }) {
  // useErrorBoundary() does not exist in React
  return <>{children}</>;
}
```

**Correct** (class with documented lifecycle):

```tsx
class ErrorBoundary extends Component<
  { children: ReactNode },
  { error: Error | null }
> {
  state: { error: Error | null } = { error: null };
  static getDerivedStateFromError(error: Error) { return { error }; }
  componentDidCatch(error: Error, info: ErrorInfo) { logError(error, info); }
  render() {
    return this.state.error
      ? <Fallback error={this.state.error} />
      : this.props.children;
  }
}
```

---

**Incorrect** (stale-closure mountain — three refs mirroring state breaks the FP link):

```tsx
function Editor({ doc, onSave }: Props) {
  const [text, setText] = useState(doc.text);
  const textRef = useRef(text);
  const docRef = useRef(doc);
  const onSaveRef = useRef(onSave);
  useEffect(() => { textRef.current = text; }, [text]);
  useEffect(() => { docRef.current = doc; }, [doc]);
  useEffect(() => { onSaveRef.current = onSave; }, [onSave]);
  // handlers read only refs because state-as-state is unreachable from closures
}
```

**Correct** (one source of truth; render purity restored):

```tsx
class Editor extends Component<Props, { text: string }> {
  state = { text: this.props.doc.text };
  handleSave = () => this.props.onSave(this.state.text, this.props.doc);
  render() { /* reads this.state and this.props directly */ }
}
```

---

**Incorrect** (`useLayoutEffect` runs after commit; scroll position is already lost):

```tsx
function Chat({ messages }: Props) {
  const ref = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    // too late — DOM has already updated
    ref.current!.scrollTop = ref.current!.scrollHeight;
  }, [messages]);
  return <div ref={ref}>{/* ... */}</div>;
}
```

**Correct** (capture DOM snapshot before commit, apply it after):

```tsx
class Chat extends Component<Props> {
  ref = createRef<HTMLDivElement>();
  getSnapshotBeforeUpdate(prevProps: Props) {
    return prevProps.messages.length < this.props.messages.length
      ? this.ref.current!.scrollHeight - this.ref.current!.scrollTop
      : null;
  }
  componentDidUpdate(_p: Props, _s: unknown, snapshot: number | null) {
    if (snapshot != null) {
      const el = this.ref.current!;
      el.scrollTop = el.scrollHeight - snapshot;
    }
  }
  render() { return <div ref={this.ref}>{/* ... */}</div>; }
}
```

---

### Cross-links

- `compose-leaf-purity` — a class component that exposes a clean prop surface and does not reach into a store is still a valid pure leaf. One source of truth in `this.state` satisfies the same leaf-purity intent as a function component relying on local state.
- `effect-setup-cleanup-pair` — `componentDidMount` + `componentWillUnmount` is a valid setup/cleanup host. When a class is chosen for the reasons above, the pairing rule still applies: do not spread setup and teardown across unrelated lifecycle methods.
