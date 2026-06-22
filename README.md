# release-ci

Reusable GitHub Actions release pipeline for rocne tools (build → sign → publish →
verify). Consumers call `.github/workflows/release.yml` via `workflow_call` with
`secrets: inherit`. See each tool's `release.yml` for the input contract.
