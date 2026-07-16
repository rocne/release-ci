# release-ci — design and plan of record

Status: **living**. Last revised 2026-07-16.

This is the binding synthesis for release-ci: what it is, what it owes consumers, what
it refuses, and what is decided versus still open. Where this document and an issue
disagree, **this document is the design and the issue is the work**; where this document
and a *consumer's* requirements disagree, see §2.

Every numbered decision below is written out in full here. There is deliberately no
"see the ledger on issue N" — a sibling document
([dstow DESIGN.md §9](https://github.com/rocne/dstow/blob/main/docs/DESIGN.md#9-bootstrap-and-distribution))
advertises requirements "B1–B9" while B7 and B9 exist only in an issue comment, and the
gap cost real time to discover. If a decision isn't spelled out here, it isn't decided.

---

## 1. What release-ci is

A reusable GitHub Actions release pipeline for rocne's Go tools. Consumers call
`.github/workflows/release.yml` via `workflow_call` with `secrets: inherit`.

**The division of labour**: callers decide **when** to release and at **what version**;
release-ci defines **how** — build, sign, publish, verify. That line is the whole design.

Current surface: GoReleaser build → SLSA attestation → cosign/Fulcio verify → Cloudsmith
apt/dnf install smoke → optional caller e2e.

**Consumers**, verified 2026-07-16:

| repo | wired | releases cut | `install.sh` |
|---|---|---|---|
| dot-dagger | yes | 100+ (v0.11.0) | yes |
| gostow | yes | 5 (v0.4.0) | yes |
| hud | yes | **0 — never released** | no |
| dstow | yes | 0 (pre-release) | not yet |
| sorta | no — conventions only | — | no |

All four wired repos pin `@v0.1.1`, which is release-ci's only tag. **Tag discipline is
therefore untested, not proven.**

## 2. Authority: consumer requirements are inputs, not mandates

**release-ci owns its own design.** A consumer's stated requirement — however formally
recorded in that consumer's own design docs — is an *input* to a decision here, never a
mandate. This applies equally to dstow's DESIGN.md §9, gostow's existing scripts, and
any future consumer.

**When we decline, we owe a counter-offer, not a refusal.** The shape is: *no — here is
what we will provide instead, here is how to use it, and here is why it is better.* A
bare "no" is a failure of this design; so is silent compliance with an ask we think is
wrong.

**Corollaries:**

- **Incumbency is not an argument.** "gostow already does it this way" is evidence about
  what works, never a reason by itself. Preserving the current system is not a priority.
- **Downstream deadlines are not our constraints.** dstow's DESIGN.md declares its first
  release blocks on #1 with "no fallback design." That is honoured and it is real — but
  a downstream repo unilaterally declaring an unfallbacked dependency **must not become
  schedule pressure to ship a design we would otherwise refuse.** The counter-offer
  always exists: dstow ships an interim installer and vendors the canonical one later.
- **Consumers are protected by the floor (§3), not by a veto.**

**Worked example** (D9, below): dstow's B6 demanded a non-overridable `~/.local/bin`.
Declined. Counter-offered: a *stable default* plus an override — strictly more than was
asked, breaking nothing downstream.

## 3. The floor and the opt-out — a load-bearing pair

**The floor**: the behavioural contract release-ci guarantees. The pipeline may grow
anything *above* the floor freely, without consulting consumers; consumers depend on
nothing above it.

**The opt-out**: every feature must be independently declinable, with omission as clean
absence — **never a stub**. A consumer must never supply a dummy no-op to satisfy a step
that assumes a feature exists.

**These two rules are load-bearing on each other and neither works alone.** Unconstrained
growth is safe *only because* consumers can decline what grows; growth plus no opt-out is
breakage on a delay.

Precedent already correct: `e2e_script` defaults to empty and skips
(`release.yml:44-48`); gostow's installer `--bin-only` declines man/completions with no
stub. **Generalize those; they are not special cases.**

Consequence for #3's audit: an element absorbable **only by being mandatory** demotes
from *should* to *can*. "Consumers can supply a no-op" is disqualified.

## 4. Evidence base

Three surveys, `docs/reference/` (merged in #5). Each carries a reviewer's note recording
what was independently re-verified — **because the prior art has failed verification
repeatedly, and this is now a standing hazard, not a one-off**:

| source | status |
|---|---|
| [`installer-conventions-survey-2026-07-16`](reference/installer-conventions-survey-2026-07-16.md) | 15 installers read at source. Reliable; **one synthesis claim corrected** ("info→stdout is universal" — mise and Volta route info to stderr) |
| [`installer-tooling-survey-2026-07-16`](reference/installer-tooling-survey-2026-07-16.md) | Reliable; **corrected a false premise in its own brief** (`dist` is actively maintained, not wound down) |
| [`mise-survey-2026-07-16`](reference/mise-survey-2026-07-16.md) | Reliable; its central claim was desk research, **since verified empirically** against real releases |
| dstow's [release-installer survey](https://github.com/rocne/dstow/blob/main/docs/reference/release-installer-survey-2026-07-14.md) | ⚠️ **Cite only where re-verified.** Two claims checked, two wrong: "dot-dagger's install.sh is essentially the same script minus man/completions" (a diff shows a second structural divergence); "both gostow and dot-dagger have a version guard" (dot-dagger has none). Its scope is also narrower than commonly cited — it never examined hud or sorta |

**Standing rule: verify before citing.** Three separate documents in this org have now
asserted cross-repo "identical/both/all" claims that failed on inspection.

## 5. Plan of record

Sequence, and why:

| # | work | state |
|---|---|---|
| **#4** | Pin/remove the Cloudsmith CLI | **First.** Live supply-chain hole, no dependencies, hours not days |
| **#1** | Canonical `install.sh` | **The main event.** Research complete, build confirmed. dstow blocks on it |
| **#7** | Endorse mise as an install channel | Cheap, verified working. A README stanza |
| **#8** | Pre-1.0 downshift convention | Cheap, unblocked. One line × 3 repos. Not release-ci code at all |
| **#3** | Adoption audit | The big one. Gates #2 |
| **#6** | mise-in-CI spike | Architecture question, no deadline |
| **#2** | Version guard as input | Last. Behind #3, likely *can-but-shouldn't* |

## 6. `install.sh` — the design (#1)

### 6.1 Why we build rather than adopt

Settled by the tooling survey. **godownloader** — GoReleaser's own generator, which
produced an `install.sh` *from* a `.goreleaser.yml`, i.e. almost exactly this ask — is
archived (2022-01-14) with no successor. Its author
[doubted the approach itself](https://github.com/goreleaser/godownloader/issues/161), not
just the maintenance burden. The successor he floated
([goreleaser#4565](https://github.com/goreleaser/goreleaser/issues/4565), "make it a pipe
on goreleaser") has been **open since 2024**, with go-task's maintainer commenting in
2025: *"We still rely heavily on godownloader for Task, despite being deprecated."* The
ecosystem **froze rather than migrated**.

Every alternative fails a checkable test: `dist` regenerates per release rather than
vendoring a stable file and has no presence-check/`--force`/`--version`; instl.sh, webi
and goblin.run each require **a third party reachable at install time** (goblin.run
additionally *recompiles our source on its servers*, defeating the entire signing chain);
ubi/aqua/binenv/cargo-binstall all require a manager to be installed first, so none serve
the fresh-machine case.

**Nothing surveyed combines** presence-check + `--force` + `--version` + a stable vendored
file + no install-time third party. That combination is unserved, not deliberately
avoided.

### 6.2 Delivery: vendoring

The script is **authored here and vendored downstream** — it lives at each consumer's
repo root, served from that consumer's own raw-on-`main` URL
(`raw.githubusercontent.com/rocne/<repo>/main/install.sh`).

Rationale: one hop; one whitelist-obvious URL on the product repo; audit-in-context;
survives the eventual org migration; and vendored updates transit each consumer's own PR
review + shellcheck CI rather than bypassing release gates.

### 6.3 Parameterization: a config block, **not a generator**

⚠️ **This is the design's sharpest question, and the one most likely to repeat
godownloader's mistake.** "Baked at vendor time" + "propagate to 4 repos" implies
*something* does the baking — and the thing that died was precisely a *generator*.

**The design: one real script, with a config block at the top.**

```sh
# ---- vendored config (per-consumer; everything below this block is canonical) ----
TOOL="gostow"           # binary name; also the repo slug under github.com/rocne/
INSTALL_MAN=1           # 0 for consumers that ship no man page/completions
# ---- end vendored config ----
```

- **It is a working script, not a template.** No render step, no placeholder syntax,
  nothing to run before it is valid. `install.sh` in this repo is executable as-is
  (with release-ci's own values, or a sensible default) and is shellcheck-able in CI here
  as well as downstream.
- **Vendoring** = copy the file, set the config block. **Propagation** = replace
  everything *below* the config block, preserve the block. That is a `sed`/`awk` range
  operation in a propagation workflow — not a code generator, and it cannot drift into
  one.
- **Why this survives caarlos0's objection**: what he doubted was deriving installers
  *from build config* — a generator with a config language, a template engine, and a
  compatibility surface across every GoReleaser feature. We have none of that. We have
  one file and a copy step.

**Consequence**: consumer-specific behaviour must be expressible as *variables in the
config block*, never as template branches. If a consumer ever needs something the config
block can't express, that is a signal to say no (§2), not to add a template engine.

### 6.4 The floor

| # | rule |
|---|---|
| **F1** | **Presence check** → if already installed and no overriding flag: one status line, **exit 0** |
| **F2** | `--force` reinstalls; `--version vX.Y.Z` installs that version and **implies force**. **No self-update** — package managers and mise own upgrades |
| **F3** | **Install dir default resolves to `~/.local/bin`** on a machine that hasn't opted out. Consumer rc snippets may rely on that |
| **F4** | **Checksum mandatory** — no `sha256sum`/`shasum` is a hard abort |
| **F5** | **Cosign opportunistic** — verify iff present, else one notice and proceed. Requiring it would fail bootstrap on exactly the fresh machines bootstrap serves |
| **F6** | **Exit code is unconditional and level-independent**; the *message* is a function of verbosity. A no-op under `--silent` still exits 0; a failure under `--silent` still exits non-zero |

Consumers depend on **nothing** beyond F1–F6.

### 6.5 Resolved behaviour

**Install directory** — precedence, highest first:

| | source | note |
|---|---|---|
| 1 | `--dir <path>` | flag name **matches both shipped scripts**; do not "improve" it to `--install-dir` |
| 2 | `<TOOL>_INSTALL_DIR` | namespaced, baked with the slug |
| 3 | `INSTALL_DIR` | **deprecated fallback**; warn on use |
| 4 | `$XDG_BIN_HOME` | follows **uv specifically** (1 of 15 surveyed), not a broad norm |
| 5 | `~/.local/bin` | default (F3) |

**Output levels** — settable by flag or env (env matters: `curl | sh` can't pass flags):

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

**Conventions**: all human output → **stderr** at every level (an installer emits no data
on stdout; mise and Volta do the same, though this is a *minority* position — only
errors-to-stderr is universal). Exit 0 success/no-op, 1 runtime, 2 usage. Errors carry
`error:` + `hint:`. `NO_COLOR` honoured; TTY check before colour/progress.

### 6.6 Above the floor

Free to grow, no consultation, consumers depend on none of it: `--require-signature`
(strict cosign; the opportunistic default stays), man/completions install (`--bin-only`
to decline), `--os`/`--arch`, `--dry-run`, `--help`, upgrade hints, the output levels
themselves.

`--help` prints the script's own comment header (`sed -n '2,23p' "$0" | sed 's/^# \?//'`)
— a good idiom in both shipped scripts; keep it, keep the line range right.

### 6.7 What we drop, and what we don't inherit

- **dot-dagger's `VALID_TOOLS` positional** — takes an optional tool name validated
  against a one-entry list. Dead generality; baked-slug is gostow's shape and it's right.
- **`printf '%q'`** (`dot-dagger/install.sh:61`) — **not POSIX**, misbehaves under `dash`,
  which is exactly what `curl … | sh` invokes. A latent bug.
- **`--update`** — dropped with F2.

### 6.8 Honest positioning

Three of our choices are **defensible minority positions, not conventions**, and the
script's own comments should say so rather than implying consensus:

1. **Presence-checking at all** — 5 of 15 surveyed installers do it. Most overwrite
   unconditionally.
2. **Fully-silent presence-exit is attested nowhere** — every checking installer speaks.
   Our "speaks, exit 0" is *vindicated*; `--silent` is our own extension.
3. **`~/.local/bin`** — 2 of 15. Most use a tool-specific dir (`~/.cargo`, `~/.deno`).

### 6.9 Scope, defended

mise (#7) and package managers own version management and upgrades. **`install.sh` does
exactly one thing: put a verified binary on a bare machine.** That is the counter-offer
to any ask that it grow.

mise does **not** reduce this scope: mise is itself a binary something must install, so on
a genuinely fresh machine there is no mise either. `curl | sh` has no prerequisite.

---

## 7. Decision register

### 7.1 Decided

| # | decision |
|---|---|
| **D1** | Consumer requirements are inputs, not mandates; declining owes a counter-offer (§2) |
| **D2** | Incumbency is not an argument; preserving the current system is not a priority |
| **D3** | The floor and the opt-out are a load-bearing pair; mandatory-only ⇒ demote to *can* |
| **D4** | Build `install.sh`; adopt nothing (§6.1) |
| **D5** | Deliver by vendoring, served from each consumer's own raw-on-`main` URL |
| **D6** | Parameterize via a **config block in a real script**; never a generator or template engine (§6.3) |
| **D7** | The floor is F1–F6 (§6.4) |
| **D8** | Install-dir env var is **namespaced** (`<TOOL>_INSTALL_DIR`); bare `INSTALL_DIR` deprecated fallback |
| **D9** | Install dir is **tunable**; the *default* is what's contractual — declines dstow B6 with a counter-offer |
| **D10** | Four output levels; all human output to stderr; exit code independent of level |
| **D11** | `--dir` keeps its name (matches both shipped scripts) |
| **D12** | Drop `VALID_TOOLS` positional, `printf '%q'`, `--update` |
| **D13** | mise is an **additional channel** (`github` backend), not a replacement; `go` backend never (§6.9, #7) |
| **D14** | Verify before citing; dstow's installer survey is unreliable prior art (§4) |
| **D15** | Sequence per §5; #4 first; #1 not gated on #3 |

### 7.2 Undecided — **and these are real**

Ordered by how much they block.

| # | open question | who/what decides | blocks |
|---|---|---|---|
| **Q1** | **Presence check: `command -v` (wider PATH), install-path only, or both?** dstow B6 says `command -v`; **mise deliberately does the opposite** — *"Only the install path is checked (not the wider PATH) so that skipping never leaves install_path missing"* (`mise.run:286-288`). Each fails alone: `command -v` only ⇒ a custom dir off PATH reinstalls forever, never converging. Install-path only ⇒ a tool already at `/usr/bin` via apt gets a silent second copy. **Recommendation: check both — resolved install path first, then `command -v`.** Strictly better than either, and is itself the counter-offer to B6 | maintainer / implementer | **#1 — F1's exact semantics** |
| **Q2** | **Testing strategy.** Nothing is decided: shellcheck is assumed, but is there a `bats` suite? A container matrix (the F1–F6 floor is executable — presence/absent × 4 levels × force/version)? Does release-ci's own CI run it, or only consumers'? **"Test-first against the floor" is a stated intent with no harness behind it** | implementer | **#1 — start of work** |
| **Q3** | **Propagation mechanism.** "Open PRs against each consumer on change" is decided in principle, unspecified in fact: a workflow here with a PAT? `gh` in a matrix? Manual? Who reviews? What preserves the config block across updates (§6.3 says a range operation — whose?) | — | #1 (may split to its own issue) |
| **Q4** | **The rc snippet has no owner.** dstow emits its own via `dstow snippet rc` (its B1), and that snippet **hardcodes `~/.local/bin`** — coupling it to our F3 default across a repo boundary with no shared test. If F3 ever changes, nothing tells dstow. Does release-ci ship a canonical snippet too, or document F3 as the contract and leave emission to consumers? | maintainer | #1 (design), #3 (ownership) |
| **Q5** | **#4: pin with hashes, or delete the dependency?** `cloudsmith-cli` pulls 17 transitive deps into the job holding `GPG_PRIVATE_KEY`. `--require-hashes` + a compiled requirements file closes it. **But if GoReleaser's publisher `cmd` can `curl` Cloudsmith's HTTP API directly, the whole Python tree leaves the signing job** — a bigger win. **Unresearched** | — | **#4** |
| **Q6** | **#8: is the downshift the right convention?** It's release-please-native and one line — but it collapses `fix` and `feat` into one tier, trading one lost distinction for another. **Nobody has checked whether an established pre-1.0 convention already exists**, which sits badly against the standing instruction *follow established practice, don't reinvent wheels* | implementer | #8 |
| **Q7** | **Man/completions in the config block?** gostow ships them, dot-dagger doesn't. §6.3 assumes `INSTALL_MAN=1`; §6.6 puts them above the floor with `--bin-only` to decline. Are those consistent — is it vendor-time config, a runtime flag, or both? | implementer | #1 |
| **Q8** | **Does hud get an installer at all?** It has **never cut a release**, so its missing `install.sh` is probably *not yet* rather than *declined*. Earlier text treated it as a deliberate opt-out; that was withdrawn. **Ask hud's owner rather than infer from an absent file** | maintainer | #1 (census), #3 |
| **Q9** | **When does the bare `INSTALL_DIR` fallback get dropped?** D8 defers it indefinitely, which is how deprecations become permanent | — | — |
| **Q10** | **Where does `install.sh` live in this repo**, and does release-ci's own CI shellcheck it? Trivial, but unanswered | implementer | #1 |
| **Q11** | **#6: can `core:go` read `go.mod`'s `go` directive** the way `actions/setup-go`'s `go-version-file` does? **Unverified and load-bearing** — if not, Go stays on `setup-go` and mise-in-CI's "one source of truth" pitch is already half-lost | spike | #6 |
| **Q12** | **Tag discipline / blast radius.** All 4 consumers pin `@v0.1.1`, the only tag ever cut. How do central changes roll out? Untested, and #3's absorption recommendations all depend on the answer | #3 | #3, #2 |

### 7.3 Deliberately not decided here

- **Everything #3 exists to decide** — the can/should/shouldn't verdicts per element.
  #3 is the mechanism, not a gap in this document.
- **#2's fate** — likely *can-but-shouldn't*; #3 rules.
- **#6's outcome** — a spike is a question, not a plan.

---

## 8. Known risks

1. **Q1 and Q2 are unresolved and #1 is next.** F1's semantics and the test harness are
   both prerequisites, not details — #1 shouldn't start until Q1 has an answer and Q2 has
   a shape.
2. **The config block (D6) is the design's load-bearing bet.** If consumer-specific needs
   outgrow it, the pressure will be to add a template engine — which is godownloader's
   road. §6.3's rule (say no, per §2) only holds if someone enforces it.
3. **Q4's cross-repo coupling is invisible.** dstow's rc snippet hardcodes our F3 default.
   No test spans that boundary, and nothing here can detect a break.
4. **hud is an untested integration presented as a consumer.** Its root-level
   `.goreleaser.yaml` — the layout that constrains absorption designs in #3 — **has never
   been run by release-ci**. Any design "fitting hud's layout" is fitting a layout nobody
   has executed.
5. **The prior art is unreliable** (§4), and three documents in this org have now made
   cross-repo claims that failed inspection. The standing rule is *verify before citing*;
   it costs time and skipping it has cost more.
