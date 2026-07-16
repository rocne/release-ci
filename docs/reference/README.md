# docs/reference

Dated research notes. Naming follows the sibling convention: `<topic>-survey-YYYY-MM-DD.md`.

These are **snapshots, not living documents**. They record what was true on the date in the
filename and are not maintained afterwards. Decisions derived from them live in
[`../DESIGN.md`](../DESIGN.md); if the two disagree, DESIGN.md is the design and these are
the evidence it was built on.

## Start here

**[`findings-2026-07-16.md`](findings-2026-07-16.md)** — what we learned and what it
changed, with sources. First-party: everything in it was verified against our own repos or
against a primary source. **Read this one first**; the three surveys below are its raw
material.

## Surveys

| doc | question | reliability |
|---|---|---|
| [`installer-conventions-survey`](installer-conventions-survey-2026-07-16.md) | How do 15 mature `curl \| sh` installers actually behave? | Good. **One synthesis claim corrected** — "info→stdout is universal" is false (mise and Volta route info to stderr). See its reviewer's note |
| [`installer-tooling-survey`](installer-tooling-survey-2026-07-16.md) | Has this been solved already — should we write an installer at all? | Good. **Corrected a false premise in its own brief** (`dist` is actively maintained, not wound down) |
| [`mise-survey`](mise-survey-2026-07-16.md) | Can mise make our CI more robust, and can it install our tools? | Good. Its central distribution claim was desk research and is flagged as such **in the doc**; it has since been **verified empirically** — see `findings` §5. Its headline "mise closes the cloudsmith-cli gap" is **corrected** in `findings` §6 (the `pipx` backend is version-only) |

## Reading these critically

Every claim in `findings` is tagged **VERIFIED** / **SOURCED** / **INFERRED**. The surveys
tag their own claims similarly and carry a reviewer's note recording what was
independently re-checked versus taken on trust.

That is not ceremony. **Three separate documents in this org have asserted cross-repo
"identical / both / all" claims that failed on inspection** — including a sibling survey
cited as prior art by three of our issues, and one of the surveys in this directory.
`findings` §7 has the full account.

**Verify before citing.** Structural descriptions in these documents have held up well;
cross-repo comparative claims have not. The cheap tell is a sentence containing
"identical", "both", "all", or "every" about more than one repo — check it before you
build on it.
