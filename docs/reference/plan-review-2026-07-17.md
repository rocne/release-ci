# Adversarial review of the plan of record — 2026-07-17

Reviewed: `docs/DESIGN.md` at `e32c772` (branch `docs/reframe-posture`), with
`reference/findings-2026-07-16.md` and issues #1–#11. Method per the brief: **every
load-bearing claim re-checked by command** against the live repos, GitHub API, PyPI,
mise.run, and primary docs — not re-read. Tags: **VERIFIED** = re-run in this review;
**ANALYSIS** = reasoning over verified facts.

---

## 1. Bottom line

The plan's core holds. D4 (build), D5 (vendor), D6 (config block), D16 (dual presence
check), D19 (downshift), D23/D24 (mise-in-CI decline), D25 (`SIGNER_REPO`), D26 (own the
snippet) all survive adversarial checking — several with *stronger* evidence than the
document claims. Nothing here says "don't build this."

But the review found:

- **One materially false claim**: the org-migration blast radius ("8 files across 5 repos,
  four of them `release-dryrun.yml` gates") is wrong — the real inventory is **3 files in
  3 repos**, and §10's entry #10 describes a problem that does not exist (§2a below).
- **One spec bug that breaks the design's central artifact on day one**: §6.3's config
  block cannot express dot-dagger (§3-D6 below).
- **One internal contradiction in the floor**: F1 and F2 give conflicting answers for
  `--version` against an already-installed tool (§3-D16 below).
- **Eight new candidates for §10**, the largest being mutable action tags in the signing
  job — the same hole class #4 fixes, unmentioned anywhere (§4 below).
- D6's star witness doesn't say what the document claims he said; the decision survives on
  different (better) legs (§3-D6).

---

## 2. Claims that failed re-verification

### 2a. The migration blast radius is miscounted — §9 and §10 #10 are wrong

**The claim** (§9): the Fulcio identity is *"hardcoded in 8 files across 5 repos, four of
them consumer `release-dryrun.yml` signing gates."* §10 #10 repeats it: *"one migration,
four hand-edits, four chances to miss one."*

**VERIFIED false.** Grep of `rocne/release-ci` across all five repos' current `main`:
every `release-dryrun.yml` (gostow, dot-dagger, hud, dstow) pins
`--certificate-identity-regexp "^https://github\.com/${{ github.repository }}/…"` — a
**context expression, not a literal**. It self-adapts on transfer. Each file's own header
comment even says: *"Does NOT validate the central release-ci signing identity (different
workflow file)."*

The true hardcoded-identity inventory:

| file | sites |
|---|---|
| `release-ci/.github/workflows/release.yml` | :130 (cosign regex), :138 (`--signer-workflow`) |
| `gostow/install.sh` | :149 |
| `dot-dagger/install.sh` | :155 |

