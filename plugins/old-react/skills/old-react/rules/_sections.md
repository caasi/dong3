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
