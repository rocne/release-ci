# release-ci — design and plan of record

Status: **proposal, for review.** Last revised 2026-07-16.

---

## 0. For reviewers

**What this is**: release-ci is a reusable GitHub Actions release pipeline for four small
Go CLI tools in one personal GitHub account. This document is the whole plan — what we
build, what we refuse, and why — resolved to the point where work could start.

**The posture** (§2, and it drives everything): downstream repos are **evidence, not
constraints**. Every consumer is ours; there is no external compatibility surface between
release-ci and them. We change them freely, we reject their declared needs when we see
better, and we try to serve the needs they haven't articulated (§10). If this document reads
as high-handed, that is deliberate — an earlier draft was deferential and it produced worse
decisions, several of which are marked *re-derived* below.

**What we want from review**: adversarial reading of §7's decisions. Specifically:

| where we're least confident | why it matters |
|---|---|
| **D6 — "config block, not a generator"** (§6.3) | The load-bearing bet. GoReleaser's own installer *generator* died partly because its author doubted the approach; we claim our shape dodges that objection. If we're wrong, we rebuild a dead thing |
| **D16 — presence-check semantics** (§6.5) | Two credible sources contradict each other (dstow's design says wider-PATH; mise's installer deliberately does the opposite and documents why). We propose doing both. Novel = suspicious |
| **D24 — decline #6 (mise in CI)** | We killed a work item on a chain of reasoning. Chains break |
| **§2's posture itself** | We claim broad licence to redesign downstream. If that licence is being used to justify churn rather than correctness, say so — D11 (renaming a flag) is the most likely offender |
| **Scale sanity generally** | 4 repos, 1 maintainer, ~110 releases total. Several proposals here (propagation robots, container test matrices, hash-pinned requirements) may be ceremony. **We would rather be told to do less** |

**What is settled and why** — please don't re-litigate without new evidence; each was
checked against primary sources this week, and the checks are in
[`reference/findings-2026-07-16.md`](reference/findings-2026-07-16.md):

- Build the installer rather than adopt one (§6.1) — every alternative fails a concrete test.
- Vendoring as the delivery model (§6.2).
- The install dir is tunable (D9) — dstow's design says otherwise; both shipped scripts already contradict it.

**What changed in this revision**: the posture (§2/§3) was rewritten, and four decisions were
**re-derived** because their reasoning had been *"it's what gostow already does"* — which §2
now rejects outright. D11 and D21 changed answer; D20 and D26 changed shape. §10 is new and
is the point of the whole reframe.

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

## 2. Posture: we design the system; downstream is evidence

release-ci exists to build an **excellent release system** for the tools that ride it.
Downstream repos are **evidence about the problem** — what breaks, what's needed, what's
been tried — and **they are ours to change**. They are not a set of constraints to satisfy.

Every consumer is ours. **There is no external compatibility surface between release-ci and
its consumers.** That fact should be used, not politely ignored.

**Three rules:**

**1. We change downstream freely.** gostow's installer, dot-dagger's argument parser, hud's
GoReleaser layout, dstow's rc snippet — if the right design requires changing them, we
change them. *"It would mean editing gostow"* is a cost to schedule, **never** a reason to
choose a worse design.

**2. We reject declared needs when we see better.** A consumer's requirement — however
formally recorded in that consumer's design doc — is a **hypothesis about what they need**,
and hypotheses can be wrong. dstow's B6 asked for a non-overridable install dir (D9: wrong,
and its own shipped siblings already contradict it). dstow's B6 asked for a `command -v`
presence check (D16: subtly broken — it never converges). A consumer's design doc binds that
consumer. It does not bind us.

**3. We serve needs they haven't articulated.** This is the more important half and where
the value actually is. Consumers ask for what they've *noticed*. An excellent system also
delivers what they'd have asked for had they seen it — see §10, which is the list of things
nobody asked for and everybody needs.

**The counter-offer is the manner, not a negotiation.** When we decline: *no — here is what
we provide instead, here is how to use it, and here is why it is better.* That is an
**obligation to explain**, not a request for consent.

**Corollaries:**

- **Incumbency is not evidence of correctness.** "gostow already does it this way" tells us
  it *works*; it does not tell us it's *right*. `--dir`'s name, `INSTALL_DIR`'s spelling,
  and hud's layout are all up for redesign on the merits, and D11/D21 below were re-derived
  once this was applied properly.
