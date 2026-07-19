#!/usr/bin/env bats
# Targeted behavior beyond the floor matrix: the canonical-copy abort (D22),
# --help under piped stdin (D33), usage errors, truncation safety (D31),
# mandatory checksum including a real corrupted download (F4), offline no-op
# and dry-run, install-dir and log-level resolution (D8/D9/D11/D21), ensure
# semantics and degradation (D28/D30), shadow warning (D16), extras (D20),
# and the cosign paths (F5).

load 'helpers'

setup() { common_setup; }

# ---- canonical copy and usage (D22, D33) ------------------------------------

@test "canonical unvendored copy aborts with a usage error" {
  run --separate-stderr "$SUT_SHELL" "$REPO_ROOT/installer/install.sh"
  assert_stdout_empty
  assert_status 2
  assert_stderr_contains "canonical source"
  assert_stderr_contains "hint:"
}

@test "canonical abort still speaks under --silent (F6: errors are never suppressed)" {
  run --separate-stderr "$SUT_SHELL" "$REPO_ROOT/installer/install.sh" --silent
  assert_stdout_empty
  assert_status 2
  assert_stderr_contains "error:"
}

@test "--help works when piped to sh -s (D33: the mode the sed-\$0 idiom broke in)" {
  run --separate-stderr bash -c "cat '$SUT' | '$SUT_SHELL' -s -- --help"
  assert_stdout_empty
  assert_status 0
  assert_stderr_contains "Usage:"
  assert_stderr_contains "--version vX.Y.Z"
}

@test "--help works on the unvendored canonical copy" {
  run --separate-stderr "$SUT_SHELL" "$REPO_ROOT/installer/install.sh" --help
  assert_stdout_empty
  assert_status 0
  assert_stderr_contains "Usage:"
}

@test "unknown flag is a usage error (exit 2)" {
  run_sut --nope
  assert_status 2
  assert_stderr_contains "unknown argument"
}

@test "--version without an argument is a usage error" {
  run_sut --version
  assert_status 2
}

@test "--version with an empty argument is a usage error" {
  run_sut --version ""
  assert_status 2
}

@test "--version with a non-semver argument is a usage error" {
  run_sut --version banana
  assert_status 2
  assert_stderr_contains "v0.2.0"
}

@test "unknown log level in the env var is a usage error" {
  GOSTOW_INSTALL_LOG_LEVEL=chatty run_sut --dry-run --version "v$FIXTURE_VERSION"
  assert_status 2
  assert_stderr_contains "unknown log level"
}

# ---- truncation safety (D31) ------------------------------------------------

@test "a truncated script executes nothing" {
  local size cut
  size=$(wc -c <"$SUT")
  for pct in 30 60 90; do
    cut=$((size * pct / 100))
    run --separate-stderr bash -c "head -c $cut '$SUT' | '$SUT_SHELL'"
    assert_stdout_empty
    [ ! -e "$INSTALL_DIR/$FIXTURE_TOOL" ]
  done
}

# ---- non-file at the install path -------------------------------------------

@test "a directory at the install path is an error, not a false success" {
  mkdir -p "$INSTALL_DIR/$FIXTURE_TOOL" # a DIRECTORY named like the tool
  local shim="$WORK/shim"
  mkdir -p "$shim"
  printf '#!/bin/sh\necho "curl should never run" >&2\nexit 9\n' >"$shim/curl"
  chmod +x "$shim/curl"
  PATH="$shim:$PATH" run_sut --install-dir "$INSTALL_DIR"
  assert_status 1
  assert_stderr_contains "not a regular file"
  assert_stderr_lacks "curl should never run"
  [ -d "$INSTALL_DIR/$FIXTURE_TOOL" ]
}

@test "--force over a directory at the install path still aborts honestly" {
  mkdir -p "$INSTALL_DIR/$FIXTURE_TOOL"
  run_sut --install-dir "$INSTALL_DIR" --force --bin-only
  assert_status 1
  assert_stderr_contains "not a regular file"
  [ -z "$(ls -A "$INSTALL_DIR/$FIXTURE_TOOL")" ] # nothing smuggled inside it
}

