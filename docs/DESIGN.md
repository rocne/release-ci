# release-ci — design and plan of record

Status: **proposal, for review.** Last revised 2026-07-16.

---

## 0. For reviewers

**What this is**: release-ci is a reusable GitHub Actions release pipeline for four small
Go CLI tools in one personal GitHub account. This document is the whole plan — what we
build, what we refuse, and why — resolved to the point where work could start.

**What we want from review**: adversarial reading of §7's decisions. Specifically:

| where we're least confident | why it matters |
|---|---|
| **D6 — "config block, not a generator"** (§6.3) | The load-bearing bet. GoReleaser's own installer *generator* died partly because its author doubted the approach; we claim our shape dodges that objection. If we're wrong, we rebuild a dead thing |
| **D16 — presence-check semantics** (§6.5) | Two credible sources contradict each other (dstow's design says wider-PATH; mise's installer deliberately does the opposite and documents why). We propose doing both. Novel = suspicious |
| **D24 — decline #6 (mise in CI)** | We killed a work item on a chain of reasoning. Chains break |
| **Scale sanity generally** | 4 repos, 1 maintainer, ~110 releases total. Several proposals here (propagation robots, container test matrices, hash-pinned requirements) may be ceremony. **We would rather be told to do less** |

**What is settled and why** — please don't re-litigate without new evidence; each was
checked against primary sources this week, and the checks are in
[`reference/findings-2026-07-16.md`](reference/findings-2026-07-16.md):

- Build the installer rather than adopt one (§6.1) — every alternative fails a concrete test.
- Vendoring as the delivery model (§6.2).
- The install dir is tunable (D9) — dstow's design says otherwise; both shipped scripts already contradict it.

**Known bias to correct for**: this document was largely produced by an AI agent working
with the maintainer, and it is long for the size of the problem. Where it reads as
over-engineered, it probably is.

---

## 1. What release-ci is

A reusable workflow. Consumers call `.github/workflows/release.yml` via `workflow_call`
with `secrets: inherit`.

**The division of labour**: callers decide **when** to release and at **what version**;
release-ci defines **how** — build, sign, publish, verify. That line is the whole design.

Current surface: GoReleaser build → SLSA attestation → cosign/Fulcio verify → Cloudsmith
apt/dnf install smoke → optional caller e2e.

**Consumers**, verified 2026-07-16:

| repo | wired | releases cut | `install.sh` |
|---|---|---|---|
| dot-dagger | yes | 100 (v0.11.0) | yes |
| gostow | yes | 5 (v0.4.0) | yes |
| hud | yes | **0 — never released** | no |
| dstow | yes | 0 (pre-release) | not yet |
| sorta | **no** — releases by other means | 2 | no |

All 8 workflow references pin `@v0.1.1` — release-ci's **only tag, cut by hand**. There is
no release-please config here. **Tag discipline is untested, not proven** (Q12).

## 2. Authority: consumer requirements are inputs, not mandates

**release-ci owns its own design.** A consumer's requirement — however formally recorded in
that consumer's design docs — is an *input*, never a mandate.

**When we decline, we owe a counter-offer**: *no — here is what we will provide instead,
here is how to use it, and here is why it is better.* A bare "no" is a failure of this
design; so is silent compliance with an ask we think is wrong.

**Corollaries:**

- **Incumbency is not an argument.** "gostow already does it this way" is evidence about
  what works, never a reason by itself.
- **Downstream deadlines are not our constraints.** dstow declares its first release blocks
  on #1 with "no fallback design." Honoured — but a downstream repo unilaterally declaring
  an unfallbacked dependency **must not become schedule pressure to ship a design we would
  otherwise refuse.** The counter-offer exists: dstow ships an interim installer and vendors
  ours later.
- **Consumers are protected by the floor (§3), not by a veto.**

**Worked example** (D9): dstow's B6 demanded a non-overridable `~/.local/bin`. Declined;
counter-offered a *stable default* plus an override — strictly more than asked, breaking
nothing.

## 3. The floor and the opt-out — a load-bearing pair

