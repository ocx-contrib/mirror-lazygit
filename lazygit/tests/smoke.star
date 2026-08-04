# lazygit/tests/smoke.star — stable across upstream lazygit releases.
#
# Asserts the contract (exit codes, version SHAPE, the platform the binary was
# BUILT for, the structure of a config document it serialized, and an env
# redirect it honoured), never help/version prose.
#
# ─── WHY THIS TEST IS SHAPED THE WAY IT IS: lazygit IS A TUI ────────────────
#
# lazygit's whole product is a full-screen terminal UI. Reaching terminal init
# inside `ocx package test` is not a slow test, it is a HUNG WINDOWS LEG — the
# process waits on a console that the runner never hands it. Measured, in a
# non-tty container, on a directory that IS a git repository:
#
#   $ lazygit --path /tmp/repo
#   *fs.PathError open /dev/tty: no such device or address     exit=1
#
# On Linux that fails fast; a Windows runner is where it stalls. So EVERY verb
# below is one of the four lazygit exits WITHOUT opening the alternate screen:
# `--version`, `--config`, `--print-config-dir`, and flag-parse failure. No
# assertion here ever hands lazygit a real repository, and none needs to.
#
#   Deliberately NOT used for the "TUI never opened" proof: a bogus repo path
#   (`--path <non-repo>`). It does exit 1 with empty stdout today (measured),
#   but it is a REPO-RESOLUTION path — one upstream change to lazygit's
#   `notARepository` handling turns it into a prompt, i.e. into terminal init,
#   i.e. into a hung Windows leg. The unknown-flag form below fails inside
#   ARGUMENT PARSING, which provably runs before any UI code on every platform.
#
# ─── WHY NO `git` IS NEEDED, AND WHY THAT IS NOT A CONTRADICTION ────────────
#
# lazygit drives git, so the fleet reflex is to install git on every Linux
# container leg (prek, lefthook). Measured in a STOCK alpine:3.20 with no git:
# all four verbs below exit exactly as they do with git present. `--version`
# does shell out to git, but tolerates its absence — it just prints an empty
# `git version=` field, which is why nothing below asserts on that field. The
# git-dependent lazygit paths all open the UI, so there is nothing a `git`
# install would let this test reach. See ../../mirror-base.yml.

LAZYGIT = "lazygit.exe" if ocx.target_platform.os == ocx.os.Windows else "lazygit"

# A token that exists nowhere in lazygit's real config-dir default
# (`~/.config/lazygit`, `~/Library/Application Support/lazygit`,
# `%APPDATA%\lazygit`). Only an honoured redirect can put it on stdout.
CFG_TOKEN = "ocx-smoke-lazygit-cfg-9F3A"

# ─── Tier 1 + 2: liveness on the composed PATH + version SHAPE ──────────────
#
# The digits are the contract; the banner around them is not. lazygit prints
# `…, version=0.63.1, os=linux, arch=amd64, git version=2.54.0` — note that
# `version=` occurs TWICE, so the regex is anchored to the field separator to
# pin lazygit's own version and not git's. An `expect.eq` on the whole line
# would break on every release; an `expect.contains(stdout, "lazygit")` would
# break on a rebrand.
r_version = ocx.run(LAZYGIT, "--version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"(?:^|, )version=\d+\.\d+\.\d+\b")

# ─── Tier 2b: the bundle holds the binary for THE PLATFORM IT CLAIMS ────────
#
# This is the assertion the asset-regex gate cannot make from outside. lazygit
# reports Go's own `runtime.GOOS`/`GOARCH`, whose spellings are exactly the OCI
# strings `ocx.target_platform` yields — so a spec whose regex shipped, say,
# the freebsd or 32-bit asset into a linux/amd64 bundle would red HERE, at the
# only point where the artifact and the claim about it are both in hand.
expect.contains(r_version.stdout, "os=" + str(ocx.target_platform.os))
expect.contains(r_version.stdout, "arch=" + str(ocx.target_platform.arch))

# ─── Tier 3a: `--config` serializes a real config document ──────────────────
#
# `--config` prints lazygit's DEFAULT configuration — 343 lines of YAML at
# 0.63.1, 331 at 0.62.2 — walked out of its own config struct. Verified it is a
# pure dump: a user config placed in CONFIG_DIR changes neither the output nor
# the exit code, so nothing here depends on ambient state.
#
# The assertions are STRUCTURAL, not textual: three top-level mapping keys at
# column 0. `(?m)` makes `^`/`$` line-anchored in the Rust regex crate, so each
# one matches only an actual top-level key — a nested `git:` indented under
# `gui:` would not satisfy it. Present exactly once each in both 0.62.2 and
# 0.63.1. No multi-word substring is asserted anywhere: lazygit colourises, and
# SGR lands per token.
r_config = ocx.run(LAZYGIT, "--config")
expect.ok(r_config)
expect.matches(r_config.stdout, r"(?m)^gui:$")
expect.matches(r_config.stdout, r"(?m)^git:$")
expect.matches(r_config.stdout, r"(?m)^keybinding:$")
# A truncated or wrong-flavour archive that still ran would plausibly emit a
# few lines; the real document is two orders of magnitude bigger.
expect.true(len(r_config.stdout.split("\n")) > 100)

# ─── Tier 3b: the CONFIG_DIR env redirect is honoured ───────────────────────
#
# lazygit's OWN env var, not XDG_CONFIG_HOME — Windows remaps XDG and would
# make this platform-dependent. `ocx.run(env=…)` is an overlay on the composed
# bundle env, so PATH survives. The assertion is on the TOKEN, never on the
# full path: Windows normalises separators, and the token is the only part
# that proves the redirect took effect. If lazygit ignored the var it would
# print its platform default, which cannot contain this token — that is the
# red this assertion is able to reach.
#
# Nothing is asserted about a FILE here because lazygit creates none: measured,
# `CONFIG_DIR=<fresh dir> lazygit --config` leaves that directory non-existent.
CFG_DIR = ocx.scratch_root + "/" + CFG_TOKEN
r_cfgdir = ocx.run(LAZYGIT, "--print-config-dir", env = {"CONFIG_DIR": CFG_DIR})
expect.ok(r_cfgdir)
expect.contains(r_cfgdir.stdout, CFG_TOKEN)

# ─── Tier 3c: NEGATIVE CONTROL, and the proof the TUI never opened ──────────
#
# Two jobs in one call, both mandatory.
#
#   (1) Negative control. Every assertion above is satisfiable by a binary that
#       prints things and always succeeds. This one is not: an unknown flag
#       must be REJECTED. Measured at 2 on both 0.62.2 and 0.63.1 — asserted as
#       a specific code rather than "non-zero", because a range of tolerated
#       exit codes is not a check.
#
#   (2) The alternate screen announces itself with a CSI burst on stdout, so an
#       EMPTY stdout is positive evidence that terminal init was never reached.
#       Argument parsing runs before any UI code on every platform, which is
#       why this call — and not a repo-resolution one — carries the proof.
#       Measured: exit 2, stdout 0 bytes, usage text on STDERR.
r_bad = ocx.run(LAZYGIT, "--ocx-smoke-not-a-flag")
expect.eq(r_bad.exit_code, 2)
expect.eq(r_bad.stdout, "")

# No Tier 4: metadata.json declares PATH only (proven by the Tier 1 liveness
# call resolving `lazygit` off the composed PATH).