- **Downstream deadlines are not our constraints.** dstow's "first release blocks on #1, no
  fallback design" is dstow's planning choice. Honoured where free; never a reason to ship a
  design we'd otherwise refuse.
- **Uniformity is the default; divergence needs a reason.** Not the other way round.

## 3. The floor exists for users, not consumers

An earlier draft said the floor protects *consumers* from us, and that they are "protected
by the floor, not by a veto." **That was wrong on both halves** — consumers need no
protection from us, because they are ours to change.

**The floor exists because of what we cannot change: artifacts already on a user's
machine.**

An rc snippet in someone's `.bashrc` bakes our install dir and our URL in **permanently**.
A `mise.toml` in a user's repo pins `github:rocne/gostow`. A wiki page, a Dockerfile, a
colleague's muscle memory for `curl -fsSL … | sh`. **None of those transit our PR review.**
dstow#28 got this exactly right: rc files are *"the most durable artifact in the design."*

So the floor is precisely: **the promises that survive contact with a user's machine.**

- **F3's default** (`~/.local/bin`) — because rc snippets hardcode a PATH line against it.
- **The URL shape** — because rc snippets bake it (and see §9: this is why the migration is dangerous).
- **F1's exit-0-when-present** — because the snippet's guard depends on it.
- **The bare invocation** (`curl … | sh`, no args) — because that's what's written down everywhere.

Everything above the floor is ours to change on any Tuesday, in this repo *and* in every
consumer, without asking.

**The opt-out** survives the reframe, but its justification changes: it is not protection,
it is **fitness**. Consumers legitimately differ — hud may genuinely not want an installer —
and a system that forces every feature on every consumer is a worse system. Omission must be
clean absence, **never a stub**.

Precedent already correct: `e2e_script` defaults to empty and skips (`release.yml:44-48`).

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
vendored updates transit each consumer's own PR review + shellcheck CI rather than bypassing
release gates.

