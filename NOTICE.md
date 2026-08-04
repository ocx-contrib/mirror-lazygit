# NOTICE

This repository packages and redistributes upstream software published by the
[lazygit](https://github.com/jesseduffield/lazygit) project. The Apache-2.0
license in [`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It
does **not** cover any upstream-derived asset — the redistributed bytes carry
their own license, recorded below.

The package logo is an **original mark authored for this repository**, not an
upstream asset: lazygit publishes no logo, and a full-tree listing of
`jesseduffield/lazygit@master` returns no `.svg` and no raster image anywhere
in the repository. It is a plain geometric commit-graph glyph used for catalog
identification only. No endorsement is implied, and no trademark claim is made.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `lazygit` | `ghcr.io/ocx-contrib/lazygit/lazygit` | `MIT` |

---

## `lazygit`

Upstream: <https://github.com/jesseduffield/lazygit>
Published to `ghcr.io/ocx-contrib/lazygit/lazygit`.

| Component | SPDX | Holder |
|---|---|---|
| lazygit | **MIT** | Copyright (c) 2018 Jesse Duffield |

Verified at the Phase 1.5 license gate:

```
$ gh api repos/jesseduffield/lazygit/license --jq '{spdx: .license.spdx_id, name: .license.name}'
{"name":"MIT License","spdx":"MIT"}
```

MIT is permissive and grants redistribution of the compiled binary subject to
its notice-retention condition. That condition is met at two levels: every
upstream release archive **carries its own `LICENSE` file alongside the
binary**, and this mirror republishes the archive contents unaltered, so the
notice travels inside the bundle exactly as upstream shipped it. The canonical
text is
<https://github.com/jesseduffield/lazygit/blob/master/LICENSE>, and every
published manifest carries an `org.opencontainers.image.source` annotation
pointing at this repository alongside `org.opencontainers.image.licenses: MIT`.

The published binaries are statically linked Go builds that vendor third-party
modules under permissive licenses, enumerated in the `go.mod` / `go.sum` of the
tagged upstream source for each mirrored version.

No modifications are made to any upstream artifact in this repository; the
archive contents (`lazygit` or `lazygit.exe`, `LICENSE`, `README.md`) are
republished byte-for-byte inside an OCX bundle.

`git` itself is **not** redistributed here. lazygit is a front end that
requires git on the host's `PATH`; nothing in this package supplies it.
