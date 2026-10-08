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
| 1 | `bwrap-userns-restrict` AppArmor profile | sudo; all bwrap callers | durable; sandboxed children get no capabilities; on 24.04 the package does not enable it — see the steps | you want the native path back, durably |
| 2 | `features.use_legacy_landlock=true` | none; codex only | **does not work** in codex-cli 0.156.1 (panic) | never — remove it if it is set |
| 3 | hand-rolled `/etc/apparmor.d/bwrap` (`flags=(unconfined)` + a `userns` rule) | sudo; all bwrap callers | least strict (no limit on sandboxed children) | only if #1 unavailable |
| 4 | `sysctl …apparmor_restrict_unprivileged_userns=0` | sudo; whole system | drops the hardening globally | last resort |
| 5 | skill-side embedded-diff | none | n/a — already automatic | always available; zero config |

## 1. `bwrap-userns-restrict` (recommended durable default)

Ubuntu ships this AppArmor profile in the `apparmor-profiles` package. It lets bwrap
create a user namespace. The children of bwrap run under a second profile,
`unpriv_bwrap`, which has `audit deny capability`. So a sandboxed child gets no
capabilities, and it cannot use bwrap to get around the user namespace restriction.
Option 3 does not have this second profile.

The profile is for `/usr/bin/bwrap` (`profile bwrap /usr/bin/bwrap`). On an Ubuntu
24.04.5 host, `strace` showed that codex-cli 0.156.1 runs `/usr/bin/bwrap`, not the `bwrap`
copy in `codex-resources/`. Issue #41 reports the same.

On Ubuntu 24.04, `apt install apparmor-profiles` does not enable this profile. The package
puts it in `/usr/share/apparmor/extra-profiles/`. The AppArmor service loads the profiles
in `/etc/apparmor.d/`, not the profiles in `extra-profiles/`. The package also adds other
profiles to `/etc/apparmor.d/`. The steps below install and load only this one profile.

These steps fixed an Ubuntu 24.04.5 host with `apparmor-profiles`
`4.0.1really4.0.1-0ubuntu0.24.04.8`. They are written here with long options, in a temporary
directory. Each command runs only if the command before it worked. If a command fails, the
block stops with that error and keeps the temporary directory, so you can examine it.

1. If `/etc/apparmor.d/bwrap-userns-restrict` does not exist, install it:

   ```bash
   (
     work="$(mktemp --directory)" &&
     cd "$work" &&
     apt-get download apparmor-profiles &&
     dpkg --extract apparmor-profiles_*.deb pkg &&
     sudo install --mode=644 pkg/usr/share/apparmor/extra-profiles/bwrap-userns-restrict /etc/apparmor.d/bwrap-userns-restrict &&
     rm --recursive --force "$work"
   )
   ```

2. Load the profile. Do this step also when the file was already there:

   ```bash
   sudo apparmor_parser --replace /etc/apparmor.d/bwrap-userns-restrict
   ```

3. If `~/.codex/config.toml` has `use_legacy_landlock` under `[features]`, remove that
   line (see option 2).

Note: the header of the profile names `aa-enforce` as the way to enable it. `aa-enforce` is
in the `apparmor-utils` package. This path was not tested.

Verify:

```bash
bwrap --ro-bind / / --unshare-user --unshare-net --dev /dev echo OK   # prints OK
scripts/sandbox-preflight.sh                     # in the skill directory; prints usable
codex sandbox -- echo inside-sandbox             # prints inside-sandbox
codex sandbox -- touch /etc/codex-write-test     # fails: Read-only file system
```

## 2. `features.use_legacy_landlock=true` (does not work in codex-cli 0.156.1)

Do not use this option. In codex-cli 0.156.1, the Linux sandbox stops with a panic when
it runs a command with this setting:

```
thread 'main' (<id>) panicked at linux-sandbox/src/linux_run_main.rs:410:9:
filesystem-restricted execution requires bubblewrap to isolate app-server sockets
```

`codex sandbox` and `codex exec` both give this panic. The setting does not replace bwrap
any more: Codex asks for bubblewrap. If `~/.codex/config.toml` has `use_legacy_landlock`
under `[features]`, remove that line. Then use option 1.

## 3. Hand-rolled `/etc/apparmor.d/bwrap` (inferior to `bwrap-userns-restrict`)

Works, but is the **least strict** variant. This profile puts no limit on the children
of bwrap. `bwrap-userns-restrict` takes all capabilities from them (see option 1). Use this
option only if option 1 is unavailable.

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
sudo apparmor_parser --replace /etc/apparmor.d/bwrap
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
  | codex exec --sandbox read-only -        # produces a real review with no native sandbox
```
