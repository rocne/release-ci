# Shared helpers for the installer test suite (DESIGN.md §6.11, D17).
#
# The suite runs against a real published release (gostow v0.4.0): real assets,
# real checksums, real cosign signatures — no mocked release server. The script
# under test runs under $SUT_SHELL (CI: bash and dash); bats itself is bash.

bats_require_minimum_version 1.5.0 # for run --separate-stderr

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SUT_SHELL="${SUT_SHELL:-sh}"

FIXTURE_REPO="rocne/gostow"
FIXTURE_TOOL="gostow"
FIXTURE_VERSION="0.4.0"   # the pinned fixture release
ALT_VERSION="0.3.0"       # a second real release, for ensure-mismatch cases

vendor_install_sh() { # DEST — mimic vendoring: set the config block
  sed -e "s|^REPO=\"\"|REPO=\"$FIXTURE_REPO\"|" \
      -e "s|^TOOL=\"\"|TOOL=\"$FIXTURE_TOOL\"|" \
      "$REPO_ROOT/installer/install.sh" >"$1"
}

vendor_snippet_sh() { # DEST
  sed -e "s|^RELEASE_CI_REPO=\"\"|RELEASE_CI_REPO=\"$FIXTURE_REPO\"|" \
      -e "s|^RELEASE_CI_TOOL=\"\"|RELEASE_CI_TOOL=\"$FIXTURE_TOOL\"|" \
      "$REPO_ROOT/installer/snippet.sh" >"$1"
}

# Every test gets an isolated HOME and XDG tree: the installer writes extras
# into XDG locations, and tests must never touch the real ones.
common_setup() {
  WORK="$BATS_TEST_TMPDIR"
  export HOME="$WORK/home"
  mkdir -p "$HOME"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_CONFIG_HOME="$HOME/.config"
  unset XDG_BIN_HOME GOSTOW_INSTALL_DIR GOSTOW_INSTALL_LOG_LEVEL
  INSTALL_DIR="$WORK/bin"
  SUT="$WORK/install.sh"
  vendor_install_sh "$SUT"
}

# A real fixture binary, downloaded once per suite run and cached.
fixture_binary() {
  local cache="$BATS_SUITE_TMPDIR/fixture"
  if [ ! -x "$cache/$FIXTURE_TOOL" ]; then
    mkdir -p "$cache"
    curl -fsSL -o "$cache/fixture.tar.gz" \
      "https://github.com/$FIXTURE_REPO/releases/download/v$FIXTURE_VERSION/${FIXTURE_TOOL}_v${FIXTURE_VERSION}_linux_amd64.tar.gz"
    tar -xzf "$cache/fixture.tar.gz" -C "$cache" "$FIXTURE_TOOL"
  fi
  echo "$cache/$FIXTURE_TOOL"
}

# True iff the fixture release publishes a cosign v3 Sigstore bundle beside its
# checksums. gostow v0.4.0 predates the v3 migration (#45) and carries the old
# detached .sig/.pem instead; the signature-verify tests skip against such a
# release and auto-run once FIXTURE_VERSION advances to a re-pressed one.
fixture_has_bundle() {
  curl -fsSL -o /dev/null \
    "https://github.com/$FIXTURE_REPO/releases/download/v$FIXTURE_VERSION/${FIXTURE_TOOL}_v${FIXTURE_VERSION}_checksums.txt.sigstore.json" \
    2>/dev/null
}

# run_sut ARGS... — run the vendored script under $SUT_SHELL. stdout must be
# empty on every path (the stderr-only convention), so that is asserted here,
# once, for every invocation in the suite.
run_sut() {
  run --separate-stderr "$SUT_SHELL" "$SUT" "$@"
  assert_stdout_empty
}

assert_stdout_empty() {
  if [ -n "$output" ]; then
    echo "expected empty stdout, got: $output" >&2
    return 1
  fi
}

assert_stderr_contains() {
  case "$stderr" in
    *"$1"*) ;;
    *) echo "expected stderr to contain [$1], got: $stderr" >&2; return 1 ;;
  esac
}

assert_stderr_empty() {
  if [ -n "$stderr" ]; then
    echo "expected empty stderr, got: $stderr" >&2
    return 1
  fi
}

assert_stderr_lacks() {
  case "$stderr" in
    *"$1"*) echo "expected stderr to lack [$1], got: $stderr" >&2; return 1 ;;
  esac
}

assert_status() {
  if [ "$status" -ne "$1" ]; then
    echo "expected exit $1, got $status; stderr: $stderr" >&2
    return 1
  fi
}

mtime_of() { stat -c %Y "$1"; }

# place_fixture DIR — put the real fixture binary at DIR/gostow with an old
# mtime, so a reinstall is detectable as an mtime change.
place_fixture() {
  mkdir -p "$1"
  cp "$(fixture_binary)" "$1/$FIXTURE_TOOL"
  chmod +x "$1/$FIXTURE_TOOL"
  touch -t 202001010000 "$1/$FIXTURE_TOOL"
}
