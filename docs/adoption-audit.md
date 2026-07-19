# Adoption audit — consumer-side pipeline surface (#3)

**Status: RULED — maintainer, 2026-07-18.** All proposed verdicts confirmed, including the
four explicitly contested rows: the dryrun gate is **mandatory** (row 3), pr-title
**centralizes with no opt-out** (row 5), pin discipline is **one tag per consumer +
Dependabot** (row 12), and sorta's standing is **conventions bind, distribution elements
vacuous** (row 18). Should-rows' implementation issues: #37 (pr-title), #38 (pin
discipline + D30 rollout), #39 (shellcheck step convergence), #40 (mise stanza), #41
(break-glass rename), dstow#64 (smoke, sequenced on packages).

Living decision record (not a dated snapshot — sibling convention per #3). Census below
re-verified by command **2026-07-18**; the method is listed so it can be re-run.

Binding context: the floor + opt-out discipline (#1/#3, M3), authority/counter-offer (M6/M7),
established practice (M5), **uniformity (M13: no per-repo exceptions — divergence must be a
ruled verdict in this file, never a default)**.

## Census (re-verified 2026-07-18)

Method: `git ls-tree origin/main .github/workflows/` per clone after `git fetch`;
`gh api repos/rocne/<r>/releases --paginate` for counts; `git grep` for pins and assert refs.

| repo | `release.yml` (reusable) | releases | `install.sh` | notable |
|---|---|---|---|---|
| gostow | `@v0.1.1` | 5 | old hand-rolled (swap staged, #44) | 7 workflows; the only repo whose lint shellchecks `install.sh` today |
| dot-dagger | `@v0.1.1` | **141** | old hand-rolled (swap staged, #201) | 8 workflows (`docs.yml` unique); **no shellcheck in CI at all** (fixed on the staged branch) |
| hud | `@v0.1.1` | 0 | none (vendor staged per M13, #4) | root `.goreleaser.yaml` (layout move tracked in hud#4) |
| dstow | `@v0.1.1` | 0 | none (vendor + `snippet.sh` staged, #64) | no `repo-install-smoke.yml`; first release blocks on #1 |
| sorta | **not wired** | 2 (tag-only, **0 assets**) | none | rides `pr-title` + `release-please` + ci/lint only — conventions, not distribution |

**New facts this census adds over 2026-07-16:**

1. **The D34 artifact-shape assert is already consumed by all four consumers** — not by
   vendoring: each `release-dryrun.yml` checks out `rocne/release-ci@v0.1.2` and runs
   `release-dryrun/assert-artifact-shape.sh <tool>` from it ("owned once, pinned by tag").
   The script headers still say "vendored"; the delivery model that actually shipped is
   **pinned fetch**. Header comment should be updated to match reality (small fix).
2. **Split pins exist now**: every consumer pins `release.yml@v0.1.1` but the assert
   checkout at `@v0.1.2`. Two tags, two pin sites, already diverged — tag-rollout
   discipline is live, not hypothetical (row 12).
3. **The D30 version-contract assert is consumed nowhere** — it merged after v0.1.2 was
   cut. It rides the next tag + the pin bump (row 6).
4. **sorta cuts releases** (v0.1.0, v0.2.0) — but they are release-please source tags with
   zero assets. "No distribution" still true; "no releases" would be false.

## The matrix

Verdicts: **should** = absorb/centralize (must name a real opt-out, M3) · **can** =
technically absorbable, not worth its mandate · **shouldn't** = consumer-specific by
nature. Per M13, "exempt" is never a status — an exemption is a ruled **shouldn't** with a
reason.

| # | element | dup | verdict (proposed) | opt-out mechanism | why |
|---|---|---|---|---|---|
| 1 | `install.sh` | 4 | **should — decided (#1), in flight** | M13: all four vendor; `--bin-only`, `--require-signature` etc. opt features in/out at runtime | Single ownership already built and gate-discharged; swaps staged for all four consumers. Not re-litigated here |
| 2 | `snippet.sh` | 1 (dstow) | **should**, for snippet-surfacing consumers | A consumer that documents no rc snippet has nothing to vendor — clean absence, not exemption (M13-compatible: the *surface* is the difference, not the treatment) | The snippet is the most durable user-side artifact (D26); single ownership of the PATH line |
| 3 | `release-dryrun.yml` (signing gate) | 4 | **should — mandatory (ruled 2026-07-18)** | Path-filtered: it triggers only on release-sensitive paths; a repo with no release surface never runs it. Beyond that, deliberately none | The body predicted this row would hide a mandate under a "should" — saying it outright instead: this is the pipeline's core safety property (snapshot build + sign + verify before merge). A consumer that could decline the signing gate can ship unsigned drift; that defeats the system's reason to exist. Mandatory is the finding, per the demotion rule's own escape clause |
| 4 | D34 assert (in dryrun) | 4 | **should — already done** (pinned fetch, v0.1.2) | Same as row 3 (it rides the dryrun) | Shipped; the scripts' "vendored" header comments corrected to pinned-fetch (same commit as this ruling) |
| 5 | `pr-title.yml` | **5** | **should — centralize, mandatory (ruled 2026-07-18) → #37** | None — ruled: it feeds squash-titles → release-please; a repo opting out silently breaks its own versioning | Most-duplicated element in the org; pure policy, zero consumer-specific content — the cheapest single-ownership win on the board |
| 6 | D30 assert (`assert-version-contract.sh`) | 0 | **should → #38** — add beside D34 in each dryrun at the next tag bump | M12's escape: a tool that cannot conform opts out with defined degradation (documented nonconformance, not a stub) | Built and tested here; consumed nowhere. Rides row 12's bump |
| 7 | `release-please.yml` + config + manifest | 5 | **can** — template/convention, not central config | n/a (stays per-repo) | The workflow is thin; the config carries per-repo versioning state (downshift flag #8/D19 is a per-repo one-liner already tracked). Centralizing state that must differ per repo buys drift, not ownership |
| 8 | `repo-install-smoke.yml` | 3 | **should → dstow#64** — dstow gets it too, when it publishes packages (sequenced, not exempt — M13) | `workflow_dispatch`-only: never runs unbidden; a repo with no published packages has nothing to smoke (clean absence) | On-demand clean-box verification of the published repos; identical policy everywhere |
| 9 | version guard (#2) | 1 (gostow, 4 sites, 2 absorbable) | **can-but-shouldn't** — confirm #2's evidence | opt-in by construction (default: no guard) | One consumer; half its sites run where release-ci cannot see. Absorbing a 1-consumer idiosyncrasy couples the pipeline to gostow's shape |
| 10 | `ci.yml` / `lint.yml` | 5 | **shouldn't** absorb wholesale; **should → #39** standardize the shellcheck-install.sh step | Consumer CI is theirs; the shellcheck step is part of #1's delivery model (the vendored script's review gate) and must exist wherever `install.sh` does | Found live: only gostow shellchecked `install.sh`; dot-dagger had **no shellcheck**, dstow/hud none for root scripts. The staged vendor branches fix all four — in three near-identical shapes that should converge on one canonical step text |
| 11 | `.goreleaser/<tool>.yaml` | 4 | **shouldn't** absorb (per-tool by nature); **should** standardize layout `.goreleaser/<tool>.yaml` (D27+M13) | Layout is uniform, content is the consumer's | hud's root-level file is the one divergence; its move is already tracked (hud#4) and costs nothing pre-first-release |
| 12 | **tag rollout / pin discipline** | all | **should (ruled 2026-07-18) → #38** — one release-ci version per consumer repo, bumped by PR | n/a — discipline, not feature | Live drift found: `@v0.1.1` + `@v0.1.2` split pins in every consumer. Proposal: a consumer pins **one** tag everywhere; bumps arrive as PRs (Dependabot `github-actions` ecosystem covers reusable-workflow and checkout refs — "staleness is a visible open PR, never silence", same doctrine as #1's propagation) |
| 13 | mise stanza (README) | 0 | **should → #40** — canonical stanza text owned here, landed with each first release | A consumer simply doesn't add the README line | Verified working with zero config (mise survey); cost is one README line; attestation verification for free |
| 14 | committed signing pubkeys + `extra_files` | 4 | **can** — keep per-repo today | n/a | Org migration (§9) changes the answer; per M8/#11 discipline: design for it, don't couple to it. Revisit at migration date |
| 15 | `docs.yml` (mkdocs) | 1 | **shouldn't** | Clean absence everywhere else | Consumer-specific by nature; no drift cost |
| 16 | e2e exerciser + `procure/` seam | 2 (dot-dagger, dstow by adoption) | **shouldn't** mandate; **can** document as the house pattern | Adopting the seam is opt-in | Useful convention; forcing it on gostow/hud buys nothing |
| 17 | consumer break-glass `release.yml` naming wart | 4 | **should (ruled) → #41**: rename consumer-side file (e.g. `release-manual.yml`) | Pure rename, no behavior | Every consumer's break-glass shares release-ci's reusable workflow's filename; flagged by the survey, confusing in every incident. Costs one rename PR per repo, can ride the vendor PRs |
| 19 | **gitleaks CI gate** (secret scan, full history, every ref) | 0 → all | ⚖️ **PROPOSED should — mandatory-defended** (2026-07-19, awaiting ruling) | Deliberately none, same defense as row 3: a repo that opts out of secret scanning weakens the org (a leaked signing PAT in any repo endangers all), not just itself. If the mandate is declined, demote to can | Baseline established 2026-07-19: full-history, all-refs scan of all six repos = **zero findings** (control-verified — a planted token is caught; AWS's documented example key is allowlisted by design). Bare pinned binary, not `gitleaks-action` (the action wrapper needs a paid license on org accounts — would couple the gate to a purchase at #11 migration time). Full-scan-every-run over diff-scan: largest repo scans in ~1s, and it re-verifies the whole exposure surface. Private repos are where this bites most: GitHub's own secret scanning doesn't cover them without paid Advanced Security, and dstow/hud/sorta flip public pre-first-release — anything buried becomes public then |
| 20 | **pre-commit hook** (`.githooks/pre-commit`, gitleaks staged scan) | 0 → all | ⚖️ **PROPOSED should** (2026-07-19, awaiting ruling) | Opt-in by construction — git never auto-runs cloned hooks; activation is a one-time per-machine `git config --global core.hooksPath .githooks`, and the hook itself degrades F5-style (gitleaks absent → one notice, proceed). The hook is convenience; row 19 is the contract | Catches the secret **before it enters history** — CI catching it post-commit still means history surgery. Distributed through the installer's vendoring pipe (canonical file, byte-identical, consumer shellcheck); no config block needed (nothing per-consumer) |
| 18 | **sorta** | — | **RULED 2026-07-18: conventions bind, distribution vacuous** — `pr-title`/`release-please`/lint conventions apply (and centralize per row 5); `release.yml`/dryrun/smoke/`install.sh` are **shouldn't wire** — nothing to distribute (private, 0-asset tags) | n/a | Was the one genuine exception candidate under M13; now an explicit verdict, not an accreted default. Revisit only if sorta ever ships an artifact |

## Should-rows → implementation issues (filed 2026-07-18, post-ruling)

Row 5 → **#37** (central `pr-title` reusable, mandatory). Rows 6+12 → **#38** (single-pin
discipline + Dependabot; D30 assert rollout rides the first uniform bump). Row 8 →
**dstow#64** (smoke, sequenced on packages). Row 10 → **#39** (canonical shellcheck step
text). Row 13 → **#40** (mise stanza). Row 17 → **#41** (break-glass rename). Rows 1/2/4
are in flight or done (installer vendor PRs: gostow#49, dot-dagger#206, dstow#78, hud#8).

## Standing risks this audit re-confirms

- **Blast radius**: absorption raises the cost of a release-ci mistake; row 12's
  single-pin-per-repo keeps rollout observable and reversible per consumer.
- **Org migration (§9/#11)**: nothing above couples to the `rocne` namespace beyond what
  #11 already tracks (`SIGNER_REPO`, D25); row 14 explicitly defers to the migration date.
- **Source reliability**: the 2026-07-14 survey remains cite-only-if-reverified (two
  falsified claims); everything in this file's census was measured 2026-07-18.

## Appendix: canonical consumer snippets (rulings' implementation surface)

The exact text consumers carry. Any drift from these is a propagation bug, same doctrine
as the installer's below-the-block invariant.

### pr-title caller (#37 — replaces each repo's policy copy at the next pin bump)

```yaml
name: PR title

# Thin caller (release-ci#37): the policy lives in release-ci's reusable
# workflow — mandatory, adoption audit row 5. Pinned per the single-pin rule.
on:
  pull_request_target:
    types: [opened, edited, synchronize, reopened]

permissions:
  pull-requests: read

jobs:
  lint:
    uses: rocne/release-ci/.github/workflows/pr-title.yml@vX.Y.Z # the repo's ONE pin
```

### Shellcheck step for vendored scripts (#39 — in each consumer's lint.yml)

```yaml
      # install.sh (and snippet.sh where vendored) is piped into `sh` from the
      # internet; a bug in it runs on a stranger's machine. shellcheck is
      # preinstalled on the ubuntu runner. Canonical step: release-ci#39.
      - name: Shellcheck the vendored installer
        run: shellcheck install.sh
```

dstow adds `snippet.sh` to the `run:` line. Repo-specific scripts (e2e suites etc.) stay
in a separate, repo-owned step — the canonical step covers exactly the vendored files.

### mise stanza (#40 — consumer READMEs, landed with the repo's first public release)

```markdown
### mise

[mise](https://mise.jdx.dev) installs pinned releases and verifies their GitHub
attestations with zero configuration:

    mise use -g github:rocne/<repo>@latest
```

Empirically verified (mise survey 2026-07-16) against gostow and dot-dagger releases.
Requires the repo to be public — dstow/hud/sorta are private today, so their stanzas wait
for the visibility flip (recorded on dstow#64 / hud#4).

### Single-pin rule (#38)

A consumer repo references release-ci at **exactly one version** across all its workflows
(`uses:` sites *and* the dryrun assert checkout's `ref:`). Bumps arrive as PRs — Dependabot
(`github-actions` ecosystem) covers the `uses:` sites; the checkout `ref:` is bumped in the
same PR by hand until the dryrun surface is unified. Split pins are a bug (found live
2026-07-18: v0.1.1/v0.1.2 in all four consumers).

### gitleaks CI gate (row 19 — canonical job, pending ruling)

```yaml
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<pinned-sha> # keep the repo's own checkout pin
        with:
          fetch-depth: 0 # full history — the scan walks every commit
          persist-credentials: false
      - name: Download gitleaks (pinned, checksum-verified)
        run: |
          curl -fsSL --proto '=https' --tlsv1.2 -o gitleaks.tar.gz \
            https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
          echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  gitleaks.tar.gz" | sha256sum -c -
          tar -xzf gitleaks.tar.gz gitleaks
      - name: Scan full history for secrets
        run: ./gitleaks git . --redact --no-banner --log-opts="--all"
```

Version bumps are a manual edit (URL + checksum together) — Dependabot doesn't track
release-asset downloads. `--log-opts="--all"` matters: default scans walk HEAD only, and
a repo going public exposes **every pushed ref** (measured 2026-07-19: HEAD-only missed
branch commits in 5 of 6 repos).

### pre-commit hook (row 20 — pending ruling)

Canonical file: release-ci `.githooks/pre-commit` — vendored byte-identical (no config
block). Activation, once per dev machine:

```console
$ git config --global core.hooksPath .githooks
```

Repos without a `.githooks/` directory are unaffected. Caveat: a global hooksPath
overrides per-repo `.git/hooks/`, so third-party repos that self-manage hooks (husky
etc.) won't fire theirs — use per-repo `git config core.hooksPath .githooks` on machines
where that matters.

### Break-glass workflow name (#41)

The consumer-side tag-push workflow is `release-manual.yml` (was `release.yml`, colliding
with the reusable workflow it calls). The `name:` fields were already distinct; the
filename now is too.
