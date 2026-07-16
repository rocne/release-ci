# release-ci

Reusable GitHub Actions release pipeline for rocne tools (build → sign → publish →
verify). Consumers call `.github/workflows/release.yml` via `workflow_call` with
`secrets: inherit`. See each tool's `release.yml` for the input contract.

Creating, storing, and rotating the signing keys and tokens a caller needs:
[docs/SECRETS.md](docs/SECRETS.md).
