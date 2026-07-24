# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

release-ci keeps its domain knowledge **and** its decisions in one canonical document, **`docs/DESIGN.md`** — not the generic `CONTEXT.md` + `docs/adr/` layout. DESIGN.md fills both roles today. This file maps the skills' expectations onto our actual docs, and records how we migrate as the domain model gets formalised.

## Before exploring, read these

- **`docs/DESIGN.md` — canonical.** Before working an area, read the parts that touch it:
  - **§7 Decision register (`D1`–`D37`)** — our decision log. Each `D<n>` is a dated, numbered, referenced decision with rationale: the **ADR-equivalent**, consolidated in one table rather than per-file `docs/adr/*.md`. Read the `D`-entries for your area and the `§6.x`/`§9`/… section each cites.
  - **§1 What release-ci is · §3 The floor exists for users · §6 `install.sh` design** — where the **ubiquitous language** is defined (consumer, canonical installer, the vendored config block, the floor `F1`–`F6`, the artifact-shape contract, the rc snippet, `SIGNER_REPO`, the downshift). This is the de-facto glossary; it is design prose that defines terms, not a standalone `CONTEXT.md`.
  - **§13 Mistakes made (`M1`…)** — the lessons register. Check it before repeating a class of error.
  - **§14 Consumer adaptation plans** — per-consumer specifics (gostow, dot-dagger, hud, dstow, sorta).
- **`docs/reference/`** — the evidence base (installer/tooling/mise surveys, plan reviews). Read the relevant survey before re-litigating a settled question.
- **`docs/SECRETS.md`, `docs/adoption-audit.md`** — signing/secret setup and the consumer-surface audit.

There is **no `CONTEXT.md` and no `docs/adr/` today, deliberately.** Don't scaffold empty ones, and don't treat DESIGN.md as if it were a `CONTEXT.md` glossary — it is a design/decision doc that happens to define the vocabulary in prose. If a file the generic skills expect is absent, **proceed silently**; don't flag it.

## Migration posture — migrate as appropriate

DESIGN.md stays canonical and is never forked. As `/domain-modeling` resolves a term or a decision, migrate it into a skill-native shape **only where that adds clarity** — e.g. extract a standalone `CONTEXT.md` glossary once the ubiquitous language is worth pinning outside DESIGN.md's prose, or split decisions into `docs/adr/NNNN-*.md` if per-file ADRs ever earn their keep. Until then:

- New **decisions** land as **`D`-numbers in §7**, not as new ADR files.
- New **terms** land as definitions in the relevant `§`-section.
- One decision log, one glossary source — in DESIGN.md.

When this file's guidance and the generic skill text disagree, **this file wins** (it describes what actually exists here).

## Use the vocabulary DESIGN.md defines

When your output names a domain concept (an issue title, a refactor proposal, a hypothesis, a test name), use DESIGN.md's term. It is deliberate about words: say **consumer**, not "downstream repo"; **vendored config block**, not "the settings"; **the floor** / **`F1`–`F6`**; **the downshift** (`D19`). Drifting to synonyms DESIGN.md avoids is a smell.

If the concept you need isn't named in DESIGN.md yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag decision conflicts

If your output contradicts an existing decision, surface it **by number** rather than silently overriding:

> _Contradicts `D25` (SIGNER_REPO is a config-block variable) — but worth reopening because…_

The same holds for the §13 mistakes: if you're about to do something a `M`-number already warns against, stop and say so.
