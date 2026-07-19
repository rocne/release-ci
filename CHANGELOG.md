# Changelog

## [0.1.4](https://github.com/rocne/release-ci/compare/v0.1.3...v0.1.4) (2026-07-19)


### Features

* gitleaks — canonical hook + CI gate; audit rows 19/20 proposed ([c790b13](https://github.com/rocne/release-ci/commit/c790b13e3c745ff6d82f3b624dbf9e865c85a176))
* gitleaks — canonical pre-commit hook, CI gate here, audit rows 19/20 proposed ([#3](https://github.com/rocne/release-ci/issues/3)-family) ([338acdf](https://github.com/rocne/release-ci/commit/338acdfd0404242d26c54a3d4c94a3e2673d9fbd))


### Bug Fixes

* **install:** silence curl noise on the opportunistic signature fetch ([53f05fb](https://github.com/rocne/release-ci/commit/53f05fb2e38a532318fb814d97645f4fb9881c3c))
* **signing:** migrate cosign contract to v3 Sigstore bundle (D35, [#45](https://github.com/rocne/release-ci/issues/45)) ([0fc39a5](https://github.com/rocne/release-ci/commit/0fc39a522dbee37398d0149c13f2b53e5a7ba4d7))
* **signing:** migrate cosign contract to v3 Sigstore bundle (D35, [#45](https://github.com/rocne/release-ci/issues/45)) ([182755a](https://github.com/rocne/release-ci/commit/182755a0cdfda3bede3b943307d010f2dd96e011))

## [0.1.3](https://github.com/rocne/release-ci/compare/v0.1.2...v0.1.3) (2026-07-18)


### Features

* assert the D30 --version parse rule ([#15](https://github.com/rocne/release-ci/issues/15)) ([06f49a8](https://github.com/rocne/release-ci/commit/06f49a8f8580087b57e9b876a2357b6d8db7d518))
* reusable pr-title workflow; canonical consumer snippets appendix ([#37](https://github.com/rocne/release-ci/issues/37), [#38](https://github.com/rocne/release-ci/issues/38), [#39](https://github.com/rocne/release-ci/issues/39), [#40](https://github.com/rocne/release-ci/issues/40), [#41](https://github.com/rocne/release-ci/issues/41)) ([7eab24a](https://github.com/rocne/release-ci/commit/7eab24a712da4468ff0d8fa6b2e00628530feb89))


### Bug Fixes

* refuse a non-file at the install path; honest error for 0-release repos ([#1](https://github.com/rocne/release-ci/issues/1)) ([c52c37b](https://github.com/rocne/release-ci/commit/c52c37bdbe2cb533b7dde4f42669508cac10496d))

## [0.1.2](https://github.com/rocne/release-ci/compare/v0.1.1...v0.1.2) (2026-07-18)


### Features

* assert the D34 artifact-shape contract in release-dryrun ([#24](https://github.com/rocne/release-ci/issues/24), [#15](https://github.com/rocne/release-ci/issues/15)) ([8dc2523](https://github.com/rocne/release-ci/commit/8dc252363f53b3d1a69916f64bf32e541d150ddd))
* assert the D34 artifact-shape contract in release-dryrun ([#24](https://github.com/rocne/release-ci/issues/24), [#15](https://github.com/rocne/release-ci/issues/15)) ([8c5b870](https://github.com/rocne/release-ci/commit/8c5b8707f6e1bd679041bd71b29b56f49be5c267))
* canonical install.sh + rc snippet + floor test suite ([#1](https://github.com/rocne/release-ci/issues/1)) ([8661d1a](https://github.com/rocne/release-ci/commit/8661d1a3a788a2c56ab0b6aa8ae1f96791153f46))
