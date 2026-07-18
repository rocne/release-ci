# release-ci — design and plan of record

Status: **reviewed proposal — resolving to final intent.** Last revised 2026-07-17.

Adversarially reviewed 2026-07-17 against live repos and primary sources; the review is
[`reference/plan-review-2026-07-17.md`](reference/plan-review-2026-07-17.md) and this
revision applies it. Next step: decompose this document into a roadmap of GitHub issues
with blocking dependencies.

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

**Review status (2026-07-17)** — the adversarial review §0 previously asked for has run;
verdicts on the points we were least confident about:

| where we were least confident | verdict |
|---|---|
| **D6 — "config block, not a generator"** (§6.3) | **Reviewed: stands, on corrected legs.** The caarlos0-objection framing was an over-read (he wanted generation *integrated*, not abandoned — godownloader#161 is titled "Call for Maintainers"); the real argument is scale and ownership (§6.3). The review also found the block as previously specified could not express dot-dagger — fixed |
| **D16 — presence-check semantics** (§6.5) | **Reviewed: the dual check stands.** The review found F1 and F2 contradicted each other on `--version`; resolved by D28 (ensure-semantics) |
| **D24 — decline #6 (mise in CI)** | **Reviewed: endorsed.** Every link re-checked, including empirically (mise 2026.7.7 reads neither `go.mod` nor `.go-version` by default). Counter-offer extended by D29 |
| **§2's posture itself** | **Reviewed: sound.** D11 is a real consistency gain, not churn. One guardrail applied: §11 no longer instructs future agents to extrapolate the posture |
| **Scale sanity generally** | 4 repos, 1 maintainer, ~148 releases total. Reviewed against the maintainer's actual goal — **excellent, principled, ergonomically consistent**, not minimal. Cuts applied where complexity bought no excellence: §6.11's container layer is gone, #3 shrinks to a checklist, #2 folds into it |

**Read these first — they are the handoff, and this document is not trustworthy without them:**

| § | what it gives you |
|---|---|
| **§11 Maintainer directives** | Which decisions came **from the maintainer** (M1–M12, quoted) and which the agent invented. §2's posture was *given*, not inferred. Without this you cannot tell whose judgement you are reviewing |
| **§12 Options considered** | What was already rejected and **the one specific reason each failed**. Several are good ideas that die on a single checkable fact. Don't re-litigate without new evidence |
| **§13 Mistakes made** | **22 of ours, 5 inherited** (15–19 found by the 2026-07-17 review; 20–22 by same-day follow-up passes). Every one came from accepting a claim instead of checking it; every one died to a single command. Calibrate your trust here |
| **§14 Consumer adaptation plans** | The exact, verified change list per downstream repo — what changes, why, in what order, and what each step blocks on. This is what the per-repo roadmap issues are cut from |

**What is settled and why** — please don't re-litigate without new evidence; each was
checked against primary sources this week, and the checks are in
[`reference/findings-2026-07-16.md`](reference/findings-2026-07-16.md):

- Build the installer rather than adopt one (§6.1) — every alternative fails a concrete test.
- Vendoring as the delivery model (§6.2).
- The install dir is tunable (D9) — dstow's design says otherwise; both shipped scripts already contradict it.

**What changed in this revision** (applying the 2026-07-17 review): the org-migration
inventory in §9 was corrected (3 files, not 8 — the `release-dryrun.yml` claim was false);
the census was corrected (dot-dagger has 141 releases, not 100); the config block gained
`REPO` (it could not previously express dot-dagger) and lost `INSTALL_MAN` from its example;
F2's `--version` semantics were re-derived (D28 — the inherited "implies force" contradicted
F1 and never converged); D6's justification was rewritten from the primary sources; five new
decisions were added (D28–D34); §10 gained nine entries; §13 gained eight mistakes (from
same-day follow-up passes: a verified `--help` bug in both shipped scripts — D33 — and
D30's over-strict first form, reshaped on maintainer challenge — M12); and **§14 is new**
— the exact, verified adaptation plan for each downstream consumer, from which the
per-repo roadmap issues are cut. The previous revision rewrote the posture (§2/§3) and
re-derived D11/D20/D21/D26.

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

**Consumers**, verified 2026-07-16, counts re-verified 2026-07-17 (the earlier "100" for
dot-dagger was a `--limit` truncation read as a total — §13 #15):

| repo | wired | releases cut | `install.sh` |
|---|---|---|---|
| dot-dagger | yes | 141 (v0.11.0) | yes |
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
[`plan-review-2026-07-17.md`](reference/plan-review-2026-07-17.md) is the adversarial
review this revision applies — it re-ran the load-bearing VERIFIED claims by command and
records which held (most) and which fell (§13 #15–19).

**Standing hazard**: three documents in this org have asserted cross-repo
"identical / both / all" claims that failed inspection — including a sibling survey cited
as prior art by three of our issues, and one survey we commissioned ourselves. **Verify
before citing.** Structural descriptions have held up; cross-repo comparative claims have
not.

## 5. Plan of record

| # | work | state |
|---|---|---|
| **#4** | Pin the Cloudsmith CLI with hashes; **SHA-pin the five actions in the signing job** (D29) | **First.** Two live holes of the same class in the job holding the signing key. Hours |
| **#1** | Canonical `install.sh` | **The main event.** Research complete; Q1/Q2 resolved (D16/D17); `--version` semantics resolved (D28); block shape corrected (§6.3). dstow blocks on it |
| **(new)** | Name the implicit contracts: `--version` parse rule (D30) + artifact shape (D34) | Small, and #1's presence check and D20's detection both depend on them. State each once; assert in CI (parse rule per consumer, artifact shape in `release-dryrun`) |
| **#8** | Pre-1.0 downshift convention | Cheap, unblocked, and **evidence-backed** (D19). One line × 3 repos |
| **#7** | Endorse mise as an install channel | Cheap, verified working. A README stanza |
| **#3** | Adoption audit — **shrunk to a checklist** (per review): elements × can/should/shouldn't × 5 repos. The 2026-07-16/17 censuses already did most of the measuring | Absorbs #2's verdict and Q12 |
| **(new)** | release-ci releases itself: release-please config here, D19 applied reflexively (Q12 promoted) | Small; gates nothing but tag discipline is currently untested |
| **#11** | Org-migration readiness — corrected inventory (§9) plus the three newly found channels (Cloudsmith slug, brew tap, Go module path) | Not imminent; must be resolved **before** any migration date |
| ~~#2~~ | ~~Version guard as input~~ | Folded into #3's checklist. Likely *can-but-shouldn't* |
| ~~#6~~ | ~~mise in CI~~ | **Declined** (D24, review-endorsed). Its case collapsed once Go was excluded |

**Per-consumer sequencing** — which of these each downstream repo feels, in what order,
and what blocks on what — is **§14**, and is the source for the per-repo roadmap issues.

## 6. `install.sh` — the design (#1)

### 6.1 Why we build rather than adopt

**godownloader** — GoReleaser's own generator, producing `install.sh` *from* a
`.goreleaser.yml`, i.e. almost exactly this ask — is archived (2022-01-14), no successor
named. Its author ran out of bandwidth and
[wondered aloud](https://github.com/goreleaser/godownloader/issues/161) whether separate
generation had been the right shape (§6.3 has the honest reading — he wanted it
*integrated*, not abandoned). The integration he floated
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
REPO=""                          # GitHub slug, e.g. rocne/dot-dagger. Set at vendor time.
TOOL=""                          # installed binary name, e.g. dotd. NOT always the repo slug.
SIGNER_REPO="rocne/release-ci"   # Fulcio identity the release is signed as (D25)
# ---- end vendored config ----
```

⚠️ **Correction (2026-07-17 review)**: the earlier block had a single `TOOL` with the
comment *"binary name = repo slug"* — **false for dot-dagger** (repo `dot-dagger`, binary
`dotd`), the family's most-released tool, and both shipped scripts already carry `REPO` and
`TOOL` separately. The design's central artifact failed §6.3's own expressibility rule for
1 of 4 consumers; caught by reading the consumer it claimed to serve (§13 #17). The earlier
`INSTALL_MAN` variable is gone per D20.

- **It is a working script, not a template.** No render step, no placeholder syntax.
  **Correction to an earlier draft**: that draft claimed the canonical copy runs "with
  release-ci's own values" — **wrong, release-ci ships no binary**. The canonical copy has
  `REPO=""` and `TOOL=""` and **aborts with a usage error** (*"install.sh: REPO/TOOL are
  unset — this is the canonical source; vendor it and set the config block"*). That keeps
  it a real, shellcheck-able, *executable* script that fails cleanly, rather than a
  template with placeholders. Tests set `REPO=rocne/gostow TOOL=gostow`.
- **Vendoring** = copy the file, set the block. **Propagation** = replace everything *below*
  the block, preserve the block. A `sed`/`awk` range operation — honestly, a tiny generator,
  which is why the invariant is **named and checkable**: everything below the marker is
  **byte-identical across consumers**, and any diff there is a propagation bug. (A CI step
  can verify vendored copies against the canonical below-the-marker; cheap to add later.)
- **Why not a generator — corrected justification** (the earlier draft over-read its
  source; §13 #19). godownloader#161 is titled *"Call for Maintainers"*: caarlos0's doubt
  was about maintaining generation as a **separate project on zero bandwidth**, and his
  preferred fix — *"maybe it would be better to make this a pipe on goreleaser?"* — is
  generation *integrated*, not abandoned (#4565 is him still wanting to build it). The
  honest argument for our shape is **scale and ownership**: godownloader owed strangers
  fidelity across every GoReleaser feature; we owe four repos we own fidelity to one asset
  layout we control, with a config surface of three variables. A generator's costs buy
  nothing at n=4. What *does* carry over from godownloader's death: never own a
  compatibility surface you don't control — which is what the rule below enforces.

**The rule that keeps it honest**: consumer-specific behaviour must be expressible as
**variables in the config block**, never as template branches. If a consumer needs something
the block can't express, that is a signal to **say no** (§2), not to add a template engine.

### 6.4 The floor

| # | rule |
|---|---|
| **F1** | **Presence check** → if already installed and no overriding flag: one status line, **exit 0**. Semantics in D16 |
| **F2** | `--force` unconditionally reinstalls; `--version vX.Y.Z` **ensures exactly that version** — exit 0 if already satisfied, installs otherwise (D28; the inherited "implies force" contradicted F1 and made pinned-version scripts reinstall forever). **No self-update** — package managers and mise own upgrades |
| **F3** | **Install dir default resolves to `~/.local/bin`** on a machine that hasn't opted out. Consumer rc snippets may rely on it |
| **F4** | **Checksum mandatory** — no `sha256sum`/`shasum` is a hard abort |
| **F5** | **Cosign opportunistic** — verify iff present, else one notice and proceed. Requiring it would fail bootstrap on exactly the fresh machines bootstrap serves |
| **F6** | **Exit code is unconditional and level-independent**; the *message* is a function of verbosity. A no-op under `--silent` still exits 0; a failure under `--silent` still exits non-zero |

Consumers depend on **nothing** beyond F1–F6.

### 6.5 Resolved behaviour

**Presence check (D16)** — check **both**, install path first:

1. **Resolved install path first.** If `$INSTALL_DIR/$TOOL` exists (and, when `--version`
   is given, reports that version — see D28/D30) → status line **naming the installed
   version**, exit 0. Naming it matters: exit-0 must not be mistakable for "latest".
   *Why first*: it **converges**. Checking only the wider PATH means a custom install dir
   that isn't on `PATH` reinstalls **forever**, never satisfying its own check.
2. **Then `command -v $TOOL`.** If found elsewhere — e.g. `/usr/bin/$TOOL` from apt — →
   status line naming the location, exit 0. **Do not silently shadow a package-managed
   install.** Exception: an explicit `--version` that the found copy does not satisfy
   installs to `$INSTALL_DIR` anyway (the user asked for a version, not a location) and
   still warns about the copy it will shadow. `--force` installs unconditionally.

Each check alone fails: wider-PATH-only **never converges**; install-path-only silently
installs a second copy beside an apt-managed one.

**`--version` semantics (D28)**: *ensure exactly this version* — satisfied → exit 0;
otherwise install. Only `--force` unconditionally reinstalls. The earlier F2 inherited
dstow B6's *"`--version` implies force"* verbatim, which contradicted F1 (present at the
requested version: F1 said exit 0, F2 said reinstall) and failed D16's own convergence
principle for any script that pins a version (§13 #18). Version matching requires reading
the installed tool's version — `$TOOL --version`, parsed per D30's rule (first
semver-shaped token on the first line; the smoke's substring grep at `release.yml:201` was
already format-agnostic). **Degradation is defined**: if the installed binary cannot be
executed (wrong arch, corrupted) or no version parses from its first line, ensure treats
the requirement as **unsatisfied and installs** — which converges, and repairs the broken
binary as a side effect. Note mise.run can version-match only because its server bakes the
target version into the served script (verified 2026-07-17); a static vendored script must
ask the binary — and its skip-if-exists is **opt-in**, not default, so our default-on
presence check remains our own position (§6.9).

**dstow's B6 asked for `command -v`, and we reject it — with one fairness note.** In the
context B6 serves, the rc snippet, `command -v` is *correct*: B1's snippet prepends
`~/.local/bin` to `PATH` **before** the guard, so the wider-PATH check covers the install
path there. The ask was context-bound, not senseless. But the installer must be correct in
**every** context — a custom install dir off `PATH`, invoked directly, reinstalls forever
under `command -v` alone — so the rejection stands (§2 rule 2). mise gets the other half
right, deliberately checking only the install path *"so that skipping never leaves
install_path missing"* (`mise.run:286-288`) — and gets the apt case wrong in exchange.
**Both were solving half. Step 1 is mise's concern; step 2 is dstow's; neither source
proposed both.**

**Install directory** — precedence, highest first:

| | source | note |
|---|---|---|
| 1 | `--install-dir <path>` | **renamed from `--dir`** (D11). Pairs with the env var below; fnm's spelling. Change the two shipped scripts |
| 2 | `<TOOL>_INSTALL_DIR` | namespaced, baked from the **binary name** (`GOSTOW_…`, `DOTD_…` — `TOOL`, not the repo slug). **No surveyed installer exposes a bare one** |
| 3 | `$XDG_BIN_HOME` | follows **uv specifically** (1 of 15 surveyed), not a broad norm |
| 4 | `~/.local/bin` | default (F3) |

**Bare `INSTALL_DIR` is gone, not deprecated (D21 — reversed).** The earlier draft kept it as
a "deprecated fallback… breaks nobody," which was deference wearing compatibility's clothes.
It is wrong on its own terms: **the fallback preserves the exact bug it was fallback for.**
We namespace *because* a bare `INSTALL_DIR` in the environment — exported for any unrelated
purpose — is silently absorbed. Honouring it "for continuity" keeps that collision alive
forever. Two repos we own, few users, and the flag is barely documented: **clean break, note
it in the release notes.** Simpler *and* strictly more correct.

**Output levels** — settable by flag or env (`curl \| sh` can't pass flags). The env var's
spelling is a #1 design detail with one requirement fixed here: it is **namespaced**
(e.g. `GOSTOW_INSTALL_QUIET`) — a bare `QUIET`/`VERBOSE` exported for any unrelated purpose
would be silently absorbed, the same collision class D8/D21 killed for `INSTALL_DIR`:

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

**Structure — truncation safety (D31)**: all logic lives in functions; the file ends with a
single `main "$@"` call. A dropped `curl | sh` connection then executes *nothing* rather
than a prefix of the script. Established practice (M5): mise.run is fully
function-wrapped with one trailing call (verified 2026-07-17); rustup equivalent. Neither
shipped script does this today — it is a property of the bare invocation the floor
protects, so the canonical script adopts it from day one.

**Latest-version resolution (D32)**: resolve via the `releases/latest` **redirect**
(`curl -sI https://github.com/$REPO/releases/latest` → `Location` header), not the JSON
API. Both shipped scripts curl `api.github.com`, which is rate-limited at 60/hr/IP
unauthenticated — it fails behind CI and office NAT, exactly where bootstrap runs. The
redirect answers the same question with no API, no rate limit, and no JSON-by-`grep`.

### 6.6 Above the floor

Free to grow, consumers depend on none of it: `--require-signature` (strict cosign; the
opportunistic default stays), man/completions install, `--os`/`--arch`, `--dry-run`,
`--help`, upgrade hints, the output levels themselves.

**`--help` comes from a `usage()` heredoc, not from reading `$0` (D33).** Both shipped
scripts print their own comment header via `sed -n '2,23p' "$0"` — and the earlier draft
called that *"a good idiom."* **Verified broken (2026-07-17)**: under the documented
invocation (`curl … | sh -s -- --help`), `$0` is `sh`, so the user gets
`sed: can't read sh: No such file or directory` — **and exit 0**. It fails precisely in the
mode the script exists for, and its hardcoded line range (gostow `2,23p`, dot-dagger
`2,14p`) is a per-vendor drift hazard besides. A `usage()` function with a heredoc serves
both invocation modes, needs no line arithmetic, and sits naturally inside D31's
function-wrapped structure. The comment header stays — for humans reading the file — but
nothing executes off it.

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

Two wins: `INSTALL_MAN` disappears (the config block shrinks to `REPO` + `TOOL` +
`SIGNER_REPO`, which strengthens D6 — less config is less generator-pressure), and
dot-dagger gets man pages the day it ships them, with no vendored-config change and nobody
remembering to flip a flag.

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

**Scope (clarified 2026-07-17)**: the canonical `snippet.sh` lives beside the canonical
installer here; it is **vendored to consumers that surface an rc snippet — today that is
dstow alone**. gostow/dot-dagger/hud get it the day they document a snippet, through the
same pipe, and not before (clean absence, §3).

**What it buys**: one source of truth for the install dir; the coupling becomes visible in a
PR diff instead of invisible across repos; shellcheck runs on it; and when the org migration
changes the URL (§9), the snippet propagates through the same pipe as everything else
instead of being a per-consumer hand-edit.

**A need dstow hasn't articulated** — it asked for a `snippet rc` subcommand; what it needs
is for the snippet to stay correct without anyone remembering.

### 6.8 What we drop

- **dot-dagger's `VALID_TOOLS` positional** — an optional tool name validated against a
  one-entry list. Dead generality; baked-slug is gostow's shape and it's right.
- **`printf '%q'`** (`dot-dagger/install.sh:60`) — **not POSIX**; misbehaves under `dash`,
  which is exactly what `curl … | sh` invokes. A latent bug on the error path.
- **`--update`** — dropped with F2.

### 6.9 Honest positioning

Four positions deserve honest comments in the script itself:

1. **Presence-checking at all** — 5 of 15 surveyed installers do it (and mise's is
   opt-in, not default; ours is default-on).
2. **Fully-silent presence-exit is attested nowhere** — every checking installer speaks. Our
   "speaks, exit 0" is *vindicated*; `--silent` is our own extension.
3. **`~/.local/bin`** — 2 of 15. Most use a tool-specific dir.
4. **Checksum-without-cosign is integrity, not authenticity.** The checksums file rides
   the same origin as the artifact, so F4 defends against corruption and truncation — not
   against a compromised release. Authenticity comes from cosign when present (F5,
   `--require-signature`), and from mise's default attestation verification (#7) — the one
   install path where it is checked without the user doing anything. Say this in the
   comments rather than letting F4 imply more than it delivers.

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
- **Matrix cells are generated, not hand-written** — bats loops over the three axes, so
  adding a level or a flag extends the matrix without 36 hand-edits.

**Cut (2026-07-17 review): no container layer for `install.sh`.** The earlier draft
floated reusing `smoke_distros` containers for end-to-end installer runs. The pipeline's
`package-repo-smoke` already exercises real containers on every release; a second
container matrix here would re-test `curl` and `mktemp`. The honest portability risk is
`dash`, and the bats-under-dash run covers it. The defended core is: **bash + dash**, and
the **exit-code / stream / effect** split asserted independently (F6).

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
| **D8** | Install-dir env var is **namespaced** (`<TOOL>_INSTALL_DIR`); bare `INSTALL_DIR` **dropped outright** (see D21 — this row previously said "deprecated" and was never updated after D21 reversed; §13 #14's class) |
| **D9** | Install dir is **tunable**; the *default* is contractual — declines dstow B6 with a counter-offer |
| **D10** | Four output levels; all human output to stderr; exit code independent of level |
| **D11** | **`--install-dir`, renamed from `--dir`** — pairs with `<TOOL>_INSTALL_DIR`; fnm's spelling. *Re-derived*: the old reasoning was "matches both shipped scripts," i.e. incumbency |
| **D12** | Drop `VALID_TOOLS` positional, `printf '%q'`, `--update` |
| **D13** | mise is an **additional channel** (`github` backend), not a replacement; `go` backend never |
| **D14** | Verify before citing; dstow's installer survey is unreliable prior art |
| **D15** | Sequence per §5; #4 first; #1 not gated on #3 |
| **D16** | **Presence check = both, install path first, then `command -v`** (§6.5). Resolves Q1 |
| **D17** | **Testing = bats-core under bash *and* dash, real-release fixture, floor matrix** (§6.11). Resolves Q2 |
| **D18** | **#4 = pin with `--require-hashes` + compiled requirements now.** The `curl`-the-API option is real but not free — Cloudsmith's upload is **two-step** (PUT → identifier → POST with deb/rpm params), so we'd own ~15 lines of bash + `jq`. **Evaluate separately; do not block the fix.** Resolves Q5 |
| **D19** | **Adopt the downshift — it is established practice, not our invention** (below). Resolves Q6 |
| **D20** | **Man/completions: detect from the archive, don't configure.** *Re-derived* — `INSTALL_MAN` encoded today's accident as tomorrow's config. `--bin-only` still declines. Shrinks the config block (§6.6). Resolves Q7 |
| **D21** | **Bare `INSTALL_DIR` is dropped outright — no deprecation window.** *Re-derived, reversed*: the "compatibility fallback" preserved the exact collision bug that namespacing exists to fix (§6.5). Resolves Q9 |
| **D22** | `install.sh` lives at **`installer/install.sh`** here (with `snippet.sh` beside it, D26) — not repo root, which would imply release-ci installs something. Canonical copy has `REPO=""`/`TOOL=""` and aborts with a usage error. Resolves Q10 |
| **D23** | **Go stays on `actions/setup-go`** — mise's `core:go` cannot read `go.mod` (below). Resolves Q11 |
| **D24** | **Propose declining #6** (mise in CI) — its case collapsed once Go was excluded (below) |
| **D25** | **The Fulcio signer identity is a config-block variable** (`SIGNER_REPO`), not a literal. The org migration otherwise hard-aborts every cosign-having install; the consumer-side literals become 1 vendored value, leaving 2 sites in release-ci's own `release.yml` (§9, #11 — inventory corrected 2026-07-17) |
| **D26** | **release-ci owns the rc snippet** and vendors it beside `install.sh`. It is the most durable artifact we produce and cannot be a hand-copied constant in a consumer's Go source. Fits dstow's own B2 (`go:embed` real files) better than dstow's own design does (§6.7). Resolves Q4 |
| **D27** | **hud gets the installer when it releases.** *Re-derived*: Q8 said "ask hud's owner." Uniformity is the default; divergence needs a reason (§2) — a Go CLI in this family has none to lack an install story. And **hud's root-level `.goreleaser.yaml` is not a constraint on our design**: it has never been run by release-ci, so if the design wants `.goreleaser/<tool>.yaml`, hud changes. Resolves Q8 |
| **D28** | **`--version` = ensure exactly that version**: satisfied → status line + exit 0; otherwise install; only `--force` unconditionally reinstalls (§6.5). *Replaces* the inherited "implies force" (dstow B6), which contradicted F1 and reinstalled forever for pinned-version scripts — failing D16's own convergence principle |
| **D29** | **SHA-pin every action in the signing job**, with Dependabot/Renovate advancing the pins. `checkout@v6`, `setup-go@v6`, `cosign-installer@v3`, `goreleaser-action@v7`, `attest-build-provenance@v2` are all movable refs running beside `GPG_PRIVATE_KEY` and OIDC — the same hole class #4 closes for pipx. Extends #4's counter-offer (D24) |
| **D30** | **The `--version` contract is a parse rule, not a format** *(reshaped 2026-07-17 — the strict `<binary> <semver> …` format was over-firm: stow, mise, and go each violate it, so it was never established practice; M12, §13 #22)*. The rule: **the first line of `--version` output contains the tool's own version, as the first semver-shaped token on that line.** Consumers: the release smoke (substring grep — already format-agnostic) and D28's ensure-parse. `<binary> <semver> …` survives only as **non-load-bearing house style** for greenfield tools, yielding to stronger conventions (e.g. GNU-clone fidelity — a byte-faithful `gostow (GNU Stow-compatible) version 0.4.0` still parses). Escapes, sanctioned but unbuilt: `VERSION_ARGS`/`VERSION_REGEX` as config-block variables (D6-compatible) the day a real tool needs them; a tool with no version report at all opts out cleanly — ensure degrades to force for it, documented (M3/D3) |
| **D31** | **The canonical script is truncation-safe**: all logic in functions, one trailing `main "$@"` (§6.5). Established practice — mise.run and rustup both do it; neither shipped script does |
| **D32** | **Resolve "latest" via the `releases/latest` redirect, not the JSON API** (§6.5). The API is rate-limited at 60/hr/IP unauthenticated and fails behind shared egress — exactly where bootstrap runs |
| **D33** | **`--help` is a `usage()` heredoc; never read from `$0`** (§6.6). The shipped scripts' self-read idiom prints a `sed` error and **exits 0** under `curl \| sh -s -- --help` — verified 2026-07-17. Replaces §13 #20's endorsed-but-broken idiom |
| **D34** | **The artifact shape is a named contract** (below). Asset `name_template`, checksums filename, archive-internal `man/` + `completions/` layout, and a `linux_amd64` build all live in **four per-consumer GoReleaser files** and are consumed by the installer, the verify job, the smoke, and D20's detection — uniform today only by copy-paste. D30's original disease, found by auditing for it (M12). Stated once, asserted in `release-dryrun` |

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
Re-verified 2026-07-17, and it is stronger now: mise 2026.7.7 with default settings reads
**neither** file — `idiomatic_version_file_enable_tools` is empty by default, so even
`.go-version` needs opt-in.

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

**D34 — the artifact-shape contract, spelled out.** What every consumer's GoReleaser
config must produce, because four things already depend on it:

| element | shape | consumed by |
|---|---|---|
| archive name | `{{ .ProjectName }}_{{ .Tag }}_{{ .Os }}_{{ .Arch }}.tar.gz` | installer download; verify job (`release.yml:122`) |
| checksums name | `{{ .ProjectName }}_{{ .Tag }}_checksums.txt` (+ `.sig`/`.pem` beside it) | installer F4/F5; verify job |
| archive internals | binary at root; man pages under `man/`, completions under `completions/` | installer install step; D20's detection |
| build matrix | `linux_amd64` exists | verify job's fixture choice; the smoke |

Today this holds in all four repos **by copy-paste, with no assertion** — the exact
pattern D30 had. Unlike D30 it can stay firm: every side of the contract is a file we
author. The work: state it in the canonical installer's header, and assert it in
`release-dryrun` (which already builds a snapshot — checking the produced asset names
against the contract is a few lines). A consumer whose GoReleaser config drifts then fails
its own dry-run, not a user's install.

**The firmness audit (M12), so it isn't re-run without new evidence.** After D30 proved
over-firm, every stated requirement was re-examined with the same question — *is this firm
because it must be, or because it was written firmly?* Softened: D30 (→ parse rule);
found-and-named: D34, the output-level env var's namespacing (§6.5). **Kept firm, each for
a stated reason**:

| requirement | why firmness is correct |
|---|---|
| F4 checksum-or-abort | Security floor; a skip flag would be an integrity bypass one typo away. The ecosystem split (uv skips) is recorded in findings §2 — we picked the larger, safer camp deliberately |
| F3's `~/.local/bin` default | The *default* is the contract rc snippets bake; the dir itself is fully tunable (D9/M1) — the escape valve already exists |
| Never free the `rocne` namespace (§9) | Security invariant; any softening re-opens the squatter chain |
| D34 artifact shape | Both sides of the contract are files we author; internal firmness costs no one anything and an assertion catches drift |
| D6's no-template-branches rule | The one rule holding the generator door shut; escapes go through config variables, which is the sanctioned valve |

### 7.2 Still open

| # | question | recommendation | blocks |
|---|---|---|---|
| **Q3** | **Propagation mechanism.** How do changes reach 4 consumer repos? | **Manual, and the case for the robot weakened on review**: the corrected §9 inventory makes migration-day propagation two vendored files at n=4 — comfortably manual. Automation needs a cross-repo PAT — a new supply-chain surface **in the repo holding the signing keys** — for no remaining simultaneity need. Revisit only if consumer count grows | #1 (may split) |
| **Q12** | **Tag discipline / blast radius.** All 4 consumers pin `@v0.1.1`, the only tag ever cut, by hand, with no release-please here | **Promoted to its own work item (§5)**: release-ci gets a release-please config and follows D19 reflexively. The can/should verdicts on consumer-side pinning remain #3's | #3 |

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
5. **Size, resolved on review (M10)**: the criterion is not "less" but *excellence per
   unit of machinery*. The 2026-07-17 review cut what failed that test (§6.11's container
   layer, #3's scope, #2, the propagation robot) and kept what passes it (the bats floor
   matrix, four output levels, D26, D29–D32). New additions must pass the same test.

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
land and propagate **before** the move.

⚠️ **Corrected inventory (2026-07-17 review; §13 #16)**: an earlier revision claimed the
identity was hardcoded in *"8 files across 5 repos, four of them consumer
`release-dryrun.yml` signing gates"*. **Grep says otherwise**: every `release-dryrun.yml`
pins `${{ github.repository }}` — a context expression that **self-adapts on transfer** —
and each file's header says explicitly that it does not validate the central identity. The
true inventory is **4 literal sites in 3 files across 3 repos**:

| file | sites |
|---|---|
| `release-ci/.github/workflows/release.yml` | :130 (cosign regexp), :138 (`--signer-workflow`) |
| `gostow/install.sh` | :149 |
| `dot-dagger/install.sh` | :155 |

Smaller and more tractable than feared: after D25, migration day touches **two sites in
release-ci plus one vendored config value**. (The separate count of **8 `@v0.1.1`
`workflow_call` references** — 2 per consumer × 4 — is correct, and is a different
question: whether `uses:` refs survive transfer redirects. Still unverified; see below.)

**The other channels that bake `rocne` into user machines** (2026-07-17 review; the §3
durable-artifact inventory had missed the most durable class):

- **apt/dnf sources** — every package-manager machine holds a **root-owned
  `sources.list.d` entry** for `dl.cloudsmith.io/public/rocne/releases/…`, written by
  Cloudsmith's setup script. If the migration moves the Cloudsmith slug, those machines
  don't fail — they **silently stop updating**, which is worse. Either the slug is part of
  the floor, or the migration includes a Cloudsmith redirect/dual-publish story.
- **Homebrew** — casks publish to `rocne/homebrew-tap` (verified in gostow's GoReleaser
  config); `brew` operations reference it from user machines. Git-level redirects cover
  this *only* under the never-free-the-namespace constraint.
- **Go module paths** — `go install github.com/rocne/gostow@latest` is an advertised
  channel, and module path is identity: after transfer, either the `module` line stays
  `github.com/rocne/…` forever (works via redirect, permanently coupled to the old name)
  or it changes (breaking every existing `go install` and import). Decide which, in #11,
  before the move.

**The rule that finds these**: *enumerate every string a user's machine stores that
contains the word `rocne`*, per channel — rc snippets, `sources.list.d`, brew taps,
`go.mod` module lines, `mise.toml` backends, workflow `uses:` refs. That enumeration **is**
the floor's real inventory, and #11 should carry it as a checklist.

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
Four literals in three repos become one vendored value plus two sites in release-ci's own
`release.yml`. This remains a strong argument for #1 — but with the corrected inventory it
**weakens the case for the propagation robot**: migration-day propagation is two files at
n=4, comfortably manual (Q3).

**Also unverified, and load-bearing**: whether GitHub's transfer redirects cover
`raw.githubusercontent.com` and `workflow_call` refs, and for how long. Do not assume.
Redirects are void if the old namespace is re-registered.

## 10. Needs downstream hasn't articulated

§2's third rule, made concrete. **Nothing in this list was asked for. Everything in it is
needed.** This is the section to grow — it is where the system stops being a request queue
and starts being a design.

| # | what they'd have asked for, had they seen it | affected | status |
|---|---|---|---|
| 1 | **The org migration will abort every install on every machine with cosign** — the Fulcio identity is pinned to `rocne` and hard-fails (4 sites in 3 files across 3 repos — inventory corrected 2026-07-17), and vendored scripts update on merge, not on release | all | #11, §9 |
| 2 | **Never free the `rocne` namespace** — or a squatter can have Fulcio *legitimately* sign as us, and serve the URL that rc snippets pipe into `sh` | all, permanently | #11, §9 |
| 3 | **Your release job installs unpinned Python beside your signing key** — `pipx install cloudsmith-cli` resolves 17 transitive deps fresh, in the job that already has `GPG_PRIVATE_KEY` on disk | all | #4 |
| 4 | **Your versioning tells Cargo/npm-minded users that every feature is a breaking change** — `feat → minor` at 0.x, when both ecosystems read minor-at-0.x as *breaking* | gostow, dot-dagger, hud | #8 |
| 5 | **`command -v` alone never converges** — the presence check dstow asked for reinstalls forever if the install dir isn't on `PATH` | dstow | D16 |
| 6 | **Your rc snippet hardcodes a constant it doesn't own**, and nothing tells it when that constant changes | dstow | D26 |
| 7 | **`printf '%q'` isn't POSIX** — a latent bug on the error path of a script whose entire job is being safe to pipe into `dash` | dot-dagger | D12 |
| 8 | **Nothing on your install path consumes the provenance you pay to produce.** We emit SLSA attestations and cosign-signed checksums; `install.sh` checks a checksum and treats cosign as optional. **mise's `github` backend verifies those attestations by default** — the only thing that ever has | all | #7 |
| 9 | **Your pipeline has never run** — wired to release-ci, zero releases cut, so the layout, secrets, and signing gate are all untested | hud | §1, D27 |
| 10 | ~~Four copies of the signing identity in `release-dryrun.yml`~~ **Withdrawn (2026-07-17)** — those files pin `${{ github.repository }}` and self-adapt; the claim failed a grep (§9, §13 #16) | — | — |
| 11 | **Your signing job trusts five mutable tags** — every action in the job holding the GPG key and OIDC is a movable ref; a retag upstream is the same hole class as #4's unpinned pipx | all | D29, #4 |
| 12 | **Every apt/dnf machine holds a root-owned source entry baking the Cloudsmith slug** — on a slug change it silently stops updating rather than failing. The durable-artifact inventory had missed its most durable member | all apt/dnf users | §9, #11 |
| 13 | **`brew` references `rocne/homebrew-tap` from user machines**; covered by transfer redirects only while the namespace is never freed | brew users | §9, #11 |
| 14 | **Go module paths don't migrate** — `go install github.com/rocne/…` is advertised, and the `module` line either stays `rocne` forever or breaks existing installs | go-install users | §9, #11 |
| 15 | **`$TOOL --version` output is already a cross-repo contract with zero documentation** — the release smoke greps it, D28's version match will parse it. Resolved as a **parse rule** (first semver on line 1), not a format — a strict format was over-firm (M12) | all | D30 |
| 19 | **Your GoReleaser config is load-bearing for four other things** — asset names, checksums name, archive layout, and a linux_amd64 build are consumed by the installer, verify job, smoke, and D20, and nothing asserts any of it. D30's disease, second instance | all | D34 |
| 16 | **Neither shipped installer is truncation-safe** — a dropped `curl \| sh` connection executes a prefix of the script. mise.run and rustup wrap everything in functions with one trailing call | all curl\|sh users | D31 |
| 17 | **"Latest" resolution burns an unauthenticated API call** rate-limited at 60/hr/IP — it fails behind CI and office NAT, exactly where bootstrap runs | CI, shared-egress users | D32 |
| 18 | **Checksum-without-cosign is integrity, not authenticity** — the checksums file rides the artifact's own origin; F4 defends against corruption, not compromise. Users deserve the honest framing (and it sharpens #7's pitch: mise verifies attestations by default) | all | §6.9 |

**How this list gets longer**: by testing the plan against things nobody asked about. #11
exists because someone asked whether we had considered the org migration — it had been
recorded as a standing constraint for eight rounds and never once checked against a decision.
**That question should be put to every standing constraint in this document.** Entries
12–14 fell out of asking one mechanical question — *"enumerate every string a user's
machine stores that contains `rocne`"* — once per channel (§9). Ask that question of any
new channel before endorsing it.

## 11. Maintainer directives

**The authority behind this document.** §2's posture is not an inference the agent drew from
the code; it was given. Recorded here because a reader who doesn't know which decisions came
from the maintainer and which the agent invented cannot evaluate either.

Recorded from working sessions on **2026-07-16** (paraphrased where not quoted; the
conversation is the source of truth).

| # | directive | drove |
|---|---|---|
| **M1** | **On the install dir**: *"this is the FLOOR. 'Not tunable' is wrong. It can be tunable. The default should be the XDG bin directory, but there is absolutely not a requirement to make this non-tunable."* | D9, and the whole floor-vs-ceiling distinction (§3) |
| **M2** | **On output**: *"`--quiet` or `--silent` is fine to suppress output… we should have 4 output 'volumes': verbose (everything and details), 'normal' (announce success, announce failure), 'quiet' (failure and changes, not no-op) and 'silent' (nothing except maybe catastrophic abort message)."* Plus: *"Actual terminology and details are up to your discretion. **Use best practices and standard terminology.**"* | D10, §6.5 |
| **M3** | **On opt-out**: *"downstream should be able to opt in/out of any feature. E.g. they should not need to stub docs generation and supply a dummy function to make the system work, they should be able to just opt out cleanly. **Same for all else.**"* | D3, §3, and #3's fourth column |
| **M4** | **On this document's audience**: *"These are for you, humans will not read later. Our readme will be clear and that is enough."* | Why the issues and this file are dense and agent-facing, and why the README is the human surface |
| **M5** | **On established practice**: *"**I want to follow established practices. I do not want to reinvent wheels.** If we need to change some of what we do, that is fine. We can namespace our env var."* | D8, D19, and the whole external-survey effort. **The single most load-bearing directive** — it triggered the surveys that killed three of our assumed conventions |
| **M6** | **On rejecting downstream**: *"keeping current system is not top priority. If we have weird stuff, if we required weird stuff, then it is acceptable to reject downstream request with a '**no, but here is what we will provide, and here is how you use it instead of what you asked for, and here is why it is better**'"* | §2's counter-offer, D9, D16 |
| **M7** | **The reframe** (supersedes any deference in earlier drafts): *"The downstream context is intended to give us context. If we need to make changes downstream, that is ok. **If gostow's custom script isn't compatible then we change it.** WE are trying to make an excellent system that meets the needs of downstream, **including the needs they aren't aware of**, and **rejecting their declared needs if we can see a better approach**."* | §2 in full, §10, and the re-derivation of D11/D20/D21/D26/D27 |
| **M8** | **On the org migration**: asked whether the intent to migrate from the personal account to a GitHub org with shared infra had been kept in mind. It had been *recorded* and never *tested*. | #11, §9 — the question found a live break |
| **M9** | **On process**: *"We are not going to begin work yet. I want to resolve the whole plan. And this plan will be a proposal that I'll check with a bigger model."* | Why this is a proposal, why §0 exists, why nothing is implemented |
| **M10** | **On scale** (2026-07-17, during review): *"I want to do excellent, not less… make this excellent, principled, and elegantly ergonomic. And give my tools consistency. I will use my tools in my day to day."* | The review's cut criterion — complexity is cut when it doesn't buy excellence, not because it is effort. D30 (consistency as a deliverable), the §6.11 container cut, #3's shrink |
| **M11** | **On weighting** (2026-07-17): the plan was ~4 hours of work with an agent, not a week — *"I don't want you to grant it the weight of a whole week of work."* Handoffs from prior agents are to be checked for embedded bias, not obeyed | Why the review re-verified VERIFIED tags rather than trusting them; the note below |
| **M12** | **On contracts** (2026-07-17): challenged D30's strict format — gostow as *"a clean clone of stow"* might need to mimic stow's own output — *"I worry that it is too strict… What if my project is really strict and I simply cannot accommodate `--version`? Do we generalize or declare that out of scope?"* | D30's reshape (parse rule; format demoted to house style; escapes sanctioned but unbuilt; clean opt-out with defined degradation), and the audit for over-firm requirements that found D34 and the namespaced output env var |
| **M13** | **On uniformity** (2026-07-18): *"all repos get the same treatment. All repos get the same release system. All repos must become consistent; repos conform to the authoritative release process… we should not have exceptions."* Given when the agent left hud out of the installer-vendoring round citing §14.3's first-release gating. The audit (#3) is the instrument that determines what conforming means per element; any per-repo divergence must be a verdict it rules explicitly, never a default that accretes | §14.3 (amended — hud vendors with the family), the four-consumer vendoring round, #3's standing as overdue rather than optional |

**Note the pattern in M1, M2, M5, M6, M7**: every one of them *loosened* a constraint the
agent had adopted from a downstream document or invented. **Do not extrapolate this into a
standing bias** (an earlier revision told the next agent to "assume that direction
continues" — withdrawn on review): a posture is a decision, not a trend line, and each new
rejection of a downstream need still owes the full counter-offer discipline (M6). What a
future agent *should* carry forward is the mechanism, not the direction: when a constraint
feels inherited rather than derived, surface it to the maintainer and check it.

## 12. Options considered

Recorded so they are not re-litigated without new evidence, and so a reviewer can see the
shape of what was rejected. **Dismissal reasons are load-bearing** — several of these are
good ideas that fail for one specific, checkable reason.

### Delivery and tooling

| option | verdict | why |
|---|---|---|
| **godownloader** — generate `install.sh` from `.goreleaser.yml` | **Dismissed** | Archived 2022-01-14, no successor shipped. The closest thing to our ask that has ever existed, and it died of maintainer bandwidth — its author still wants generation, integrated (§6.1, §6.3, §13 #19) |
| **Wait for `goreleaser` to build it** | **Dismissed** | [#4565](https://github.com/goreleaser/goreleaser/issues/4565) open since 2024, author still intends it, go-task still on the dead generator. Waiting is indefinite |
| **`dist`** (ex-cargo-dist) | **Dismissed** | Actively maintained (premise correction: *not* wound down). But the installer is a per-release regenerated artifact, not a stable vendored file; no presence-check/`--force`/`--version`; imports a Rust release tool |
| **instl.sh, webi** | **Dismissed** | Require a third party **reachable at install time** — a different trust and availability model from a script in our own repo |
| **goblin.run** | **Dismissed, hard** | **Recompiles our Go source on its servers** rather than serving our signed artifacts. Defeats the entire cosign/SLSA chain |
| **ubi, eget, aqua, binenv, cargo-binstall** | **Dismissed** | All require a manager pre-installed ⇒ none serve the fresh-machine case, which is the only case `install.sh` exists for |
| **A template + render step** | **Dismissed** | It is a generator with extra words (D6). The whole objection that killed godownloader |
| **A thin-shim installer / a URL on release-ci itself** | **Dismissed** *(upstream, dstow#28)* | Two hops; the whitelisted URL wouldn't be the one that must be reachable. Recorded because it was already considered and settled |

### mise

| option | verdict | why |
|---|---|---|
| **mise as install channel** (`github` backend) | **Adopted** (#7) | Zero config, zero registry entry, verifies our attestations. **Empirically tested**, not assumed |
| **mise as a replacement for `install.sh`** | **Dismissed** | mise must itself be installed. On a fresh machine there is no mise either. The ordering runs opposite to the naive take |
| **mise in CI** (#6) | **Propose decline** (D24) | Can't read `go.mod` (D23), so Go is excluded; the rest is achievable without it. And it substitutes *mise's Rust reimplementation* of cosign/SLSA verification for the audited upstream binaries — in a pipeline whose product is provenance |
| **mise `go:` backend for distribution** | **Dismissed, hard** | Builds from source. **Silently discards the entire signed-release pipeline** |
| **mise registry short name** (`mise use -g gostow`) | **Not viable** | mise's registry has a "reasonably popular" bar these tools won't clear. `github:rocne/gostow` is the invocation |

### Installer behaviour

| option | verdict | why |
|---|---|---|
| **`--update` / self-update** | **Dismissed** | Package managers and mise own upgrades. `install.sh` puts a verified binary on a bare machine; that's all (§6.10) |
| **`--require-signature` as floor** | **Demoted, not dismissed** | Above the floor. Mandatory cosign would fail bootstrap on exactly the fresh machines bootstrap serves (F5) |
| **`command -v` alone** (dstow B6) | **Rejected** | Never converges — reinstalls forever if the install dir isn't on `PATH` (D16). Context-bound fairness note in §6.5: it *is* correct inside B1's snippet, which fixes `PATH` first |
| **`--version` implies force** (dstow B6, was F2) | **Rejected** (D28) | Contradicted F1 outright, and pinned-version scripts never converge. `--version` = ensure exactly; only `--force` is unconditional |
| **Install-path check alone** (mise's choice) | **Rejected** | Silently shadows an apt-managed install (D16) |
| **Non-overridable `~/.local/bin`** (dstow B6) | **Rejected** (M1) | Both shipped scripts already contradict it. Countered with a stable default + override (D9) |
| **`--dir`** | **Dismissed** | Incumbency only. `--install-dir` pairs with the env var (D11) |
| **Bare `INSTALL_DIR` as deprecated fallback** | **Dismissed** | **Preserves the exact collision bug namespacing exists to fix** (D21) |
| **`INSTALL_MAN` config var** | **Dismissed** | Encodes today's accident as config. The archive already knows (D20) |
| **dot-dagger's `VALID_TOOLS` positional** | **Dismissed** | Dead generality — a one-entry list (D12) |
| **Accept the rc-snippet coupling** | **Dismissed** | Surrender dressed as pragmatism. We own the snippet (D26) |

### Pipeline

| option | verdict | why |
|---|---|---|
| **`pipx install cloudsmith-cli==X.Y.Z`** | **Insufficient** | Pins 1 of 18. The other 17 resolve fresh. **This was our own first proposal and it was wrong** (#4) |
| **`--require-hashes` + compiled requirements** | **Adopted** (D18) | The only option that closes the transitive tree. Previously dismissed by us as over-engineering |
| **Delete `cloudsmith-cli`; `curl` the API** | **Deferred, promising** | Cloudsmith's upload is **two-step** (PUT → identifier → POST), so ~15 lines of bash + `jq` we'd own. Bigger win than any pin; a design change, not a bug fix (Q5/D18) |
| **mise to fix the pin** | **Dismissed** | `pipx` backend is version-only in the lockfile. Doesn't verify the tree either |
| **Version guard as `workflow_call` input** (#2) | **Likely can-but-shouldn't** | 2 of 4 sites, in 1 of 4 consumers. The "duplicated across consumers" premise was false |
| **Propagation robot** (Q3) | **Deferred, tension acknowledged** | Needs a cross-repo PAT *in the repo holding the signing keys*, for 4 repos. But §2 and §9 both argue for it |

## 13. Mistakes made

**Read this before trusting anything above.** The pattern is consistent and worth knowing:
**every error here came from accepting a claim instead of checking it**, and every one was
caught by checking. This document is the product of a process that has been wrong repeatedly.

### Ours

| # | mistake | how it was caught | cost if it had shipped |
|---|---|---|---|
| 1 | **Reported "the install dir is not tunable" as fact.** Read it out of the issue text, repeated it to the maintainer as a requirement | Maintainer corrected (M1). Both shipped scripts already contradicted it — a 30-second grep | A non-overridable install dir, worse than what we already had |
| 2 | **Claimed "a successful install always announces itself" was an invariant** | Maintainer corrected (M2) — it's default-level behaviour, not a law | No `--quiet`. Unusable in scripts |
| 3 | **Said `pipx install cloudsmith-cli==X.Y.Z` closes the supply-chain hole** | Checked PyPI: 17 of 18 deps are open ranges | A "fixed" issue that fixed ~1/17th of the surface |
| 4 | **Dismissed `--require-hashes` as "more machinery than this warrants"** | Same check. It is the *only* thing that closes it | The actual fix, rejected on vibes |
| 5 | **Asked whether to retry a dead research agent, then didn't** | Maintainer asked *"did we resume that research?"* | The single most important thread — "has this been solved?" — stayed unanswered for a round |
| 6 | **Used hud's missing `install.sh` as evidence for the opt-out doctrine** | `gh release list`: hud has **0 releases**. Its absence is "not yet", not "declined" | A design principle propped up by a fact that wasn't one |
| 7 | **D6 claimed the canonical script is "executable with release-ci's own values"** | release-ci **ships no binary**. The sentence was incoherent | A design whose central artifact can't exist |
| 8 | **Claimed vendoring "survives infra reorgs"** | Tested against the migration: the vendored script **hard-aborts** on the signing identity | The stated rationale for the delivery model, false in the way that matters |
| 9 | **Treated the org migration as a footnote for 8 rounds** despite it being a recorded constraint in #3 | Maintainer asked directly (M8) | Discovering #11 *during* the migration: every install breaking at once |
| 10 | **Wrote "requirements are inputs, not mandates" while deferring to incumbency in 6 places** | Maintainer reframed (M7); grep found all six | Two wrong decisions (D11, D21) and two mis-shaped ones (D20, D26) |
| 11 | **Justified the floor as protecting consumers from us** | The reframe. It's backwards — consumers are ours to change; the floor is for *users'* machines | The wrong mental model, which is what produced #10 |
| 12 | **Cited the dstow survey's "identical except X" claim in #1's body** before diffing the scripts | Ran the diff. There's a second structural divergence | A canonical design built on an unverified comparison |
| 13 | **Briefed a research agent that axodotdev had "wound down"** — a false premise, stated as fact | **The agent corrected me.** `dist` is actively released | A candidate dismissed for a reason that wasn't true |
| 14 | **Edited `main` while the PR it depended on was unmerged** | Register showed D1–D24; D25–D27 and §10 had silently failed to apply | A document with dangling references to sections that don't exist |
| 15 | **Reported dot-dagger at 100 releases** — a `--limit` truncation read as a total, inside the census §13 exists to protect | Review re-ran with `--paginate`: **141** | A census cited as the evidence floor, wrong about the most-released consumer |
| 16 | **Claimed the Fulcio identity was hardcoded in "8 files across 5 repos, four of them `release-dryrun.yml` gates"** — written *after* the verify-cross-repo-claims rule, containing "four…four…four", never grepped | Review grepped: dryrun files pin `${{ github.repository }}` and self-adapt. Real inventory: 4 sites, 3 files, 3 repos | A migration plan sized 2.7× too large; §10 carried a work item for a problem that doesn't exist |
| 17 | **Specified the config block as `TOOL` = "binary name = repo slug"** — false for dot-dagger (repo `dot-dagger`, binary `dotd`), which both shipped scripts already encode as separate `REPO`/`TOOL` | Review read the consumer the block claimed to serve | The design's central artifact unable to express 1 of 4 consumers on day one |
| 18 | **Adopted dstow B6's "`--version` implies force" verbatim into F2** while writing F1's "matches `--version` → exit 0" — a direct contradiction, and incumbency again (§2 rule 2 applied to everything except this clause) | Review worked the state machine: present-at-requested-version had two answers | Pinned-version scripts reinstalling forever — failing D16's own convergence principle |
| 19 | **Claimed caarlos0 "doubted the approach, not just the maintenance burden"** — godownloader#161 is titled *"Call for Maintainers"* and his stated alternative was generation *integrated into goreleaser* | Review read the full primary text | D6 argued against an objection its author never made, leaving the real argument (scale, ownership) unstated |
| 20 | **Endorsed the shipped scripts' `--help` self-read idiom as "good"** — `sed "$0"` cannot work when the script arrives on stdin, which is the documented invocation | Piped the script into `sh -s -- --help`: `sed: can't read sh` — **and exit 0** | The canonical installer vendoring a help flag that errors uselessly, and reports success, in its primary mode (D33) |
| 21 | **Applied the #19 correction to §6.3 but left the retracted claim standing in §6.1 and §12** — the same mistake-#14 drift class, committed *in the revision that documented mistake #14* | Self-review pass re-read the whole document after editing | Two sections contradicting the correction they sit beside |
| 22 | **Specified D30 as a strict output format and called it a contract** — invented under the banner of consistency, hours after writing that strictness must trace to established practice (M5). stow, mise, and go each violate it | Maintainer challenged (M12); three `--version` invocations on the maintainer's own machine falsified "established" | Either forced nonconformance on a faithful GNU-style clone, or an immediate exception that hollowed the "contract" out |

### Inherited — sources that failed verification

| source | claim | reality |
|---|---|---|
| dstow release-installer survey §2.1 | *"dot-dagger's install.sh is essentially the same script minus the man page/completions block"* | **False.** A second structural divergence in the argument parser. It ran no diff |
| dstow release-installer survey §1 | *"both gostow and dot-dagger have a hand-rolled refuse-v1.0.0 guard"* | **False.** dot-dagger has none. Zero hits |
| dstow DESIGN.md §9 | advertises requirements **"B1–B9"** | **B7 and B9 were never written into it** — they exist only in an issue ledger |
| our own conventions survey | *"errors to stderr, info to stdout — the one true, unanimous convention"* | **False.** Falsified by its own closest precedent: mise and Volta route info to **stderr** |
| our own mise survey | *"closing the cloudsmith-cli gap is the strongest case for mise in CI"* | **False.** The `pipx` backend is version-only. It closes nothing |

### The rule this produced

**D14: verify before citing.** Structural descriptions in these documents have held up.
**Cross-repo comparative claims have not** — five of five checked were wrong. The cheap tell
is a sentence containing *"identical"*, *"both"*, *"all"*, or *"every"* about more than one
repo. Check it before building on it.

### For the reviewer

Two things follow from this list.

1. **The corrections came from checking, not from thinking harder.** Every mistake above
   survived multiple careful re-readings and died to one command — a grep, a diff, a
   `gh release list`, a `curl` to PyPI. If you doubt a claim here, the useful move is to run
   something, not to reason about it.
2. **The agent's confident prose is not evidence.** This document is written in a declarative
   register throughout. Items 1, 2, 3, 4, 7, 8, and 11 above were written in exactly that
   register and were wrong. Weight the VERIFIED tags in
   [`reference/findings-2026-07-16.md`](reference/findings-2026-07-16.md), not the tone here.

## 14. Consumer adaptation plans

§2 rule 1, made operational: we change downstream freely, so the design owes each consumer
its **exact change list** — what changes, why, and in what order. Verified against each
repo's `origin/main`, 2026-07-17. These sections become per-repo tracking issues in the
roadmap, with the block-dependencies shown.

**Applies to every consumer (so it is said once):**

- **`release-dryrun.yml`: no action, ever, for the migration.** All four pin
  `${{ github.repository }}` and self-adapt (§9). Recorded here so nobody "fixes" them.
- **Workflow refs stay `@v0.1.1`** until release-ci cuts its next tag — by hand or via the
  promoted Q12 work item; then each consumer bumps its 2 `uses:` refs.
- **D30 conformance**: the first line of `--version` must contain the tool's own version
  as its **first semver-shaped token** — a parse rule, not a format. (`<binary>
  <semver> …` is house style for new tools only, and yields to stronger conventions.) The
  release smoke already greps for the version (`release.yml:201`), so released tools pass
  today — the change is *asserting the parse rule* in each repo's CI so it can't drift.
- **D34 conformance**: the GoReleaser config keeps the artifact-shape contract (asset and
  checksums name templates, `man/`/`completions/` layout, linux_amd64 build); asserted in
  each repo's `release-dryrun` once release-ci ships the check.
- **Vendored-file changes arrive as ordinary PRs** in each consumer, reviewed there,
  shellchecked there (D5). Nothing lands on release day.

### 14.1 gostow — mature consumer, hand-rolled installer retires

*Unblocked now:*

1. **#8**: flip `bump-patch-for-minor-pre-major` → `true` in `release-please-config.json`
   (one line; both bump flags verified present).
2. **D30**: current output `gostow 0.4.0 (GNU Stow 2.4.1 compatible)` conforms to the
   parse rule — its own version precedes the Stow-compat `2.4.1`, and **that ordering is
   the load-bearing part**; add the parse-rule assertion to CI. (If gostow ever adopts
   byte-faithful GNU formatting, `gostow (GNU Stow-compatible) version 0.4.0` also parses.)

*Blocked on release-ci #1 (canonical installer exists):*

3. **Replace `install.sh`** (221 hand-rolled lines) with the vendored canonical; config
   block `REPO="rocne/gostow"`, `TOOL="gostow"`. Net behaviour changes, for the release
   notes: **`--dir` → `--install-dir`** (D11); **bare `INSTALL_DIR` dropped** →
   `GOSTOW_INSTALL_DIR` (D21, clean break); presence check now default-on (F1/D16);
   `--version` = ensure (D28); gains truncation safety (D31), redirect-based latest (D32),
   a `--help` that works when piped (D33 — the current one errors under `curl | sh`),
   and the migration-proof `SIGNER_REPO` (D25). Man pages + completions: gostow ships them
   in its archives, so D20's detection preserves today's behaviour with zero config.
4. **Docs sweep**: `README.md` and `docs/SPEC.md` document `--dir`/`INSTALL_DIR`
   (verified) — update both; add the mise stanza (#7).

### 14.2 dot-dagger — the consumer that reshaped the config block

*Unblocked now:*

1. **#8**: same one-line flip (flags verified present).
2. **D30**: assert the parse rule for `dotd` in CI (141 releases have passed the smoke's
   grep, so conformance is near-certain; the assertion is the new part).

*Blocked on release-ci #1:*

3. **Replace `install.sh`** (186 lines); config block `REPO="rocne/dot-dagger"`,
   `TOOL="dotd"` — the exact pair that forced the block's `REPO`/`TOOL` split (§6.3).
   Removals, per D12: the `VALID_TOOLS` positional (dead generality, one entry) and with
   it the **non-POSIX `printf '%q'`** on its error path. Same release-notes items as
   gostow (`--install-dir`, `DOTD_INSTALL_DIR`, presence check, D28).
4. **Docs sweep**: `README.md`, `docs/getting-started/index.md`, `docs/reference/dotd.md`
   reference `install.sh` and its flags (verified) — remove any positional-tool usage,
   update flags; add the mise stanza (#7 — noting mise verifies dot-dagger via the SLSA
   path, `findings §5`).
5. **Man/completions**: ships none today (archives are binary-only — verified in
   `.goreleaser/dotd.yaml`). No action; D20 means the day they enter the archive, the
   installer picks them up with no vendored change.

### 14.3 hud — untested consumer; conforms with the family (M13)

⚠️ **Amended 2026-07-18 (M13).** This section previously gated everything on hud's
"first release intent" — an exception the maintainer has eliminated: all repos get the
same treatment and conform to the authoritative release process. What is genuinely
*sequenced* before a first release (secrets, a green dryrun — item 3) stays sequenced;
nothing else waits on intent.

1. **Layout**: move root `.goreleaser.yaml` → `.goreleaser/hud.yaml` for family uniformity
   (D27: it has never been run by release-ci, so this is free).
2. **#8**: same one-line flip (flags verified present).
3. **Pre-first-release checklist**: secrets set by hand (`GPG_PRIVATE_KEY`,
   `CLOUDSMITH_API_KEY`, `HOMEBREW_TAP_GITHUB_TOKEN` — the three dstow's design also
   names); D30 parse rule asserted (the smoke will grep it on release day); a green
   `release-dryrun` run.
4. **Vendor `install.sh` with the family** (`REPO="rocne/hud"`, `TOOL="hud"`) — M13
   removed the on-first-release gating this item carried. Safe to ship before any release
   exists: a 0-release repo's vendored installer exits 1 with an honest *"no published
   release yet"* (behavior added by the pre-vendor review fixes, #34). The mise stanza
   still lands with the first release — mise has nothing to install before one exists.

### 14.4 dstow — greenfield consumer; its design doc needs amending

dstow's first release blocks on release-ci #1 (its B3, no fallback — dstow's choice, §2).

1. **Vendor `install.sh`** (`REPO="rocne/dstow"`, `TOOL="dstow"`) **and `snippet.sh`
   beside it** (D26).
2. **Implement `dstow snippet rc` as a `go:embed` reader of the vendored `snippet.sh`.**
   Verified 2026-07-17: **no snippet code exists yet** — this is greenfield, not rework,
   and it satisfies dstow's own B2 ("real files, diffable, shellcheck-able; never string
   literals") better than an independent hardcoding would.
3. **Amend dstow `DESIGN.md` §9** to match the counter-offers it accepts — its design doc
   binds *dstow*, so the text must follow: B6's `command -v` → the dual check (D16); B6's
   "`--version` implies force" → ensure-semantics (D28); B6's "`~/.local/bin` bound as
   contract" → tunable dir with the *default* as the contract (D9/M1, which both shipped
   siblings already practise).
4. **Out of #8's scope**: `initial-version: 1.0.0` is deliberate (verified) — no bump-flag
   change.
5. **Pre-first-release checklist**: same as hud's item 3.

### 14.5 sorta — no adaptation, and now we know why

Verified 2026-07-17 from sorta's own workflow: it is **private, with no distribution
pipeline** — its `release-please.yml` states the tag + GitHub release *is* the whole
release. Staying off release-ci is **correct by design**, not a gap; this closes the
question `findings §4` said nobody had asked. Revisit only if sorta ever ships binaries to
machines it doesn't own.
