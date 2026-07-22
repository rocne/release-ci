#!/usr/bin/env bats
# The rc snippet (D26, §6.7): sourced from a user's shell rc, so the tests
# exercise it *sourced*, under $SUT_SHELL, and assert it can never break shell
# startup or leak variables into the user's shell.

load 'helpers'

setup() {
  common_setup
  SNIPPET="$WORK/snippet.sh"
  vendor_snippet_sh "$SNIPPET"
}

# make_present_shim — a dir holding a fake tool, so the snippet's guard
# short-circuits; echoes the dir. For tests that must not install anything.
make_present_shim() {
  mkdir -p "$WORK/present"
  printf '#!/bin/sh\nexit 0\n' >"$WORK/present/$FIXTURE_TOOL"
  chmod +x "$WORK/present/$FIXTURE_TOOL"
  echo "$WORK/present"
}

# source_snippet PRE_CMDS — source in a fresh shell; report leaks and PATH.
source_snippet() {
  run --separate-stderr "$SUT_SHELL" -c "
    $1
    . '$SNIPPET'
    rc=\$?
    [ -z \"\${RELEASE_CI_REPO+x}\" ] && [ -z \"\${RELEASE_CI_BIN+x}\" ] || echo 'LEAK' >&2
    echo \"PATH=\$PATH\" >&2
    exit \$rc
  "
}

@test "the canonical unvendored snippet is a silent no-op" {
  run --separate-stderr "$SUT_SHELL" -c ". '$REPO_ROOT/installer/snippet.sh'; echo ok >&2"
  assert_stdout_empty
  assert_status 0
  assert_stderr_contains "ok"
  assert_stderr_lacks "error"
}

@test "sourcing prepends ~/.local/bin to PATH exactly once (idempotent)" {
  local shim
  shim=$(make_present_shim)
  run --separate-stderr "$SUT_SHELL" -c "
    PATH='$shim':\"\$PATH\"
    . '$SNIPPET'; . '$SNIPPET'
    echo \":\$PATH:\" >&2
  "
  assert_stdout_empty
  assert_status 0
  local count
  count=$(printf '%s\n' "$stderr" | grep -o "$HOME/.local/bin:" | wc -l)
  [ "$count" -eq 1 ]
}

@test "no leaked variables after sourcing" {
  local shim
  shim=$(make_present_shim)
  source_snippet "PATH='$shim':\"\$PATH\""
  assert_stdout_empty
  assert_stderr_lacks "LEAK"
}

@test "tool present: the guard short-circuits before any network" {
  local shim="$WORK/shim"
  mkdir -p "$shim"
  printf '#!/bin/sh\necho "curl should never run" >&2\nexit 9\n' >"$shim/curl"
  chmod +x "$shim/curl"
  printf '#!/bin/sh\nexit 0\n' >"$shim/$FIXTURE_TOOL"
  chmod +x "$shim/$FIXTURE_TOOL"
  source_snippet "PATH='$shim':\"\$PATH\""
  assert_stdout_empty
  assert_status 0
  assert_stderr_lacks "curl should never run"
}

@test "no curl: skips silently — an rc file must never break shell startup" {
  local bare="$WORK/bare"
  mkdir -p "$bare"
  source_snippet "PATH='$bare'"
  assert_stdout_empty
  assert_status 0
  assert_stderr_lacks "LEAK"
}

@test "tool absent: bootstraps through the canonical installer end-to-end" {
  # curl shim: serve the local vendored install.sh for the raw-on-main URL, so
  # the snippet exercises OUR script against the real release rather than
  # whatever the consumer's repo currently vendors; everything else passes
  # through to real curl.
  local shim="$WORK/shim" real_curl
  real_curl=$(command -v curl)
  mkdir -p "$shim"
  cat >"$shim/curl" <<EOF
#!/bin/sh
case "\$*" in
  *raw.githubusercontent.com/$FIXTURE_REPO/main/install.sh*) exec cat '$SUT' ;;
esac
exec "$real_curl" "\$@"
EOF
  chmod +x "$shim/curl"
  source_snippet "PATH='$shim':\"\$PATH\""
  assert_stdout_empty
  assert_status 0
  assert_stderr_contains "installed:"
  [ -x "$HOME/.local/bin/$FIXTURE_TOOL" ]
  # B1: the snippet's PATH prepend means the fresh install resolves immediately
  assert_stderr_contains "$HOME/.local/bin"
  assert_stderr_lacks "LEAK"
}