**The floor**: the behavioural contract release-ci guarantees. The pipeline may grow
anything *above* it freely; consumers depend on nothing above it.

**The opt-out**: every feature must be independently declinable, with omission as clean
absence — **never a stub**.

**Neither works alone.** Unconstrained growth is safe *only because* consumers can decline
what grows; growth plus no opt-out is breakage on a delay.

Precedent already correct: `e2e_script` defaults to empty and skips (`release.yml:44-48`);
gostow's `--bin-only` declines man/completions with no stub.

Consequence for #3: an element absorbable **only by being mandatory** demotes from *should*
to *can*.

## 4. Evidence base

[`reference/`](reference/) — three external surveys plus
[`findings-2026-07-16.md`](reference/findings-2026-07-16.md), which records what we verified
ourselves. Every claim there is tagged VERIFIED / SOURCED / INFERRED.

**Standing hazard**: three documents in this org have asserted cross-repo
"identical / both / all" claims that failed inspection — including a sibling survey cited
as prior art by three of our issues, and one survey we commissioned ourselves. **Verify
before citing.** Structural descriptions have held up; cross-repo comparative claims have
not.

## 5. Plan of record

| # | work | state |
|---|---|---|
| **#4** | Pin the Cloudsmith CLI with hashes | **First.** Live hole in the job holding the signing key. Hours |
| **#1** | Canonical `install.sh` | **The main event.** Research complete; Q1/Q2 now resolved (D16/D17). dstow blocks on it |
| **#8** | Pre-1.0 downshift convention | Cheap, unblocked, and now **evidence-backed** (D19). One line × 3 repos |
| **#7** | Endorse mise as an install channel | Cheap, verified working. A README stanza |
| **#3** | Adoption audit | The big one. Gates #2 |
| **#2** | Version guard as input | Behind #3. Likely *can-but-shouldn't* |
| ~~#6~~ | ~~mise in CI~~ | **Propose: decline** (D24). Its case collapsed once Go was excluded |

## 6. `install.sh` — the design (#1)

### 6.1 Why we build rather than adopt

