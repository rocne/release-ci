# AGENTS.md

Canonical design and decision record for this repo: **[`docs/DESIGN.md`](docs/DESIGN.md)** (D1–D37, §14 per-consumer plans). Read the relevant decisions before changing behaviour.

## Agent skills

### Issue tracker

Issues and PRDs are tracked as GitHub issues via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage roles, default label strings (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context. Domain knowledge and decisions live in `docs/DESIGN.md`, not `CONTEXT.md` + `docs/adr/`. See `docs/agents/domain.md`.