**3 files, 3 repos.** The migration break (#11) is real — the installers and release-ci's
own verify job do hard-abort — but it is smaller and *more tractable* than stated: after
D25, the fix is two sites in release-ci plus one vendored config value. The separate count
of **8 `@v0.1.1` workflow references** (2 per consumer × 4) is correct; those are a
different concern (do `uses:` refs survive transfer redirects — still legitimately open).

**Action**: rewrite §9's inventory; delete or rewrite §10 #10. Note the irony for §13:
this claim sits in the section written *after* the "verify cross-repo claims" rule, uses
the word "four … four … four", and was never grepped.

### 2b. The consumer census is wrong about dot-dagger

**VERIFIED**: `gh api repos/rocne/dot-dagger/releases --paginate | wc -l` → **141**
releases, not the 100 in §1 (latest v0.11.0 ✓). 100 is exactly what a truncated
`--limit 100` listing returns — a §13-class error inside the census that §13 protects.
Family total is ~148, not "~110". Cosmetic, but fix it: the census is cited as the
evidence floor for everything else.

### 2c. Register/prose drift (mistake-#14 class, still live)

- **D8** says bare `INSTALL_DIR` is *"deprecated"*; D21 and §6.5 say **dropped outright**.
  D8 was never updated after D21 reversed.
- **§6.3's example config block** still contains `INSTALL_MAN` (deleted by D20) and lacks
  `SIGNER_REPO` (added by D25). The block shown is the one the document elsewhere says
  doesn't exist.
- **D17** cites "(§6.10)" for testing; testing is §6.11.

### 2d. What passed (so it's on record)

**VERIFIED this review**: unpinned `pipx install cloudsmith-cli` at `release.yml:89` with
`GPG_PRIVATE_KEY` written to disk beforehand ✓; cloudsmith-cli 1.19.0 declares 17 deps,
exactly 2 exact-pinned (`mcp`, `python-toon`) ✓; godownloader archived ✓;
goreleaser#4565 open, assigned caarlos0, 3 comments with the quoted text ✓; gostow's 4
guard sites at the stated lines and dot-dagger's zero ✓; `v0.1.1` the only release-ci tag,
no release-please config here ✓; hud root-level `.goreleaser.yaml` vs gostow's
`.goreleaser/` dir ✓; all three consumers' release-please bump flags and dstow's
`initial-version: 1.0.0` ✓; dot-dagger `%q` at :60, `VALID_TOOLS`, both scripts' bare
`INSTALL_DIR` + `--dir` ✓; mise.run's install-path-only comment at the stated lines ✓;
Cargo *"left-most non-zero"* and npm *"breaking-change indicator"* quotes ✓; dstow B1/B2/B6
as characterized ✓.

---

## 3. The named weak points

### D6 — right conclusion, wrong star witness

**The document claims** the generator approach's own author "doubted the approach, not
just the maintenance burden," and that our config-block shape "dodges his objection."

**VERIFIED, godownloader#161 in full**: the issue is titled **"Call for Maintainers."**
The body: *"I honestly barely make the time to maintain nfpm and goreleaser. At this
point, I'm not even sure the way we're handling this was a good idea. Maybe it would be
better to make this a pipe on goreleaser?"* — and #4565 is him, in 2024, still *wanting to
build* integrated generation.

**ANALYSIS**: "a pipe on goreleaser" **is still a generator** — generation from build
config, moved in-process. caarlos0 never disavowed generating installers; he disavowed
maintaining it as a separate project on zero bandwidth. So the claim "our shape dodges the
objection that killed godownloader" argues against an objection its author never quite
made. §6.3's "why this survives caarlos0's objection" paragraph over-reads its source.

**Why D6 still stands, on better legs**:

1. **Scale.** One maintainer, four consumers, and (per §6.6) a config surface of ~3
   variables. A generator's costs — render step, template syntax, a test surface over the
   generator itself — buy *nothing* at n=4. This argument needs no dead project.
2. **The compatibility-surface lesson**, properly stated: godownloader owed its users
   fidelity to every GoReleaser feature. We owe four repos we own fidelity to one asset
   layout we control. That asymmetry, not the archive date, is the real moat.
3. The ecosystem-froze evidence (go-task, golangci-lint hand-maintaining frozen output)
   stands as verified and does support "nothing to adopt" (D4).

**The bug — §6.3's block cannot express dot-dagger.** The spec:
`TOOL="" # binary name = repo slug under github.com/rocne/`. But the family's
most-released tool is the counterexample: **repo `dot-dagger`, binary `dotd`**. Binary
name ≠ repo slug, and both shipped scripts already know it (`REPO="rocne/dot-dagger"` +
`TOOL="dotd"`). The block needs **two variables** (`REPO`, `TOOL` — plus `SIGNER_REPO`).
As written, the design's central artifact fails §6.3's own rule ("expressible as variables
in the config block") for 1 of 4 consumers on day one. Trivial fix; embarrassing if it had
shipped; exactly the kind of thing §13 says dies to one grep.

**One more honesty note**: "propagation = a `sed`/`awk` range operation" is itself a tiny
generator. That's fine — but the invariant that keeps D6 honest should be *named in the
script*: everything below the marker is byte-identical across consumers, and any diff
there is a propagation bug. That makes the invariant checkable (a future CI step can
verify vendored copies match canonical below-the-marker), instead of a norm someone
remembers.

### D16 — dual check is right; the `--version` semantics are self-contradictory

**The contradiction**: F1/D16 step 1 — *"if `$INSTALL_DIR/$TOOL` exists (**and matches
`--version` if given**) → status line, exit 0."* F2 — *"`--version vX.Y.Z` installs that
version and **implies force**."* Both cannot hold: tool present at exactly the requested
version → F1 says exit 0, F2 says reinstall. The "implies force" clause is inherited
verbatim from dstow B6 (**VERIFIED**, dstow DESIGN §9.2) — ironic, given §2 rule 2.

**Recommendation (ANALYSIS)**: `--version` should mean **"ensure exactly this version"**
— exit 0 if satisfied, install if not; only `--force` unconditionally reinstalls. The
alternative (implies-force) means any script that pins a version reinstalls on every run —
failing the *convergence* principle D16 itself champions. Rewrite F2; the fix is one
clause.

**The consequence nobody priced**: "matches `--version`" requires the script to *learn the
installed version* — i.e. run `$TOOL --version` and parse it. mise.run can version-compare
only because the server bakes the target version into the served script (**VERIFIED**
today: `installed_mise_version` vs a baked `$version`, and note its skip is **opt-in** via
`MISE_INSTALL_SKIP_IF_EXISTS`, not default). A static vendored script must parse tool
output instead → the `--version` output format becomes a cross-repo contract. It already
is one, silently: the smoke test greps it (`release.yml:201`). See §4 entry 5 — make it
explicit.

**A fairness note on "dstow's ask is simply wrong"**: in the context B6 serves — the rc
snippet — `command -v` is *correct*, because B1's snippet prepends `~/.local/bin` to
`PATH` **before** the guard (**VERIFIED**, dstow DESIGN §9.1). Non-convergence bites only
custom-dir direct invocations. The rejection stands (the installer must be correct in
every context, not just under its snippet), but the document should stop calling the ask
senseless; it was context-bound, and the context was coherent.

**Edge cases the resolved design should enumerate** (currently unstated): present at
install path *at a different version*, no flags → status line should *name* the installed
version so exit-0 isn't mistaken for "latest"; present elsewhere (apt) *and* `--version`
given → step 2's exit-0 would ignore an explicit request — the ensure-semantics above
resolves this cleanly (install to `$INSTALL_DIR`, still warn about the shadowed apt copy).

### D24 — the chain holds; every link re-checked

| link | status |
|---|---|
| mise can't read `go.mod` | **VERIFIED, this machine, stronger than claimed**: mise 2026.7.7 with only `go.mod` (`go 1.24.4`) present resolves *no* go version at all — and with `.go-version` present *also* nothing, because `idiomatic_version_file_enable_tools` is **empty by default** now. mise reads neither file without opt-in |
| GoReleaser pins exactly in the action, free | **VERIFIED**: `goreleaser-action` `version:` input, default `~> v2`, accepts exact versions |
| cosign pinned by the action's default | **VERIFIED**: `cosign-installer` `action.yml` default `cosign-release: v3.0.6` |
| mise `pipx` backend is version-only | not re-verified — and **immaterial**: pipx-under-mise still resolves the 17-dep transitive tree fresh either way, so the conclusion (mise doesn't fix #4) is robust without it |
| `minimum_release_age` is real | **VERIFIED**: present in mise's settings schema |

**Decline #6: endorsed.** One caveat: the counter-offer ("pin GoReleaser exactly,
hash-pin cloudsmith-cli") is **incomplete** — see §4 entry 1. The remaining tool-pinning
hole in the signing job isn't something mise would have fixed either, but D24's
counter-offer is where it belongs.

### §2's posture — sound; one guardrail to add

The posture is the maintainer's (M7), and the re-derivations it forced (D21's clean break
especially) are better decisions at this scale. **D11 is not churn**: pairing
`--install-dir` with `<TOOL>_INSTALL_DIR` is a real consistency gain, and the cost is two
scripts you own with near-zero documented users.

The guardrail: **§11's closing note instructs the next agent to "assume that direction
continues."** Delete or soften it. A posture is a decision, not a trend line; extrapolated
autonomously it turns into licence. The counter-offer obligation (M6) is the actual
control — keep that load-bearing, not the extrapolation.

### Scale — reframed per the maintainer: *excellent*, not *less*

(Directive received during review: the goal is an excellent, principled, ergonomically
consistent system for tools in daily use — not a minimal one.)

**Keep, they are the excellence**: #4; #1 with the bats suite under **bash and dash** and
the exit-code/stream/effect assertions (this is what "the floor is executable" means); the
four output levels (M2); #8; #7; D25; D26; the honest-positioning comments (§6.9).

**Cut or shrink, they are ceremony even under the excellence framing**:

1. **§6.11's container layer** — the pipeline's `package-repo-smoke` already runs real
   containers per release; a second container matrix for `install.sh` re-tests curl and
   `mktemp`. The doc already suspects this; confirmed: cut. (One `dash`-on-Debian bats run
   in CI covers the honest risk.)
2. **#3 as "the big one"** — shrink from research program to a **one-page checklist**:
   elements × {can/should/shouldn't} × 5 repos. This review plus findings-2026-07-16
   already contains most of the census #3 was going to do. The remaining open questions
   (Q12, sorta's status, #2's fate) are decidable in an afternoon against that table.
3. **#2** — agree with "likely can-but-shouldn't"; fold its resolution into #3's
   checklist rather than keeping a standing issue.
4. **Propagation robot (Q3)** — agree: manual now, revisit *when the migration gets a
   date*. With §2a's corrected inventory, migration-day propagation is 2 sites + 2
   vendored files — comfortably manual at n=4.

---

## 4. New §10 entries — needs nobody has articulated

1. **Your signing job trusts five mutable tags.** `actions/checkout@v6`,
   `actions/setup-go@v6`, `sigstore/cosign-installer@v3`, `goreleaser/goreleaser-action@v7`,
   `actions/attest-build-provenance@v2` — every one a movable ref, running in the job
   holding `GPG_PRIVATE_KEY`, `CLOUDSMITH_API_KEY`, tap token, and OIDC. A retag upstream
   is the same class of hole #4 closes for pipx, and arguably ahead of it in severity.
   Standard practice: SHA-pin + Dependabot/Renovate to advance the pins. This belongs in
   #4 or a sibling issue. *(Affects: all. Status: nowhere in the plan.)*
2. **The durable-artifact inventory missed the most durable artifact.** §3 enumerates rc
   snippets, mise.toml, muscle memory — but every apt/dnf machine has a **root-owned
   sources.list.d entry baking `dl.cloudsmith.io/public/rocne/releases/…`**, written by
   Cloudsmith's setup script. If the migration (or any Cloudsmith rename) moves that slug,
   those machines don't fail — they **silently stop updating**, which is worse. #11's
   inventory must include the Cloudsmith slug; either it's part of the floor or the
   migration needs a Cloudsmith redirect/dual-publish story. *(Affects: all apt/dnf users.)*
3. **`brew` references `rocne/homebrew-tap` from user machines** (VERIFIED in gostow's
   goreleaser config). Git-level redirects cover it *only* under the "never free the
   namespace" constraint — one more reason that constraint is load-bearing; write the tap
   into #11's inventory. *(Affects: brew users.)*
4. **Go module paths don't migrate.** `go install github.com/rocne/gostow@latest` is an
   advertised channel (gostow's own goreleaser comments). Module path is identity: after a
   transfer the `module` line either stays `github.com/rocne/...` forever (works via
   redirect, forever coupled to the old name) or changes (breaking every existing
   `go install` invocation and import). Decide which, in #11, before the move.
5. **`$TOOL --version` output is already a cross-repo contract, and nothing says so.**
   The release smoke greps it (`release.yml:201`); D16's version matching will parse it;
   four tools currently emit whatever they like (gostow: `gostow 0.4.0 (GNU Stow 2.4.1
   compatible)`). One sentence of spec ("first line: `<binary> <semver>`…") makes three
   consumers of it reliable. Pure consistency win — the thing the maintainer actually
   asked for. *(Affects: all.)*
6. **Neither shipped installer is truncation-safe.** A dropped `curl | sh` connection
   executes a prefix of the script. mise.run wraps all logic in functions with one
   trailing `install_mise` call (**VERIFIED** today, 370 lines, 13 functions); rustup
   does the equivalent. The canonical script should adopt the main-wrapper idiom — it's
   established practice (M5) and costs nothing. Floor-adjacent: it's a property of *the
   bare invocation* the floor protects. *(Affects: all curl|sh users.)*
7. **"Latest" resolution burns an unauthenticated API call.** Both shipped scripts curl
   `api.github.com/repos/…/releases/latest` — rate-limited at 60/hr/IP, which fails
   behind NAT/CI shared egress. The `https://github.com/<repo>/releases/latest` **redirect
   Location header** resolves the same answer with no API and no JSON-by-grep. Design note
   for #1. *(Affects: CI and office-network users.)*
8. **Say out loud that checksum-without-cosign is integrity, not authenticity.** The
   checksums file rides the same origin as the artifact; F4 defends against corruption,
   not compromise. §6.9 is the right register — add this as its fourth honest position.
   It also sharpens #7's pitch: mise's attestation verification is the only install path
   where authenticity is checked by default. *(Affects: threat-model honesty.)*

**Meta-observation**: entries 2–4 all fall out of one question — *"enumerate every string
a user's machine stores that contains the word `rocne`"* — asked against each channel
(curl, apt/dnf, brew, go install, mise). §10's closing line says to put the migration
question to every standing constraint; this is that, made mechanical. The answer set
(rc snippets, sources.list.d, brew taps, go.mod module lines, mise.toml backends,
workflow `uses:` refs) *is* the floor's real inventory.

---

## 5. Corrections list for DESIGN.md (all quick)

1. §9 + §10 #10 — replace the 8-files/5-repos/dryrun claim with the 3-file inventory (§2a).
2. §1 census — dot-dagger 141 releases; family total ~148.
3. D8 — "deprecated" → dropped (align with D21).
4. §6.3 — config block: `REPO` + `TOOL` + `SIGNER_REPO`; delete `INSTALL_MAN` from the
   example; fix the "binary name = repo slug" comment (false for dot-dagger).
5. F2/D16 — resolve the `--version` contradiction (ensure-semantics recommended).
6. D17 — "(§6.10)" → §6.11.
7. §6.3 — rewrite the caarlos0 paragraph: the honest claim is the scale/ownership
   asymmetry, not "dodges his objection" (§3-D6).
8. §6.5 — soften "dstow's ask is simply wrong" to context-bound (§3-D16).
9. §11 — remove/soften the "assume that direction continues" instruction.
10. §6.11 — cut the container layer; keep bash+dash bats as the defended core.

## 6. Suggested issue actions

| issue | action |
|---|---|
| **#11** | Rewrite the inventory per §2a; add Cloudsmith slug, brew tap, and go-module-path line items (§4.2–4.4); keep "never free `rocne`" as a written constraint — it now protects four channels, not two |
| **#4** | Extend (or add sibling) to SHA-pin the five actions in the signing job (§4.1) |
| **#1** | Fold in: `REPO`+`TOOL`+`SIGNER_REPO` block, `--version` ensure-semantics, main-wrapper, redirect-based latest resolution, below-the-marker byte-identity invariant |
| **#3** | Shrink to a checklist; absorb #2's verdict |
| **#6** | Close as declined per D24 (endorsed) |
| **new** | `--version` output contract across the four tools (§4.5) — or fold into #1 + a one-line addition per consumer |
| **new (small)** | release-ci releases itself: no release-please config, one hand-cut tag, D19 should apply reflexively (Q12's gap, promoted) |

---

## 7. Addendum: second pass — self-review of the applied revision (same day)

The maintainer asked for the applied revision itself to be challenged for consistency,
quality, clarity, and completeness. Method unchanged: full re-read, every new §14 claim
re-verified by command. Findings, all now applied:

**Contradictions the first application left standing (fixed):**
- §6.1 and §12 still carried the retracted caarlos0 claim ("doubted the approach") that
  §6.3's correction had replaced — mistake-#14-class drift committed *in the revision that
  documented mistake #14*. Recorded as §13 #21.

**New defect found and VERIFIED (fixed, D33 + §13 #20):**
- The `--help` self-read idiom (`sed -n '2,23p' "$0"`), praised as "a good idiom" in §6.6,
  **cannot work under the documented invocation**: piping the script into `sh -s -- --help`
  yields `sed: can't read sh: No such file or directory` **with exit 0**. Reproduced
  directly. Both shipped scripts carry this; the canonical script uses a `usage()` heredoc.

**Underspecification resolved:**
- D26's snippet vendoring scope was ambiguous (§6.7 implied four consumers; only dstow
  surfaces a snippet). Clarified: vendored to consumers that surface an rc snippet — today
  dstow alone; clean absence elsewhere.

**Precision fixes:** D23 strengthened with the 2026-07-17 empirical result (mise reads
neither `go.mod` nor `.go-version` by default); `<TOOL>_INSTALL_DIR` wording corrected to
"baked from the binary name" post REPO/TOOL split; canonical abort message now covers
`REPO` and `TOOL` (§6.3, D22); `%q` cite corrected to `dot-dagger/install.sh:60`; §14's
tag-bump dependency rephrased (blocked on the next tag, not specifically on automation).

**Challenges run that did NOT survive (§14 claims verified sound):**
- `repo-install-smoke.yml` (gostow) tests the Cloudsmith apt/dnf path via
  `test/run-repo-install-smoke.sh`; it never touches `install.sh` — no hidden CI
  touchpoint for the installer swap. No gostow test script references `install.sh`;
  the only CI touchpoint is `lint.yml`'s shellcheck, already covered.
- hud's binary/project name is `hud` and dstow's is `dstow` (verified from their
  `release-please.yml` inputs and hud's `.goreleaser.yaml`) — §14.3/14.4's config-block
  values are correct.
- gostow's `--version` first line (`gostow 0.4.0 (GNU Stow 2.4.1 compatible)`) conforms to
  D30's `<binary> <semver> …` spec as claimed.
