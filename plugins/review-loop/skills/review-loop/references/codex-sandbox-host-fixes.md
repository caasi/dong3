# Codex sandbox host fixes (optional)

`review-loop` works correctly **without any of these** — its embedded-diff fallback
sidesteps a broken sandbox entirely (option 5). These fixes are only for restoring
the *native* `codex exec review` path on a host where bubblewrap can't build its
sandbox (Ubuntu 23.10+/24.04 default `kernel.apparmor_restrict_unprivileged_userns=1`).
The skill **never** applies any of them — pick what fits your machine.

Symptom: `sandbox-preflight.sh` prints `broken`, and `codex … review --commit <unpushed-sha>`
returns a false-clean ("…not available in the connected GitHub repository").

| # | Fix | sudo / scope | Trade-off | Prefer when |
|---|-----|--------------|-----------|-------------|
| 1 | `bwrap-userns-restrict` AppArmor profile | sudo; all bwrap callers | durable; also blocks nested-ns escape | you want the native path back, durably |
| 2 | `features.use_legacy_landlock=true` | none; codex only | **deprecated** in recent codex | a quick, no-sudo stopgap |
| 3 | hand-rolled `/etc/apparmor.d/bwrap` (`flags=(unconfined)` + a `userns` rule) | sudo; all bwrap callers | least strict (nested-escape hole) | only if #1 unavailable |
| 4 | `sysctl …apparmor_restrict_unprivileged_userns=0` | sudo; whole system | drops the hardening globally | last resort |
| 5 | skill-side embedded-diff | none | n/a — already automatic | always available; zero config |

## 1. `bwrap-userns-restrict` (recommended durable default)

Ships in Ubuntu's `apparmor-profiles` (default in 25.04; backportable to 24.04). Restores
bwrap's userns under an AppArmor profile **and** denies a sandboxed child from creating
further namespaces (closing the nested-escape gap that option 3 leaves open).

```bash
sudo apt install apparmor-profiles   # if not present
sudo systemctl reload apparmor
```

Verify:

```bash
bwrap --ro-bind / / --unshare-user --unshare-net --dev /dev echo OK   # prints OK
```

## 2. `features.use_legacy_landlock=true` (temporary compatibility workaround)

No sudo, scoped to codex; uses the Landlock LSM instead of bwrap, with the read-only
sandbox preserved. **Recent `codex` marks this deprecated and slated for removal** — treat
it as a stopgap, not a long-term default. If it is removed, fall back to #1 or rely on
the skill-side embedded-diff path.

```toml
# ~/.codex/config.toml
[features]
use_legacy_landlock = true
```

Verify:

```bash
codex exec --json --sandbox read-only review --commit <unpushed-sha>   # produces a real review
```

## 3. Hand-rolled `/etc/apparmor.d/bwrap` (inferior to `bwrap-userns-restrict`)

Works, but is the **least strict** variant: sandboxed children also get userns (the
nested-escape hole that `bwrap-userns-restrict` closes). Use only if option 1 is unavailable.

Create the profile and load it:

```bash
sudo tee /etc/apparmor.d/bwrap >/dev/null <<'EOF'
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
  include if exists <local/bwrap>
}
EOF
sudo apparmor_parser -r /etc/apparmor.d/bwrap
```

Verify:

```bash
bwrap --ro-bind / / --unshare-user --unshare-net --dev /dev echo OK   # prints OK
```

## 4. `sysctl …=0` (last resort — drops hardening system-wide)

```bash
echo 'kernel.apparmor_restrict_unprivileged_userns=0' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl --system
```

This disables the 24.04 unprivileged-userns hardening for **every** process. Not recommended.

Verify:

```bash
sysctl kernel.apparmor_restrict_unprivileged_userns                  # = 0
bwrap --ro-bind / / --unshare-user --unshare-net --dev /dev echo OK  # prints OK
```

## 5. Skill-side embedded-diff (no host change)

This is what `review-loop` does automatically on a `broken`/`unknown` host: it embeds the
diff in the prompt (`git show <sha>` / `git diff <base>...HEAD`), so Codex needs no
sandboxed subprocess to read the tree. Zero config; always available. The other options
only matter if you specifically want the native `review` path back.

Verify (no host change — confirm the fallback itself yields a real review):

```bash
sha=$(git rev-parse HEAD)
printf '%s\n\n%s\n' "Review this diff for correctness and risk:" "$(git show "$sha")" \
  | codex exec --json --sandbox read-only -   # produces a real review with no native sandbox
```