# ---- latest-resolution failures (D32) ----------------------------------------

@test "a repo with no releases gets an honest error, not a network hint" {
  local shim="$WORK/shim"
  mkdir -p "$shim"
  cat >"$shim/curl" <<'EOF'
#!/bin/sh
# GitHub's verified behavior for a 0-release repo (rocne/hud, 2026-07-18):
# -f fails with rc 22 while -w still emits the code and final URL.
printf '404 https://github.com/rocne/gostow/releases/latest'
exit 22
EOF
  chmod +x "$shim/curl"
  PATH="$shim:$PATH" run_sut --install-dir "$INSTALL_DIR"
  assert_status 1
  assert_stderr_contains "no published release yet"
  assert_stderr_lacks "check the network"
}

@test "a network failure resolving latest blames the network" {
  local shim="$WORK/shim"
  mkdir -p "$shim"
  cat >"$shim/curl" <<'EOF'
#!/bin/sh
printf '000 https://github.com/rocne/gostow/releases/latest'
exit 6
EOF
  chmod +x "$shim/curl"
  PATH="$shim:$PATH" run_sut --install-dir "$INSTALL_DIR"
  assert_status 1
  assert_stderr_contains "check the network"
}

# ---- mandatory checksum (F4) ------------------------------------------------

@test "no sha256sum/shasum on PATH aborts before any download" {
  local shim="$WORK/shim"
  mkdir -p "$shim"
  ln -s "$(command -v tr)" "$shim/tr"
  printf '#!/bin/sh\necho "curl should never run" >&2\nexit 9\n' >"$shim/curl"
  chmod +x "$shim/curl"
  run --separate-stderr env PATH="$shim" "$(command -v "$SUT_SHELL")" "$SUT" --install-dir "$INSTALL_DIR"
  assert_stdout_empty
  assert_status 1
  assert_stderr_contains "cannot verify download integrity"
  assert_stderr_lacks "curl should never run"
  [ ! -e "$INSTALL_DIR/$FIXTURE_TOOL" ]
}

@test "a corrupted download fails the checksum and nothing is installed" {
  local shim="$WORK/shim" real_curl
  real_curl=$(command -v curl)
  mkdir -p "$shim"
  cat >"$shim/curl" <<EOF
#!/bin/sh
# pass through to real curl, then corrupt any downloaded tarball
"$real_curl" "\$@" || exit \$?
out=""
while [ \$# -gt 0 ]; do
  if [ "\$1" = "-o" ]; then out="\$2"; shift 2; else shift; fi
done
case "\$out" in *.tar.gz) printf X >>"\$out" ;; esac
EOF
  chmod +x "$shim/curl"
  PATH="$shim:$PATH" run_sut --install-dir "$INSTALL_DIR" --version "v$FIXTURE_VERSION"
  assert_status 1
  assert_stderr_contains "checksum mismatch"
  [ ! -e "$INSTALL_DIR/$FIXTURE_TOOL" ]
}

# ---- no network on the no-op and dry-run paths ------------------------------

@test "presence no-op touches no network (F1)" {
  place_fixture "$INSTALL_DIR"
  local shim="$WORK/shim"
  mkdir -p "$shim"
  printf '#!/bin/sh\necho "curl should never run" >&2\nexit 9\n' >"$shim/curl"
  chmod +x "$shim/curl"
  PATH="$shim:$PATH" run_sut --install-dir "$INSTALL_DIR"
  assert_status 0
  assert_stderr_lacks "curl should never run"
}

