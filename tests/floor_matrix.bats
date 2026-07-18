#!/usr/bin/env bats
# The floor, enumerated (D17):
#   {absent, present-at-install-path, present-on-PATH-elsewhere}
#     × {default, quiet, silent, verbose}
#     × {none, --force, --version}
# Cells are generated, not hand-written — the loops at the bottom register one
# bats test per cell, so adding a state, level, or flag extends the matrix
# without hand-edits. Exit code, output stream, and effect are asserted
# independently: F6 makes them independent dimensions.

load 'helpers'

setup() { common_setup; }

matrix_cell() {
  local state="$1" level="$2" flagkind="$3"
  local args=(--install-dir "$INSTALL_DIR")
  case "$level" in
    quiet)   args+=(--quiet) ;;
    silent)  args+=(--silent) ;;
    verbose) args+=(--verbose) ;;
  esac
  case "$flagkind" in
    force)   args+=(--force) ;;
    version) args+=(--version "v$FIXTURE_VERSION") ;;
  esac

  # -- arrange ---------------------------------------------------------------
  local pre_mtime=""
  case "$state" in
    present-install-path)
      place_fixture "$INSTALL_DIR"
      pre_mtime=$(mtime_of "$INSTALL_DIR/$FIXTURE_TOOL")
      ;;
    present-elsewhere)
      place_fixture "$WORK/elsewhere"
      export PATH="$WORK/elsewhere:$PATH"
      ;;
  esac

  # -- act -------------------------------------------------------------------
  run_sut "${args[@]}"

  # -- assert: exit code (every cell in this matrix succeeds or no-ops) ------
  assert_status 0

  # expected effect, derived from the axes alone
  local installed
  case "$state/$flagkind" in
    absent/*|*/force)       installed=yes ;;
    *)                      installed=no ;;
  esac

  # -- assert: stream (stdout already asserted empty by run_sut; the effect
  #    assertions below re-run commands, so streams are checked first) -------
  assert_stderr_lacks "error:"
  case "$level/$installed" in
    silent/*)    assert_stderr_empty ;;
    quiet/yes)   assert_stderr_contains "installed:" ;;
    quiet/no)    assert_stderr_empty ;;   # a no-op under --quiet says nothing
    */yes)       assert_stderr_contains "installed:" ;;
    */no)        [ -n "$stderr" ] ;;      # the no-op status line (F1)
  esac
  if [ "$level" = verbose ] && [ "$installed" = yes ]; then
    assert_stderr_contains "checksum verified"
  fi

  # -- assert: effect --------------------------------------------------------
  case "$state/$installed" in
    */yes)
      [ -x "$INSTALL_DIR/$FIXTURE_TOOL" ]
      if [ -n "$pre_mtime" ]; then
        [ "$(mtime_of "$INSTALL_DIR/$FIXTURE_TOOL")" != "$pre_mtime" ]
      fi
      if [ "$flagkind" = version ]; then
        run --separate-stderr "$INSTALL_DIR/$FIXTURE_TOOL" --version
        case "$output" in *"$FIXTURE_VERSION"*) ;; *) return 1 ;; esac
      fi
      ;;
    present-install-path/no)
      [ "$(mtime_of "$INSTALL_DIR/$FIXTURE_TOOL")" = "$pre_mtime" ]
      ;;
    present-elsewhere/no)
      [ ! -e "$INSTALL_DIR/$FIXTURE_TOOL" ]
      ;;
  esac
}

for state in absent present-install-path present-elsewhere; do
  for level in default quiet silent verbose; do
    for flagkind in none force version; do
      bats_test_function \
        --description "floor: $state × $level × $flagkind" \
        -- matrix_cell "$state" "$level" "$flagkind"
    done
  done
done