**godownloader** — GoReleaser's own generator, producing `install.sh` *from* a
`.goreleaser.yml`, i.e. almost exactly this ask — is archived (2022-01-14), no successor
named. Its author [doubted the approach](https://github.com/goreleaser/godownloader/issues/161),
not just the maintenance burden. The successor he floated
([goreleaser#4565](https://github.com/goreleaser/goreleaser/issues/4565)) has been **open
since 2024**; go-task's maintainer, 2025: *"We still rely heavily on godownloader for Task,
despite being deprecated."* The ecosystem **froze rather than migrated**.

Every alternative fails a concrete test: `dist` regenerates per release rather than
vendoring a stable file and has no presence-check/`--force`/`--version`; instl.sh, webi and
goblin.run each need **a third party reachable at install time** (goblin.run *recompiles our
source on its servers*, defeating the signing chain); ubi/aqua/binenv/cargo-binstall all
need a manager installed first, so none serve the fresh-machine case.

Nothing surveyed combines presence-check + `--force` + `--version` + a stable vendored file
+ no install-time third party.

### 6.2 Delivery: vendoring

Authored here, vendored to each consumer's repo root, served from that consumer's own
raw-on-`main` URL (`raw.githubusercontent.com/rocne/<repo>/main/install.sh`).

Rationale: one hop; one whitelist-obvious URL on the product repo; audit-in-context;
survives the eventual org migration; vendored updates transit each consumer's own PR review
+ shellcheck CI rather than bypassing release gates.

### 6.3 Parameterization: a config block, not a generator

⚠️ **The design's sharpest question.** "Baked at vendor time" + "propagate to 4 repos"
implies *something* does the baking — and what died was a *generator*.

**One real script with a config block at the top:**

```sh
# ---- vendored config (per-consumer; everything below is canonical) ----
TOOL=""                 # binary name = repo slug under github.com/rocne/. Set at vendor time.
INSTALL_MAN=0           # 1 for consumers shipping a man page + completions
# ---- end vendored config ----
```

- **It is a working script, not a template.** No render step, no placeholder syntax.
  **Correction to an earlier draft**: that draft claimed the canonical copy runs "with
  release-ci's own values" — **wrong, release-ci ships no binary**. The canonical copy has
  `TOOL=""` and **aborts with a usage error** (*"install.sh: TOOL is unset — this is the
  canonical source; vendor it and set TOOL in the config block"*). That keeps it a real,
  shellcheck-able, *executable* script that fails cleanly, rather than a template with
  placeholders. Tests set `TOOL=gostow`.
- **Vendoring** = copy the file, set the block. **Propagation** = replace everything *below*
  the block, preserve the block. A `sed`/`awk` range operation — not a generator, and it
  cannot drift into one.
- **Why this survives caarlos0's objection**: he doubted deriving installers *from build
  config* — a generator with a config language, a template engine, and a compatibility
  surface across every GoReleaser feature. We have one file and a copy step.

**The rule that keeps it honest**: consumer-specific behaviour must be expressible as
**variables in the config block**, never as template branches. If a consumer needs something
the block can't express, that is a signal to **say no** (§2), not to add a template engine.

### 6.4 The floor

| # | rule |
|---|---|
| **F1** | **Presence check** → if already installed and no overriding flag: one status line, **exit 0**. Semantics in D16 |
| **F2** | `--force` reinstalls; `--version vX.Y.Z` installs that version and **implies force**. **No self-update** — package managers and mise own upgrades |
| **F3** | **Install dir default resolves to `~/.local/bin`** on a machine that hasn't opted out. Consumer rc snippets may rely on it |
| **F4** | **Checksum mandatory** — no `sha256sum`/`shasum` is a hard abort |
| **F5** | **Cosign opportunistic** — verify iff present, else one notice and proceed. Requiring it would fail bootstrap on exactly the fresh machines bootstrap serves |
| **F6** | **Exit code is unconditional and level-independent**; the *message* is a function of verbosity. A no-op under `--silent` still exits 0; a failure under `--silent` still exits non-zero |

Consumers depend on **nothing** beyond F1–F6.

### 6.5 Resolved behaviour

**Presence check (D16)** — check **both**, install path first:

1. **Resolved install path first.** If `$INSTALL_DIR/$TOOL` exists (and matches `--version`
   if given) → status line, exit 0.
   *Why first*: it **converges**. Checking only the wider PATH means a custom install dir
   that isn't on `PATH` reinstalls **forever**, never satisfying its own check.
2. **Then `command -v $TOOL`.** If found elsewhere — e.g. `/usr/bin/$TOOL` from apt — →
   status line naming the location, exit 0. **Do not silently shadow a package-managed
   install.** `--force` installs anyway.

Each check alone fails: wider-PATH-only never converges; install-path-only silently
installs a second copy alongside an apt-managed one. **This is the counter-offer to dstow's
B6**: it asked for `command -v`; it gets `command -v` **plus** convergence. It also
reconciles mise, which deliberately checks only the install path *"so that skipping never
leaves install_path missing"* (`mise.run:286-288`) — a real concern, and step 1 is exactly
it.

**Install directory** — precedence, highest first:

| | source | note |
|---|---|---|
| 1 | `--dir <path>` | flag name **matches both shipped scripts**; do not "improve" it |
| 2 | `<TOOL>_INSTALL_DIR` | namespaced, baked with the slug. **No surveyed installer exposes a bare one** |
| 3 | `INSTALL_DIR` | **deprecated fallback**; warn on use (D21) |
| 4 | `$XDG_BIN_HOME` | follows **uv specifically** (1 of 15 surveyed), not a broad norm |
| 5 | `~/.local/bin` | default (F3) |

**Output levels** — settable by flag or env (`curl \| sh` can't pass flags):

| level | flag | emits |
|---|---|---|
| verbose | `-v`, `--verbose` | everything, with detail |
| normal | *(default)* | success announced, failures, no-op status line |
| quiet | `-q`, `--quiet` | failures and changes only — a no-op says nothing |
| silent | `--silent` | nothing but a catastrophic abort |

Announcement matrix, **at default level**:

| invocation | tool present | tool absent |
|---|---|---|
| rc snippet | *(snippet guard short-circuits; installer never runs)* | installs and **announces** |
| direct `curl \| sh` | one status line, exit 0 | installs and **announces** |

**Conventions**: all human output → **stderr** at every level. Exit 0 success/no-op, 1
runtime, 2 usage. Errors carry `error:` + `hint:`. `NO_COLOR` honoured; TTY check before
colour/progress.

### 6.6 Above the floor

Free to grow, consumers depend on none of it: `--require-signature` (strict cosign; the
opportunistic default stays), man/completions install, `--os`/`--arch`, `--dry-run`,
`--help`, upgrade hints, the output levels themselves.

`--help` prints the script's own comment header (`sed -n '2,23p' "$0" | sed 's/^# \?//'`) —
a good idiom in both shipped scripts.

**Man/completions (D20)**: `INSTALL_MAN` in the config block sets the **vendor-time
default** (gostow `1`, dot-dagger `0`); `--bin-only` **overrides at runtime**. Config sets
the default; the flag overrides it. Both, and they are consistent.

### 6.7 What we drop

- **dot-dagger's `VALID_TOOLS` positional** — an optional tool name validated against a
  one-entry list. Dead generality; baked-slug is gostow's shape and it's right.
- **`printf '%q'`** (`dot-dagger/install.sh:61`) — **not POSIX**; misbehaves under `dash`,
  which is exactly what `curl … | sh` invokes. A latent bug on the error path.
- **`--update`** — dropped with F2.

### 6.8 Honest positioning

Three choices are **defensible minority positions, not conventions**. The script's comments
should say so:

1. **Presence-checking at all** — 5 of 15 surveyed installers do it.
2. **Fully-silent presence-exit is attested nowhere** — every checking installer speaks. Our
   "speaks, exit 0" is *vindicated*; `--silent` is our own extension.
3. **`~/.local/bin`** — 2 of 15. Most use a tool-specific dir.

### 6.9 Scope, defended

mise (#7) and package managers own version management and upgrades. **`install.sh` does one
thing: put a verified binary on a bare machine.** That is the counter-offer to any ask that
it grow. mise does not reduce this scope — mise is itself a binary something must install,
so on a fresh machine there is no mise either.

### 6.10 Testing (D17)

The floor is executable; test it directly.

- **Harness**: `bats-core`, run in release-ci's own CI. The script is authored here, so it
  is tested here — consumers' shellcheck is a review gate, not the test suite.
- **Shells**: run the whole suite under **`bash` and `dash`**. Non-negotiable: the `%q` bug
  we're dropping is exactly this class, and `curl … | sh` is `dash` on Debian/Ubuntu.
- **Lint**: `shellcheck` in CI, matching what consumers run on the vendored copy.
- **Matrix** — the floor, enumerated:
  `{absent, present-at-install-path, present-on-PATH-elsewhere}` × `{default, quiet, silent, verbose}` × `{none, --force, --version}`.
  Assert on **exit code**, **which stream** output went to, and **whether an install
  actually happened** — F6 means these are independent and must be asserted independently.
- **Fixture**: a real published release (gostow v0.4.0) — real assets, real checksums, real
  cosign signatures. No mocked release server.
- **Containers**: reuse the existing `smoke_distros` idea (ubuntu:24.04, fedora:41) for
  end-to-end installs only, not for the matrix above.

**Reviewer check**: this may be too much for a ~200-line script. The parts we'd defend
hardest are dash+bash and the exit-code/stream/effect split; the container matrix is the
first thing to cut.

## 7. Decision register

### 7.1 Decided

| # | decision |
|---|---|
| **D1** | Consumer requirements are inputs, not mandates; declining owes a counter-offer (§2) |
| **D2** | Incumbency is not an argument; preserving the current system is not a priority |
| **D3** | The floor and the opt-out are a load-bearing pair; mandatory-only ⇒ demote to *can* |
| **D4** | Build `install.sh`; adopt nothing (§6.1) |
| **D5** | Deliver by vendoring, from each consumer's own raw-on-`main` URL |
| **D6** | Parameterize via a **config block in a real script**; never a generator or template engine (§6.3) |
| **D7** | The floor is F1–F6 (§6.4) |
| **D8** | Install-dir env var is **namespaced** (`<TOOL>_INSTALL_DIR`); bare `INSTALL_DIR` deprecated |
| **D9** | Install dir is **tunable**; the *default* is contractual — declines dstow B6 with a counter-offer |
| **D10** | Four output levels; all human output to stderr; exit code independent of level |
| **D11** | `--dir` keeps its name |
| **D12** | Drop `VALID_TOOLS` positional, `printf '%q'`, `--update` |
| **D13** | mise is an **additional channel** (`github` backend), not a replacement; `go` backend never |
| **D14** | Verify before citing; dstow's installer survey is unreliable prior art |
| **D15** | Sequence per §5; #4 first; #1 not gated on #3 |
| **D16** | **Presence check = both, install path first, then `command -v`** (§6.5). Resolves Q1 |
| **D17** | **Testing = bats-core under bash *and* dash, real-release fixture, floor matrix** (§6.10). Resolves Q2 |
| **D18** | **#4 = pin with `--require-hashes` + compiled requirements now.** The `curl`-the-API option is real but not free — Cloudsmith's upload is **two-step** (PUT → identifier → POST with deb/rpm params), so we'd own ~15 lines of bash + `jq`. **Evaluate separately; do not block the fix.** Resolves Q5 |
| **D19** | **Adopt the downshift — it is established practice, not our invention** (below). Resolves Q6 |
| **D20** | Man/completions: `INSTALL_MAN` sets the vendor-time default, `--bin-only` overrides at runtime. Resolves Q7 |
| **D21** | Bare `INSTALL_DIR` warns from day one; **dropped when all consumers are on the canonical script** — a trigger, not "someday". Resolves Q9 |
| **D22** | `install.sh` lives at **`installer/install.sh`** here — not repo root, which would imply release-ci installs something. Canonical copy has `TOOL=""` and aborts with a usage error. Resolves Q10 |
| **D23** | **Go stays on `actions/setup-go`** — mise's `core:go` cannot read `go.mod` (below). Resolves Q11 |
| **D24** | **Propose declining #6** (mise in CI) — its case collapsed once Go was excluded (below) |

**D19 — the downshift is established practice.** The convention: major pinned at 0,
breaking → **minor**, feature → **patch**. **This is not ours.** VERIFIED from primary
sources:

- **Cargo**: `^0.2.3 := >=0.2.3, <0.3.0` and `^0.0.3 := >=0.0.3, <0.0.4`. Its rule:
  *"Versions are considered compatible if their left-most non-zero major/minor/patch
  component is the same. This is different from SemVer which considers all pre-1.0.0
  packages to be incompatible."*
- **npm/node-semver**: `^0.2.3 := >=0.2.3 <0.3.0-0`, with the rationale stated outright:
  *"Many authors treat a `0.x` version as if the `x` were the major 'breaking-change'
  indicator."*

So across two major ecosystems, **for 0.x the minor is the breaking axis and the patch
carries everything else** — exactly the downshift. Our current config
(`bump-patch-for-minor-pre-major: false`) makes every `feat` bump the minor, which under
those semantics **signals a breaking change for every feature**. We are crying wolf, and
`^0.4.0` consumers get needlessly excluded.

**Honest caveat**: Go has no caret ranges, and semver.org itself says 0.x means *"anything
MAY change at any time"*. So this is a **refinement codified by Cargo and npm**, not a
universal law. But it is the only established convention that gives 0.x meaningful
granularity, and it is what a large share of developers already assume. #8 should cite
Cargo/npm rather than present it as a local idea.

**D23 — mise cannot read `go.mod`.** VERIFIED empirically: with `go.mod` declaring
`go 1.24.4` and `mise.toml` declaring `go = "prefix:1.24"`, mise resolved **1.24.13** — the
latest 1.24.x, ignoring `go.mod`. mise's docs confirm it reads `.go-version`, not `go.mod`.

This is decisive because **release-ci is a reusable workflow**: four consumers, four
different `go.mod` files. `actions/setup-go` with `go-version-file: go.mod` reads *the
caller's* `go.mod` at checkout. A `mise.toml` here cannot vary per consumer; a `mise.toml`
per consumer duplicates `go.mod` and invites drift. Either way the "one source of truth"
pitch is lost — `go.mod` **is** the source of truth, and mise can't read it.

**D24 — decline #6.** With Go excluded (D23), what remains for mise-in-CI is:

| tool | status without mise | does mise improve it? |
|---|---|---|
| Go | pinned by caller's `go.mod` | **No** — can't read it (D23) |
| cosign | pinned by `cosign-installer@v3`'s `v3.0.6` default | No |
| GoReleaser | floats `~> v2` | Marginally — but `version: v2.x.y` in the action pins it exactly, for free |
| cloudsmith-cli | unpinned (#4) | **No** — mise's `pipx` backend is **version-only**, no checksum/provenance. Same as an `==` pin, which doesn't fix it either (D18) |

So mise-in-CI buys: an exact GoReleaser pin **achievable without it**, plus
`minimum_release_age` (24h quarantine — genuinely mise-only), plus consolidation into one
file. Against that: a third-party action, mise's own binary, and — the pointed one —
**mise's Rust reimplementation of cosign/SLSA verification** instead of the upstream
binaries security researchers audit. For a pipeline whose entire product is provenance,
that trade is bad at this price.

**Counter-offer**: pin GoReleaser exactly in the action, hash-pin cloudsmith-cli (#4).
That captures most of the benefit with none of the surface. **Revisit if** we adopt many
more tools, or if `minimum_release_age` becomes a requirement on its own.

### 7.2 Still open

| # | question | recommendation | blocks |
|---|---|---|---|
| **Q3** | **Propagation mechanism.** How do installer changes reach 4 consumer repos? | **Do it manually; don't build the robot.** 4 repos, low change rate. Automation needs a cross-repo PAT — a new supply-chain surface **in the repo that holds the signing keys**, to save 4 copy-pastes a year. Revisit at >6 consumers or the first missed propagation | #1 (may split) |
| **Q4** | **The rc snippet has no owner.** dstow's snippet hardcodes `~/.local/bin`, coupling it to our F3 across a repo boundary with **no shared test** | release-ci documents **F3 as the contract**; consumers own emission. No cross-repo test is feasible, so **accept and document the coupling**: an F3 change is a coordinated, cross-repo change. Really a #3 ownership question | #1, #3 |
| **Q8** | **Does hud get an installer?** | **Ask hud's owner.** Moot until hud releases anything — it has 0 releases, so its missing `install.sh` is *not yet*, not *declined*. Do not infer intent from an absent file | #1 (census), #3 |
| **Q12** | **Tag discipline / blast radius.** All 4 consumers pin `@v0.1.1`, the only tag ever cut, by hand, with no release-please here | #3's to answer. Note the reflexive gap: **if D19's convention is org-wide, release-ci should follow it too — and release-ci has no release-please config at all.** Possibly its own issue | #3, #2 |

### 7.3 Deliberately not decided here

- **Everything #3 exists to decide** — the can/should/shouldn't verdicts per element. #3 is
  the mechanism, not a gap.
- **#2's fate** — likely *can-but-shouldn't*; #3 rules.

## 8. Known risks

1. **D6 is the load-bearing bet.** If consumer needs outgrow the config block, the pressure
   will be to add a template engine — godownloader's road. §6.3's rule (say no) only holds
   if someone enforces it.
2. **Q4's cross-repo coupling is invisible.** dstow's rc snippet hardcodes our F3 default.
   No test spans that boundary; nothing here can detect a break.
3. **hud is an untested integration presented as a consumer.** Its root-level
   `.goreleaser.yaml` — the layout constraining #3's absorption designs — **has never been
   run by release-ci**.
4. **The prior art is unreliable** (§4). Three documents in this org have made cross-repo
   claims that failed inspection.
5. **This plan may be too large for the problem.** Four repos, one maintainer, one tool that
   has ever released more than five times. §0 asks reviewers to cut rather than add.