@test "--dry-run --version resolves offline and prints the plan" {
  local shim="$WORK/shim"
  mkdir -p "$shim"
  printf '#!/bin/sh\necho "curl should never run" >&2\nexit 9\n' >"$shim/curl"
  chmod +x "$shim/curl"
  PATH="$shim:$PATH" run_sut --install-dir "$INSTALL_DIR" --dry-run --version "v$FIXTURE_VERSION"
  assert_status 0
  assert_stderr_contains "release:  v$FIXTURE_VERSION"
  assert_stderr_contains "install:  $INSTALL_DIR/$FIXTURE_TOOL"
  assert_stderr_contains "(dry-run: no changes made)"
  assert_stderr_lacks "curl should never run"
  [ ! -e "$INSTALL_DIR/$FIXTURE_TOOL" ]
}

# ---- install-dir resolution (D8/D9/D11/D21) ---------------------------------

resolved_install_line() { # ARGS... — echo the dry-run's resolved install path
  run_sut --dry-run --version "v$FIXTURE_VERSION" "$@"
  assert_status 0
  printf '%s\n' "$stderr" | sed -n 's/^install:  //p'
}

@test "install dir defaults to ~/.local/bin (F3)" {
  [ "$(resolved_install_line)" = "$HOME/.local/bin/$FIXTURE_TOOL" ]
}

@test "XDG_BIN_HOME overrides the default" {
  export XDG_BIN_HOME="$WORK/xdg-bin"
  [ "$(resolved_install_line)" = "$WORK/xdg-bin/$FIXTURE_TOOL" ]
}

@test "namespaced env var beats XDG_BIN_HOME" {
  export XDG_BIN_HOME="$WORK/xdg-bin" GOSTOW_INSTALL_DIR="$WORK/env-bin"
  [ "$(resolved_install_line)" = "$WORK/env-bin/$FIXTURE_TOOL" ]
}

@test "--install-dir beats the namespaced env var" {
  export GOSTOW_INSTALL_DIR="$WORK/env-bin"
  [ "$(resolved_install_line --install-dir "$WORK/flag-bin")" = "$WORK/flag-bin/$FIXTURE_TOOL" ]
}

@test "bare INSTALL_DIR is dead (D21): it is ignored outright" {
  export INSTALL_DIR="$WORK/bare-bin"
  [ "$(resolved_install_line)" = "$HOME/.local/bin/$FIXTURE_TOOL" ]
}

# ---- log level via environment (D8-class namespacing) -----------------------

@test "GOSTOW_INSTALL_LOG_LEVEL=quiet silences the no-op line" {
  place_fixture "$INSTALL_DIR"
  GOSTOW_INSTALL_LOG_LEVEL=quiet run_sut --install-dir "$INSTALL_DIR"
  assert_status 0
  assert_stderr_empty
}

@test "a level flag beats the env var" {
  place_fixture "$INSTALL_DIR"
  GOSTOW_INSTALL_LOG_LEVEL=silent run_sut --install-dir "$INSTALL_DIR" --verbose
  assert_status 0
  assert_stderr_contains "already installed"
}

# ---- ensure semantics and degradation (D28/D30) -----------------------------

@test "ensure repairs a broken binary at the install path (D28 degradation)" {
  mkdir -p "$INSTALL_DIR"
  printf 'not a binary\n' >"$INSTALL_DIR/$FIXTURE_TOOL"
  run_sut --install-dir "$INSTALL_DIR" --version "v$FIXTURE_VERSION"
  assert_status 0
  assert_stderr_contains "installed:"
  run --separate-stderr "$INSTALL_DIR/$FIXTURE_TOOL" --version
  assert_status 0
  case "$output" in *"$FIXTURE_VERSION"*) ;; *) return 1 ;; esac
}

@test "without --version, a broken binary still counts as present (F1)" {
  mkdir -p "$INSTALL_DIR"
  printf 'not a binary\n' >"$INSTALL_DIR/$FIXTURE_TOOL"
  local pre_mtime
  pre_mtime=$(mtime_of "$INSTALL_DIR/$FIXTURE_TOOL")
  run_sut --install-dir "$INSTALL_DIR"
  assert_status 0
  assert_stderr_contains "already installed"
  [ "$(mtime_of "$INSTALL_DIR/$FIXTURE_TOOL")" = "$pre_mtime" ]
}

