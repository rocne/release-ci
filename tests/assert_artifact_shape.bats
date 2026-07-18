#!/usr/bin/env bats
# The D34 artifact-shape contract, asserted against synthetic dist/ trees that
# mirror GoReleaser's snapshot output (#24). No goreleaser here: the script
# reads a directory of files, so the fixtures are just files. Runs under
# $SUT_SHELL (CI: bash and dash), same discipline as the installer suite.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SUT_SHELL="${SUT_SHELL:-sh}"
  SUT="$REPO_ROOT/release-dryrun/assert-artifact-shape.sh"
  DIST="$BATS_TEST_TMPDIR/dist"
  mkdir -p "$DIST"
}

# archive PROJECT TAG OS ARCH [rootpath-of-binary] — write a tar.gz holding a
# binary. rootpath defaults to the project name at the archive root.
archive() {
  local proj="$1" tag="$2" os="$3" arch="$4" binpath="${5:-$1}"
  local stage="$BATS_TEST_TMPDIR/stage.$RANDOM"
  mkdir -p "$stage/$(dirname "$binpath")"
  echo bin >"$stage/$binpath"
  tar -C "$stage" -czf "$DIST/${proj}_${tag}_${os}_${arch}.tar.gz" "$binpath"
}

checksums() { # PROJECT TAG [skip]  — skip ∈ {"", nosig, nopem, nofile}
  local proj="$1" tag="$2" skip="${3:-}"
  local f="$DIST/${proj}_${tag}_checksums.txt"
  [ "$skip" = nofile ] && return 0
  echo "abc  ${proj}_${tag}_linux_amd64.tar.gz" >"$f"
  [ "$skip" = nosig ] || echo sig >"$f.sig"
  [ "$skip" = nopem ] || echo pem >"$f.pem"
}

good_dist() { # a full, conformant snapshot: two platforms, signed checksums
  archive gostow v0.0.0-dryrun linux amd64
  archive gostow v0.0.0-dryrun darwin arm64
  checksums gostow v0.0.0-dryrun
}

@test "valid snapshot passes" {
  good_dist
  run "$SUT_SHELL" "$SUT" gostow "$DIST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK (gostow"* ]]
}

@test "bin-only archive (no man/completions) passes" {
  archive dotd v1.2.3 linux amd64
  checksums dotd v1.2.3
  run "$SUT_SHELL" "$SUT" dotd "$DIST"
  [ "$status" -eq 0 ]
}

@test "binary not at archive root fails" {
  archive gostow v0.0.0-dryrun linux amd64 bin/gostow
  checksums gostow v0.0.0-dryrun
  run "$SUT_SHELL" "$SUT" gostow "$DIST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not at the root"* ]]
}

@test "missing linux_amd64 fails the build-matrix floor" {
  archive gostow v0.0.0-dryrun darwin arm64
  checksums gostow v0.0.0-dryrun
  run "$SUT_SHELL" "$SUT" gostow "$DIST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no linux_amd64 archive"* ]]
}

@test "missing checksums signature fails" {
  archive gostow v0.0.0-dryrun linux amd64
  checksums gostow v0.0.0-dryrun nosig
  run "$SUT_SHELL" "$SUT" gostow "$DIST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"signature missing"* ]]
}

@test "missing checksums certificate fails" {
  archive gostow v0.0.0-dryrun linux amd64
  checksums gostow v0.0.0-dryrun nopem
  run "$SUT_SHELL" "$SUT" gostow "$DIST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"certificate missing"* ]]
}

@test "missing checksums file fails" {
  archive gostow v0.0.0-dryrun linux amd64
  checksums gostow v0.0.0-dryrun nofile
  run "$SUT_SHELL" "$SUT" gostow "$DIST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no checksums file"* ]]
}

@test "misnamed archive (wrong prefix / too few fields) fails" {
  good_dist
  mv "$DIST/gostow_v0.0.0-dryrun_darwin_arm64.tar.gz" "$DIST/gostow_darwin.tar.gz"
  run "$SUT_SHELL" "$SUT" gostow "$DIST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not match the contract"* ]]
}

@test "empty dist (no archives) fails" {
  checksums gostow v0.0.0-dryrun
  run "$SUT_SHELL" "$SUT" gostow "$DIST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no .tar.gz archives"* ]]
}

@test "missing project argument is a usage error (exit 2)" {
  run "$SUT_SHELL" "$SUT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no project name"* ]]
}

@test "missing dist directory is a usage error (exit 2)" {
  run "$SUT_SHELL" "$SUT" gostow "$BATS_TEST_TMPDIR/nonexistent"
  [ "$status" -eq 2 ]
  [[ "$output" == *"dist directory not found"* ]]
}
