# mirror-lazygit

OCX mirror for [lazygit](https://github.com/jesseduffield/lazygit), a terminal
UI for git. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [lazygit](https://github.com/jesseduffield/lazygit) | [`lazygit/mirror.yml`](lazygit/mirror.yml) | `ghcr.io/ocx-contrib/lazygit/lazygit` | [`ocx.sh/lazygit/lazygit`](https://index.ocx.sh/lazygit/lazygit) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`jesseduffield` is a personal handle rather than a vendor, so the tool names
itself: the package is `lazygit/lazygit`. Provenance is not lost by that — it
is recorded verifiably in the index claim's `upstream` block.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
lazygit/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
path filter and would never trigger a describe run.

## Toolchain

`ocx.toml` pins the **floating minor** of the prod toolchain
(`ocx.sh/ocx/cli:0.5`, `ocx.sh/ocx/mirror:0.5`); the concrete digests live in
`ocx.lock`. `direnv allow` once to put them on `PATH`, then invoke
`ocx-mirror` **directly** — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

```sh
direnv allow
ocx update                      # re-resolve the floating tags
grep lock_version ocx.lock      # must be 3
```

## Editing

Everything in `.github/workflows/` is **generated**. Never hand-edit it — the
`verify-generated.yml` drift guard fails CI at exit 65 on any change. Edit the
spec (or the renderer template), then regenerate, **naming every spec** —
`--spec` appends rather than replaces, so a command naming a subset silently
stops rendering the rest while staying green:

```sh
ocx-mirror package validate lazygit/mirror.yml
ocx-mirror package pipeline generate ci --spec lazygit/mirror.yml
ocx-mirror package pipeline generate ci --check --spec lazygit/mirror.yml   # must exit 0
```

`--repo-root` is inferred from the enclosing git repository, so it is never
passed here — and the drift guard bakes in the same inference, which is why a
`generate ci` run from outside a git checkout exits 64.

## Testing the smoke locally before pushing

CI runs the smoke on macOS (10× minutes) and Windows (2×), so a Starlark
dialect error costs a full matrix round trip to find. Run it against a real
native bundle first, **for every in-range version** — a binary's flag surface
can change inside the range even when its asset set does not:

```sh
ocx-mirror package pipeline prepare --spec lazygit/mirror.yml \
  --version 0.63.1 --work-dir "$(mktemp -d)"
# bundle lands at <work-dir>/<V>_<YYYYMMDD>/linux_amd64/ under build_timestamp: date
ocx package test --platform linux/amd64 \
  --identifier ghcr.io/ocx-contrib/lazygit/lazygit:0.63.1 \
  <work-dir>/<V>_<YYYYMMDD>/linux_amd64/bundle.tar.xz \
  --script lazygit/tests/smoke.star
```

**lazygit is a TUI, and that constrains the smoke test.** Reaching terminal
init inside `ocx package test` hangs a Windows leg. Every verb the smoke uses
(`--version`, `--config`, `--print-config-dir`, and a deliberately unknown
flag) exits without opening the alternate screen, and the unknown-flag call
asserts `stdout == ""` as positive evidence that it never did. Do not add an
assertion that hands lazygit a real repository.

## Platform rollout

Platforms are staged to keep macOS and Windows minutes off an unproven layout:
pass 1 linux only, pass 2 darwin, pass 3 windows. Each pass uncomments the
platform key in `mirror-base.yml` **and** its asset regex in
`lazygit/mirror.yml` together — staging `assets:` alone still boots a real
macOS/Windows runner that self-skips per version and reports success having
tested nothing. Uncomment with an editor, never `sed`: the values are regexes,
and backslash is special on `sed`'s replacement side.

## Claim + announce

The index claim (`p/lazygit/lazygit.json` in `ocx-sh/index`) is the one PR in
this workflow; **mirror repos themselves take no PRs — push straight to
`main`**. Order is publish → verify the GHCR package is public → merge the
claim → announce:

```sh
gh workflow run announce-from-registry-lazygit.yml -f dry_run=false
```

An announce before the claim lands fails with `unclaimed namespace`, exit 79 —
expected at that point, not a misconfiguration.