⚠️ **Correction**: earlier drafts also claimed vendoring *"survives infra reorgs (relevant
to the planned org migration)"*. **That claim is too broad and is withdrawn.** Vendoring may
survive the *URL* reorg (unverified — it rests on GitHub's transfer redirects), but it does
**not** survive the *signing identity* reorg: the vendored script pins the Fulcio identity to
`rocne/release-ci` and **hard-aborts** when it doesn't match (#11). What vendoring actually
buys is the first three rationales; migration-survival is not one of them. See §9.

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

Each check alone fails: wider-PATH-only **never converges**; install-path-only silently
installs a second copy beside an apt-managed one.

**dstow's B6 asked for `command -v`, and that ask is simply wrong** — not a preference to be
met halfway, but a check that reinstalls forever whenever the install dir isn't on `PATH`.
We reject it and explain why (§2 rule 2). mise gets the other half right, deliberately
checking only the install path *"so that skipping never leaves install_path missing"*
(`mise.run:286-288`) — and gets the apt case wrong in exchange. **Both were solving half.
Step 1 is mise's concern; step 2 is dstow's; neither source proposed both.**

**Install directory** — precedence, highest first:

| | source | note |
|---|---|---|
| 1 | `--install-dir <path>` | **renamed from `--dir`** (D11). Pairs with the env var below; fnm's spelling. Change the two shipped scripts |
| 2 | `<TOOL>_INSTALL_DIR` | namespaced, baked with the slug. **No surveyed installer exposes a bare one** |
| 3 | `$XDG_BIN_HOME` | follows **uv specifically** (1 of 15 surveyed), not a broad norm |
| 4 | `~/.local/bin` | default (F3) |

**Bare `INSTALL_DIR` is gone, not deprecated (D21 — reversed).** The earlier draft kept it as
a "deprecated fallback… breaks nobody," which was deference wearing compatibility's clothes.
It is wrong on its own terms: **the fallback preserves the exact bug it was fallback for.**
We namespace *because* a bare `INSTALL_DIR` in the environment — exported for any unrelated
purpose — is silently absorbed. Honouring it "for continuity" keeps that collision alive
forever. Two repos we own, few users, and the flag is barely documented: **clean break, note
it in the release notes.** Simpler *and* strictly more correct.

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

**Man/completions (D20 — re-derived): detect, don't configure.**

The earlier draft had `INSTALL_MAN` in the config block, set from *"gostow ships them,
dot-dagger doesn't."* That is incumbency again — it encodes today's accident as tomorrow's
configuration.

Re-derived from the actual question — *should a curl-installed tool feel like an
apt-installed one?* **Yes.** apt/dnf/brew place man pages and completions; `curl | sh` is the
fallback path for users without those, and parity is the whole point of a fallback. So the
answer isn't per-consumer preference; it's: **install them whenever the tool has them.**

Which the script can determine **itself**: the archive either contains `man/` and
`completions/` or it does not. **Look, don't ask.** `--bin-only` still declines at runtime.

Two wins: `INSTALL_MAN` disappears (the config block shrinks to `TOOL` + `SIGNER_REPO`,
which strengthens D6 — less config is less generator-pressure), and dot-dagger gets man
pages the day it ships them, with no vendored-config change and nobody remembering to flip a
flag.

### 6.7 The rc snippet is ours (D26 — resolves Q4)

**The problem**: dstow emits its own rc snippet (`dstow snippet rc`, its B1) which hardcodes
`~/.local/bin` — coupling it to our F3 default **across a repo boundary, with no shared
test**. If F3 ever changes, nothing tells dstow. The earlier draft's answer was *"accept and
document the coupling."* That is surrender dressed as pragmatism.

**Under the reframe: the snippet is our artifact, and we own it.**

The reasoning is §3's. The snippet is *the* thing that lands in users' `.bashrc` and stays
there for years — the single most durable output of this entire system. It bakes our install
dir **and** our URL. It is the floor made concrete. **A thing that important cannot be a
hand-copied constant in a consumer's Go source.**

**The design**: release-ci authors the canonical snippet and **vendors it beside
`install.sh`** — same config block, same propagation, same review path.

This *fits dstow's own design better than dstow's does*: its B2 requires every snippet
emission be a **`go:embed` document — "real files, diffable, shellcheck-able in CI; never
string literals."** A vendored `snippet.sh` is exactly that file. dstow's `snippet rc`
becomes a thin reader of a vendored artifact instead of an independent hardcoding of a
constant it doesn't own.

**What it buys**: one source of truth for the install dir; the coupling becomes visible in a
PR diff instead of invisible across repos; shellcheck runs on it; and when the org migration
changes the URL (§9), the snippet propagates through the same pipe as everything else
instead of being four separate hand-edits.

**A need dstow hasn't articulated** — it asked for a `snippet rc` subcommand; what it needs
is for the snippet to stay correct without anyone remembering.

### 6.8 What we drop

- **dot-dagger's `VALID_TOOLS` positional** — an optional tool name validated against a
  one-entry list. Dead generality; baked-slug is gostow's shape and it's right.
- **`printf '%q'`** (`dot-dagger/install.sh:61`) — **not POSIX**; misbehaves under `dash`,
  which is exactly what `curl … | sh` invokes. A latent bug on the error path.
- **`--update`** — dropped with F2.

### 6.9 Honest positioning

Three choices are **defensible minority positions, not conventions**. The script's comments
should say so:

1. **Presence-checking at all** — 5 of 15 surveyed installers do it.
2. **Fully-silent presence-exit is attested nowhere** — every checking installer speaks. Our
   "speaks, exit 0" is *vindicated*; `--silent` is our own extension.
3. **`~/.local/bin`** — 2 of 15. Most use a tool-specific dir.

### 6.10 Scope, defended

mise (#7) and package managers own version management and upgrades. **`install.sh` does one
thing: put a verified binary on a bare machine.** That is the counter-offer to any ask that
it grow. mise does not reduce this scope — mise is itself a binary something must install,
so on a fresh machine there is no mise either.

### 6.11 Testing (D17)

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
| **D11** | **`--install-dir`, renamed from `--dir`** — pairs with `<TOOL>_INSTALL_DIR`; fnm's spelling. *Re-derived*: the old reasoning was "matches both shipped scripts," i.e. incumbency |
| **D12** | Drop `VALID_TOOLS` positional, `printf '%q'`, `--update` |
| **D13** | mise is an **additional channel** (`github` backend), not a replacement; `go` backend never |
| **D14** | Verify before citing; dstow's installer survey is unreliable prior art |
| **D15** | Sequence per §5; #4 first; #1 not gated on #3 |
| **D16** | **Presence check = both, install path first, then `command -v`** (§6.5). Resolves Q1 |
| **D17** | **Testing = bats-core under bash *and* dash, real-release fixture, floor matrix** (§6.10). Resolves Q2 |
| **D18** | **#4 = pin with `--require-hashes` + compiled requirements now.** The `curl`-the-API option is real but not free — Cloudsmith's upload is **two-step** (PUT → identifier → POST with deb/rpm params), so we'd own ~15 lines of bash + `jq`. **Evaluate separately; do not block the fix.** Resolves Q5 |
| **D19** | **Adopt the downshift — it is established practice, not our invention** (below). Resolves Q6 |
| **D20** | **Man/completions: detect from the archive, don't configure.** *Re-derived* — `INSTALL_MAN` encoded today's accident as tomorrow's config. `--bin-only` still declines. Shrinks the config block (§6.6). Resolves Q7 |
| **D21** | **Bare `INSTALL_DIR` is dropped outright — no deprecation window.** *Re-derived, reversed*: the "compatibility fallback" preserved the exact collision bug that namespacing exists to fix (§6.5). Resolves Q9 |
| **D22** | `install.sh` lives at **`installer/install.sh`** here — not repo root, which would imply release-ci installs something. Canonical copy has `TOOL=""` and aborts with a usage error. Resolves Q10 |
| **D23** | **Go stays on `actions/setup-go`** — mise's `core:go` cannot read `go.mod` (below). Resolves Q11 |
| **D24** | **Propose declining #6** (mise in CI) — its case collapsed once Go was excluded (below) |
| **D25** | **The Fulcio signer identity is a config-block variable** (`SIGNER_REPO`), not a literal. The org migration otherwise hard-aborts every cosign-having install; 8 hardcoded literals become 1 vendored value (§9, #11) |
| **D26** | **release-ci owns the rc snippet** and vendors it beside `install.sh`. It is the most durable artifact we produce and cannot be a hand-copied constant in a consumer's Go source. Fits dstow's own B2 (`go:embed` real files) better than dstow's own design does (§6.7). Resolves Q4 |
| **D27** | **hud gets the installer when it releases.** *Re-derived*: Q8 said "ask hud's owner." Uniformity is the default; divergence needs a reason (§2) — a Go CLI in this family has none to lack an install story. And **hud's root-level `.goreleaser.yaml` is not a constraint on our design**: it has never been run by release-ci, so if the design wants `.goreleaser/<tool>.yaml`, hud changes. Resolves Q8 |

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
| **Q3** | **Propagation mechanism.** How do changes reach 4 consumer repos? **§2 raises the stakes**: if we change downstream freely, propagation is a core capability, not a convenience — and §9's migration needs it *simultaneous, before a deadline* | **Still: do it manually, for now.** 4 repos. Automation needs a cross-repo PAT — a new supply-chain surface **in the repo holding the signing keys**. But the honest tension is now visible: the posture argues for the robot and the scale argues against it. **Revisit before the migration, not after** | #1 (may split) |
| **Q12** | **Tag discipline / blast radius.** All 4 consumers pin `@v0.1.1`, the only tag ever cut, by hand, with no release-please here | #3's to answer. Note the reflexive gap: **if D19's convention is org-wide, release-ci should follow it too — and release-ci has no release-please config at all.** Possibly its own issue | #3, #2 |

### 7.3 Deliberately not decided here

- **Everything #3 exists to decide** — the can/should/shouldn't verdicts per element. #3 is
  the mechanism, not a gap.
- **#2's fate** — likely *can-but-shouldn't*; #3 rules.

## 8. Known risks

1. **D6 is the load-bearing bet.** If consumer needs outgrow the config block, the pressure
   will be to add a template engine — godownloader's road. §6.3's rule (say no) only holds
   if someone enforces it.
2. ~~Q4's cross-repo coupling is invisible.~~ **Resolved by D26** — release-ci owns and
   vendors the snippet, so the coupling lives in one file and shows up in a PR diff.
3. **hud is an untested integration presented as a consumer** — wired, zero releases. Its
   root-level `.goreleaser.yaml` has never been run by release-ci. Per D27 this is no longer
   a *constraint* on our design (hud changes if the design says so), but it does mean any
   claim that something "works for hud" is unevidenced.
4. **The prior art is unreliable** (§4). Three documents in this org have made cross-repo
   claims that failed inspection.
5. **This plan may be too large for the problem.** Four repos, one maintainer, one tool that
   has ever released more than five times. §0 asks reviewers to cut rather than add.

## 9. The org migration (#11)

**Standing intent**: migrate these repos from the personal `rocne` account to a GitHub org
with org-level shared secrets. Not imminent. The rule from #3 is *design for it, don't
couple to it* — and until 2026-07-16 that rule was **recorded but never tested against the
decisions**. It should have been; testing it found a live break.

**The break**: the vendored installer pins the Fulcio identity to
`^https://github\.com/rocne/release-ci/…` and **hard-aborts** on mismatch
(`gostow/install.sh:149-156`). Post-migration, releases sign as `<neworg>/release-ci`, so
**every install on a machine with cosign fails** — for every consumer, from the first
post-migration release. Vendored scripts update on PR merge, not on release, so the fix must
land and propagate **before** the move. The identity is hardcoded in **8 files across 5
repos**, four of them consumer `release-dryrun.yml` signing gates.

**The ordering trap**: old releases keep the old identity forever, so the installer must
accept **both** — an alternation of two exact prefixes, not a loosened regex.

**⚠️ The constraint that makes this safe**: **never free the `rocne` namespace.** If it were
released and re-registered, that party could create `rocne/release-ci`, have Fulcio
legitimately sign with the identity our installers trust, and serve
`raw.githubusercontent.com/rocne/<tool>/main/install.sh` — **which rc snippets pipe into
`sh`**. Every layer would report success. If the migration is *personal account retained +
org created + repos transferred*, this risk is nil — but that must be **written down as a
constraint, not left to how it happens to get done**.

**How this feeds the design** (D25): the identity becomes a **config-block variable**
(`SIGNER_REPO="rocne/release-ci"`), not a literal at line 149 of two hand-copied scripts.
Eight hardcoded literals become one vendored value. This is the strongest concrete argument
yet for #1 existing at all — and it is also the strongest counter-argument to Q3's
*"don't build the propagation robot"*, since a migration needs simultaneous propagation
across every consumer.

**Also unverified, and load-bearing**: whether GitHub's transfer redirects cover
`raw.githubusercontent.com` and `workflow_call` refs, and for how long. Do not assume.
Redirects are void if the old namespace is re-registered.

## 10. Needs downstream hasn't articulated

§2's third rule, made concrete. **Nothing in this list was asked for. Everything in it is
needed.** This is the section to grow — it is where the system stops being a request queue
and starts being a design.

| # | what they'd have asked for, had they seen it | affected | status |
|---|---|---|---|
| 1 | **The org migration will abort every install on every machine with cosign** — the Fulcio identity is pinned to `rocne` and hard-fails, across 8 files in 5 repos, and vendored scripts update on merge, not on release | all | #11, §9 |
| 2 | **Never free the `rocne` namespace** — or a squatter can have Fulcio *legitimately* sign as us, and serve the URL that rc snippets pipe into `sh` | all, permanently | #11, §9 |
| 3 | **Your release job installs unpinned Python beside your signing key** — `pipx install cloudsmith-cli` resolves 17 transitive deps fresh, in the job that already has `GPG_PRIVATE_KEY` on disk | all | #4 |
| 4 | **Your versioning tells Cargo/npm-minded users that every feature is a breaking change** — `feat → minor` at 0.x, when both ecosystems read minor-at-0.x as *breaking* | gostow, dot-dagger, hud | #8 |
| 5 | **`command -v` alone never converges** — the presence check dstow asked for reinstalls forever if the install dir isn't on `PATH` | dstow | D16 |
| 6 | **Your rc snippet hardcodes a constant it doesn't own**, and nothing tells it when that constant changes | dstow | D26 |
| 7 | **`printf '%q'` isn't POSIX** — a latent bug on the error path of a script whose entire job is being safe to pipe into `dash` | dot-dagger | D12 |
| 8 | **Nothing on your install path consumes the provenance you pay to produce.** We emit SLSA attestations and cosign-signed checksums; `install.sh` checks a checksum and treats cosign as optional. **mise's `github` backend verifies those attestations by default** — the only thing that ever has | all | #7 |
| 9 | **Your pipeline has never run** — wired to release-ci, zero releases cut, so the layout, secrets, and signing gate are all untested | hud | §1, D27 |
| 10 | **Four copies of the signing identity** — `release-dryrun.yml` carries the Fulcio regex in four repos: one migration, four hand-edits, four chances to miss one | all | #3, #11 |

**How this list gets longer**: by testing the plan against things nobody asked about. #11
exists because someone asked whether we had considered the org migration — it had been
recorded as a standing constraint for eight rounds and never once checked against a decision.
**That question should be put to every standing constraint in this document.**
