#!/usr/bin/env bats
# The D30 --version parse rule, asserted against synthetic `--version` output
# (#15). The script reads the output on stdin, so the fixtures are just strings —
# no live binary. Runs under $SUT_SHELL (CI: bash and dash), same discipline as
# the assert-artifact-shape suite.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SUT_SHELL="${SUT_SHELL:-sh}"
  SUT="$REPO_ROOT/release-dryrun/assert-version-contract.sh"
}

# avc VERSION_OUTPUT [expected-version] — feed the first arg on stdin, pass any
# remaining args through to the script. Wrapped so `run` can capture it.
avc() {
  local out="$1"; shift
  printf '%s\n' "$out" | "$SUT_SHELL" "$SUT" "$@"
}

@test "conformant first line passes (parse-only), parsing the tool's own version" {
  run avc "gostow 0.4.0 (GNU Stow 2.4.1 compatible)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK (parsed 0.4.0)"* ]]
}

@test "the FIRST semver token wins over a later compat version" {
  # gostow prints its own 0.4.0 before stow's 2.4.1 — the ordering is load-bearing.
  run avc "gostow 0.4.0 (GNU Stow 2.4.1 compatible)"
  [ "$status" -eq 0 ]
  [[ "$output" != *"2.4.1"* ]]
}

@test "equals-version match passes (the release-time check)" {
  run avc "gostow 0.4.0 (GNU Stow 2.4.1 compatible)" 0.4.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"matches 0.4.0"* ]]
}

@test "equals-version mismatch fails" {
  run avc "gostow 0.4.0 (GNU Stow 2.4.1 compatible)" 0.5.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not match the release"* ]]
}

@test "leading v is ignored on the output side" {
  run avc "foo v1.2.3" 1.2.3
  [ "$status" -eq 0 ]
}

@test "leading v is ignored on the expected side" {
  run avc "foo 1.2.3" v1.2.3
  [ "$status" -eq 0 ]
}

@test "snapshot pseudo-version passes parse-only (tag-agnostic dry-run check)" {
  run avc "gostow 0.0.0-dryrun"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK (parsed 0.0.0-dryrun)"* ]]
}

@test "prerelease + build metadata parses as one token" {
  run avc "x 1.2.3-rc.1+b.5 extra" 1.2.3-rc.1+b.5
  [ "$status" -eq 0 ]
}

@test "go-style embedded semver parses (go1.21.0 -> 1.21.0)" {
  run avc "go version go1.21.0 linux/amd64"
  [ "$status" -eq 0 ]
  [[ "$output" == *"parsed 1.21.0"* ]]
}

@test "no semver on the first line fails, even if a later line has one" {
  # The rule is line-1-only: a version buried on line 2 does not satisfy it.
  run avc "$(printf 'mytool\nversion 1.2.3')"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no semver token on the first line"* ]]
}

@test "empty input is a usage error (exit 2)" {
  run avc ""
  [ "$status" -eq 2 ]
  [[ "$output" == *"no --version output"* ]]
}
