# Does the D34 artifact shape survive a Rust build?

Spike run 2026-07-25 for [#66](https://github.com/rocne/release-ci/issues/66), a ticket on
the [Rust accommodation](https://github.com/rocne/release-ci/issues/63) map.

**Verdict: yes.** A GoReleaser `builder: rust` build produces D34-conformant artifacts with
no change to the archive or checksums `name_template`, and
`release-dryrun/assert-artifact-shape.sh` passes green against the resulting `dist/`.

Claims below are tagged **VERIFIED** (run here, output in this doc), **SOURCED** (read from
GoReleaser v2.17.0 source or docs at that tag), or **INFERRED**.

## Method

A throwaway crate — `rustow`, one `main.rs`, a stub man page and three stub completion
files — built with a `.goreleaser.yaml` copied from
[`gostow`'s](https://github.com/rocne/gostow/blob/main/.goreleaser/gostow.yaml) with only
the `builds:` block swapped for `builder: rust`. Every other stanza (`archives:`,
`checksum:`, `signs:`, `nfpms:`) was left as the Go consumers have it.

| component | version | note |
|---|---|---|
| goreleaser | **v2.17.0** | the version `release.yml` pins, downloaded fresh — not the v2.16.0 on this machine |
| rustc / cargo | 1.97.1 | rustup, isolated `RUSTUP_HOME`/`CARGO_HOME` in a scratchpad |
| cargo-zigbuild | 0.23.0 | the `command: zigbuild` default |
| zig | 0.15.2 | scratchpad tarball |

Nothing was installed into `$HOME` or into the release-ci checkout.

Commands: `goreleaser release --snapshot --clean --skip=publish,announce`, then
`sh release-dryrun/assert-artifact-shape.sh rustow dist`.

## Findings

### 1. The shape holds, and the D34 assert passes — VERIFIED

Four targets (`x86_64`/`aarch64` × `unknown-linux-gnu`/`apple-darwin`) produced exactly the
names the Go consumers produce:

```
rustow_v0.0.0_darwin_amd64.tar.gz
rustow_v0.0.0_darwin_arm64.tar.gz
rustow_v0.0.0_linux_amd64.tar.gz
rustow_v0.0.0_linux_arm64.tar.gz
rustow_v0.0.0_checksums.txt
rustow_v0.0.0_checksums.txt.sigstore.json

$ sh release-dryrun/assert-artifact-shape.sh rustow dist
D34 artifact-shape contract: OK (rustow, 4 archive(s), checksums signed)
```

All four D34 elements: archive name shape, checksums name + bundle beside it, binary at the
archive root, and a `linux_amd64` archive.

### 2. The triple→`Os_Arch` translation is real, but `.Os` is not a lookup — SOURCED

`internal/builders/rust/build.go` at v2.17.0 parses a target by splitting on `-`:

```go
t := Target{
    Target: target,
    Os:     parts[2],
    Vendor: parts[1],
    Arch:   convertToGoarch(parts[0]),
}
```

`.Arch` goes through a real map (`x86_64`→`amd64`, `aarch64`→`arm64`, …). **`.Os` is the
third field of the triple verbatim** — it lands on a GOOS value because Rust and Go happen
to share the vocabulary (`linux`, `darwin`, `windows`), not because anything translates it.
For the targets a consumer would plausibly ship this is a distinction without a difference,
but it means the guarantee is a vocabulary coincidence rather than an enforced mapping.

The docs state the intent directly: *"GoReleaser will translate Rust's Os/Arch triple into a
GOOS/GOARCH pair, so templates should work the same as before."* `.Target`, `.Vendor`,
`.Abi` and `.Libc` are additionally available in templates.

### 3. gnu and musl for the same os/arch collide, and GoReleaser hard-fails — VERIFIED

This is the load-bearing constraint for
[the libc ticket](https://github.com/rocne/release-ci/issues/65). Because `.Os` is
`parts[2]` and the ABI field is *not* in the D34 name template, `x86_64-unknown-linux-gnu`
and `x86_64-unknown-linux-musl` both render as `linux_amd64`. Building both:

```
• archiving  name=dist/rustow_v0.0.0_linux_arm64.tar.gz
• archiving  name=dist/rustow_v0.0.0_linux_amd64.tar.gz
⨯ release failed after 1m16s
  error=archive named dist/rustow_v0.0.0_linux_amd64.tar.gz already exists.
        Check your archive name template
```

So: **one libc per os/arch, or the D34 name template has to grow a field.** It fails loudly
at build time rather than silently overwriting, which is the good failure mode — a consumer
cannot ship a colliding pair by accident. Note the template is a D34 contract shared by the
installer, the verify job, the smoke and D20's detection, so growing it is not a
consumer-local change.

### 4. `nfpms:`, `archives:` internals and `signs:` are untouched by the builder — VERIFIED

The deb/rpm stanza copied verbatim from gostow produced the usual `ConventionalFileName`
outputs off the Rust binaries:

```
rustow_0.0.0~SNAPSHOT-none_amd64.deb   rustow-0.0.0~SNAPSHOT_none-1.x86_64.rpm
rustow_0.0.0~SNAPSHOT-none_arm64.deb   rustow-0.0.0~SNAPSHOT_none-1.aarch64.rpm
```

Archive internals are as D34 and D20 require — binary at the root, `man/` and `completions/`
riding along:

```
$ tar -tzf dist/rustow_v0.0.0_linux_arm64.tar.gz
LICENSE  README.md  completions/_rustow  completions/rustow.bash
completions/rustow.fish  man/rustow.8  rustow
```

and the extracted arm64 binary is `ELF 64-bit … ARM aarch64 … dynamically linked … stripped`.

**Caveat on `signs:` — the signature was NOT produced by cosign.** Keyless `sign-blob` needs
Fulcio/OIDC, unavailable in a local spike, so `cosign` was replaced on `PATH` by a shim that
writes a placeholder file at the `--bundle=` path. What this proves is that the `signs:`
pipe wires up and fires identically under `builder: rust`, emitting
`<checksums>.sigstore.json` — which is expected, since `artifacts: checksum` signs a file
GoReleaser generated, and the signing pipe never sees the builder. It does **not** prove a
real cosign v3 signature. That gap is builder-independent (D35) and no Rust-specific risk is
INFERRED from it.

### 5. GoReleaser installs no toolchain, but does run `rustup target add` — SOURCED + VERIFIED

Directly from `build.go`, GoReleaser shells `rustup target add <target>` for each declared
target before building. It will **not** install cargo, rustup, zig or cargo-zigbuild. So the
Rust arm of the `language` input has to put all four on `PATH` — and `rustup` specifically,
not just a cargo binary, or target-add fails. Defaults if `targets:` is omitted:
`x86_64-unknown-linux-gnu`, `x86_64-apple-darwin`, `x86_64-pc-windows-gnu`,
`aarch64-unknown-linux-gnu`, `aarch64-apple-darwin`. Defaults are `tool: cargo`,
`command: zigbuild`.

### 6. darwin cross-compiles from linux with no macOS SDK — VERIFIED, with a caveat

Both `*-apple-darwin` targets built on this Linux box and yielded a real
`Mach-O 64-bit arm64 executable`. The linker warned it could not find `MacOSX.sdk` via
`xcrun` and proceeded. Warnings only, exit 0.

That the *shape* survives is settled. Whether an SDK-less darwin binary is fit to ship
(SDK version stamping, symbol availability, notarization) is **not** something this spike
answers and is not INFERRED here — it belongs to
[the build-path ticket](https://github.com/rocne/release-ci/issues/64).

### 7. Two things this spike did not test, both worth their own decision

**Version injection has no Rust equivalent of `-ldflags -X`.** `release.yml` passes
`VERSION: ${{ inputs.version }}` into the GoReleaser step, and every Go consumer injects it
with `ldflags: -X main.version={{.Env.VERSION}}`. Rust has no such seam — the spike binary
read `env!("CARGO_PKG_VERSION")`, i.e. the version baked into `Cargo.toml` at compile time.
A Rust consumer therefore needs `Cargo.toml` bumped in the release-please PR for the D30
`--version` contract to report the tag, where a Go consumer needs nothing. This spike did
not exercise it. The current `release-please-config.json` uses `"release-type": "go"`.

**man page and completions generation.** The spike used *stub* files, because D34 only cares
that they are in the archive. Producing them for real (`clap_mangen` / `clap_complete`)
against the Go consumers' `go:generate` equivalent is untested and is already fog on the map.

### 8. One non-contract difference worth knowing — VERIFIED

The intermediate per-target directory inside `dist/` is named by raw triple —
`rustow_x86_64-unknown-linux-gnu` — where a Go build yields `gostow_linux_amd64_v1`. This is
outside D34 and the assert correctly ignores it (`-maxdepth 1 -type f`). It only matters to
anything that globs `dist/` subdirectories by GOOS-style names; nothing in release-ci does
today.

## What this changes

- [#66](https://github.com/rocne/release-ci/issues/66) is answered: no D34 change is needed
  to accommodate Rust, and no Rust-specific case needs adding to
  `assert-artifact-shape.sh` — it is already builder-agnostic.
- [#65](https://github.com/rocne/release-ci/issues/65) inherits a hard constraint from
  finding 3: the D34 name template admits one libc per os/arch.
- [#64](https://github.com/rocne/release-ci/issues/64) inherits findings 5 and 6: the
  toolchain arm must supply rustup + zig + cargo-zigbuild, and the SDK-less darwin question
  is live.
- Finding 7's version-injection gap is a new decision, not covered by any ticket that
  existed when this spike started.