@test "an unsatisfied --version installs past a copy elsewhere on PATH, and warns (D16)" {
  place_fixture "$WORK/elsewhere"
  export PATH="$WORK/elsewhere:$PATH"
  run_sut --install-dir "$INSTALL_DIR" --version "v$ALT_VERSION"
  assert_status 0
  assert_stderr_contains "does not satisfy"
  assert_stderr_contains "shadow"
  run --separate-stderr "$INSTALL_DIR/$FIXTURE_TOOL" --version
  case "$output" in *"$ALT_VERSION"*) ;; *) return 1 ;; esac
}

# ---- PATH reminder ----------------------------------------------------------

@test "an install to a dir off PATH gets the PATH reminder" {
  run_sut --install-dir "$INSTALL_DIR" --version "v$FIXTURE_VERSION"
  assert_status 0
  assert_stderr_contains "not on your PATH"
}

@test "an install to a dir on PATH gets no PATH reminder" {
  mkdir -p "$INSTALL_DIR"
  PATH="$INSTALL_DIR:$PATH" run_sut --install-dir "$INSTALL_DIR" --version "v$FIXTURE_VERSION"
  assert_status 0
  assert_stderr_lacks "not on your PATH"
}

# ---- extras (D20): look, don't ask ------------------------------------------

@test "man page and completions install from the archive into XDG locations" {
  run_sut --install-dir "$INSTALL_DIR" --version "v$FIXTURE_VERSION"
  assert_status 0
  [ -f "$XDG_DATA_HOME/man/man8/$FIXTURE_TOOL.8" ]
  [ -f "$XDG_DATA_HOME/bash-completion/completions/$FIXTURE_TOOL" ]
  [ -f "$XDG_DATA_HOME/zsh/site-functions/_$FIXTURE_TOOL" ]
  [ -f "$XDG_CONFIG_HOME/fish/completions/$FIXTURE_TOOL.fish" ]
}

@test "--bin-only declines the extras cleanly" {
  run_sut --install-dir "$INSTALL_DIR" --version "v$FIXTURE_VERSION" --bin-only
  assert_status 0
  [ -x "$INSTALL_DIR/$FIXTURE_TOOL" ]
  [ ! -e "$XDG_DATA_HOME/man" ]
  [ ! -e "$XDG_DATA_HOME/bash-completion" ]
}

# ---- cosign (F5): opportunistic, hardenable ---------------------------------

@test "with cosign present, the signature is verified" {
  command -v cosign >/dev/null 2>&1 || skip "cosign not installed here"
  fixture_has_bundle || skip "fixture v$FIXTURE_VERSION predates the cosign v3 bundle shape (#45)"
  run_sut --install-dir "$INSTALL_DIR" --version "v$FIXTURE_VERSION"
  assert_status 0
  assert_stderr_contains "signature verified"
}

@test "--require-signature succeeds when cosign is present" {
  command -v cosign >/dev/null 2>&1 || skip "cosign not installed here"
  fixture_has_bundle || skip "fixture v$FIXTURE_VERSION predates the cosign v3 bundle shape (#45)"
  run_sut --install-dir "$INSTALL_DIR" --version "v$FIXTURE_VERSION" --require-signature
  assert_status 0
  assert_stderr_contains "signature verified"
}

@test "without cosign, a notice is emitted and the install proceeds" {
  command -v cosign >/dev/null 2>&1 && skip "cosign is installed here"
  run_sut --install-dir "$INSTALL_DIR" --version "v$FIXTURE_VERSION"
  assert_status 0
  assert_stderr_contains "cosign not found"
  [ -x "$INSTALL_DIR/$FIXTURE_TOOL" ]
}

@test "--require-signature without cosign aborts (exit 1)" {
  command -v cosign >/dev/null 2>&1 && skip "cosign is installed here"
  run_sut --install-dir "$INSTALL_DIR" --version "v$FIXTURE_VERSION" --require-signature
  assert_status 1
  assert_stderr_contains "cosign is not installed"
  [ ! -e "$INSTALL_DIR/$FIXTURE_TOOL" ]
}
