# Adoption audit — consumer-side pipeline surface (#3)

**Status: verdicts PROPOSED, none ruled.** Per #3's model gate, the census and table below
are built; the can/should/shouldn't calls are **proposals awaiting the maintainer's ruling**
(Fable + maintainer in the loop — this document merging with a verdict column intact *is*
the ruling; strike or amend rows to overrule). Rows marked ⚖️ need an explicit decision and
should not be defaulted.

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
| 3 | `release-dryrun.yml` (signing gate) | 4 | **should — and its mandate is defended, explicitly** ⚖️ | Path-filtered: it triggers only on release-sensitive paths; a repo with no release surface never runs it. Beyond that, deliberately none | The body predicted this row would hide a mandate under a "should" — saying it outright instead: this is the pipeline's core safety property (snapshot build + sign + verify before merge). A consumer that could decline the signing gate can ship unsigned drift; that defeats the system's reason to exist. Mandatory is the finding, per the demotion rule's own escape clause |
| 4 | D34 assert (in dryrun) | 4 | **should — already done** (pinned fetch, v0.1.2) | Same as row 3 (it rides the dryrun) | Shipped; fix the "vendored" header comment to say pinned-fetch |
| 5 | `pr-title.yml` | **5** | **should — centralize as a reusable workflow** | ⚖️ None proposed: it feeds squash-titles → release-please; a repo opting out silently breaks its own versioning. If a mandate is unacceptable, demote to can | Most-duplicated element in the org; pure policy, zero consumer-specific content — the cheapest single-ownership win on the board |
| 6 | D30 assert (`assert-version-contract.sh`) | 0 | **should** — add beside D34 in each dryrun at the next tag bump | M12's escape: a tool that cannot conform opts out with defined degradation (documented nonconformance, not a stub) | Built and tested here; consumed nowhere. Rides row 12's bump |
| 7 | `release-please.yml` + config + manifest | 5 | **can** — template/convention, not central config | n/a (stays per-repo) | The workflow is thin; the config carries per-repo versioning state (downshift flag #8/D19 is a per-repo one-liner already tracked). Centralizing state that must differ per repo buys drift, not ownership |
| 8 | `repo-install-smoke.yml` | 3 | **should** — dstow gets it too, when it publishes packages (sequenced, not exempt — M13) | `workflow_dispatch`-only: never runs unbidden; a repo with no published packages has nothing to smoke (clean absence) | On-demand clean-box verification of the published repos; identical policy everywhere |
| 9 | version guard (#2) | 1 (gostow, 4 sites, 2 absorbable) | **can-but-shouldn't** — confirm #2's evidence | opt-in by construction (default: no guard) | One consumer; half its sites run where release-ci cannot see. Absorbing a 1-consumer idiosyncrasy couples the pipeline to gostow's shape |
| 10 | `ci.yml` / `lint.yml` | 5 | **shouldn't** absorb wholesale; **should** standardize the shellcheck-install.sh step | Consumer CI is theirs; the shellcheck step is part of #1's delivery model (the vendored script's review gate) and must exist wherever `install.sh` does | Found live: only gostow shellchecked `install.sh`; dot-dagger had **no shellcheck**, dstow/hud none for root scripts. The staged vendor branches fix all four — in three near-identical shapes that should converge on one canonical step text |
| 11 | `.goreleaser/<tool>.yaml` | 4 | **shouldn't** absorb (per-tool by nature); **should** standardize layout `.goreleaser/<tool>.yaml` (D27+M13) | Layout is uniform, content is the consumer's | hud's root-level file is the one divergence; its move is already tracked (hud#4) and costs nothing pre-first-release |
| 12 | **tag rollout / pin discipline** | all | **should** ⚖️ — one release-ci version per consumer repo, bumped by PR | n/a — discipline, not feature | Live drift found: `@v0.1.1` + `@v0.1.2` split pins in every consumer. Proposal: a consumer pins **one** tag everywhere; bumps arrive as PRs (Dependabot `github-actions` ecosystem covers reusable-workflow and checkout refs — "staleness is a visible open PR, never silence", same doctrine as #1's propagation) |
| 13 | mise stanza (README) | 0 | **should** — canonical stanza text owned here, landed with each first release | A consumer simply doesn't add the README line | Verified working with zero config (mise survey); cost is one README line; attestation verification for free |
| 14 | committed signing pubkeys + `extra_files` | 4 | **can** — keep per-repo today | n/a | Org migration (§9) changes the answer; per M8/#11 discipline: design for it, don't couple to it. Revisit at migration date |
| 15 | `docs.yml` (mkdocs) | 1 | **shouldn't** | Clean absence everywhere else | Consumer-specific by nature; no drift cost |
| 16 | e2e exerciser + `procure/` seam | 2 (dot-dagger, dstow by adoption) | **shouldn't** mandate; **can** document as the house pattern | Adopting the seam is opt-in | Useful convention; forcing it on gostow/hud buys nothing |
| 17 | consumer break-glass `release.yml` naming wart | 4 | **should** (cheap): rename consumer-side file (e.g. `release-manual.yml`) ⚖️ | Pure rename, no behavior | Every consumer's break-glass shares release-ci's reusable workflow's filename; flagged by the survey, confusing in every incident. Costs one rename PR per repo, can ride the vendor PRs |
| 18 | **sorta** | — | ⚖️ **ruling required (M13)**: proposed **shouldn't wire** `release.yml`/dryrun/smoke — nothing to distribute (private, 0-asset tags) — while `pr-title`/`release-please`/lint conventions **bind** | n/a | Under M13 "correct by design off the pipeline" may not stand as an assumption. Proposal: sorta conforms to the *conventions* subset of the authoritative process; the distribution elements are vacuous for a repo that ships no artifacts. This is the one row that is genuinely an exception unless ruled |

## Should-rows → implementation issues (to file after ruling)

Only after verdicts are ruled (each links back here): row 5 (central `pr-title` reusable),
row 6 (D30 assert into dryruns, rides row 12), row 8 (dstow smoke, sequenced on packages),
row 10 (canonical shellcheck step text), row 12 (pin discipline + Dependabot), row 13
(mise stanza text), row 17 (break-glass rename). Rows 1/2/4 are in flight or done.

## Standing risks this audit re-confirms

- **Blast radius**: absorption raises the cost of a release-ci mistake; row 12's
  single-pin-per-repo keeps rollout observable and reversible per consumer.
- **Org migration (§9/#11)**: nothing above couples to the `rocne` namespace beyond what
  #11 already tracks (`SIGNER_REPO`, D25); row 14 explicitly defers to the migration date.
- **Source reliability**: the 2026-07-14 survey remains cite-only-if-reverified (two
  falsified claims); everything in this file's census was measured 2026-07-18.
