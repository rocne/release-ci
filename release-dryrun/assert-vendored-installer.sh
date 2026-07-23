#!/usr/bin/env sh
# assert-vendored-installer.sh — assert a consumer's vendored install.sh has not
# drifted from the canonical release-ci installer. Everything outside the
# per-consumer "vendored config" block must be byte-identical to the canonical
# copy in the same release-ci tree (DESIGN.md §6.3, D5/D6, D36): the block holds
# the only sanctioned per-consumer values (REPO/BIN/SIGNER_REPO), so any diff
# elsewhere is a propagation bug — the class that left consumers on the old
# cosign-v2 verify path after the v3 installer shipped upstream (#52).
#
# Canonical source: rocne/release-ci, release-dryrun/assert-vendored-installer.sh;
# consumed by each consumer via a tag-pinned checkout of release-ci (owned once,
# never copied) and run in its own CI against its repo-root install.sh, so a
# vendored copy that drifts fails the consumer's CI instead of a user's install.
# Consumer-side by design: the upstream never enumerates its consumers (#29) —
# each consumer checks its own copy against the release-ci tag it already pins.
#
# Usage:  assert-vendored-installer.sh <consumer-install.sh> [canonical-install.sh]
#   <consumer-install.sh>   the vendored copy to check (e.g. ./install.sh).
#   canonical-install.sh    defaults to installer/install.sh in this script's own
#                           release-ci tree ($script_dir/../installer/install.sh).
#
# Exit: 0 identical outside the config block; 1 drift; 2 usage/structural error.

set -eu

CONSUMER="${1:-}"

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
CANONICAL="${2:-$script_dir/../installer/install.sh}"

if [ -z "$CONSUMER" ]; then
  echo "error: no consumer install.sh given" >&2
  echo "hint:  assert-vendored-installer.sh <consumer-install.sh> [canonical-install.sh]" >&2
  exit 2
fi
for f in "$CONSUMER" "$CANONICAL"; do
  if [ ! -f "$f" ]; then
    echo "error: file not found: $f" >&2
    exit 2
  fi
done

# The config block is delimited by exactly one start and one end marker. A copy
# missing them is not a vendored install.sh this check can reason about — fail
# loudly rather than silently pass (or mis-strip) a mangled file.
START='# ---- vendored config'
END='# ---- end vendored config'
for f in "$CONSUMER" "$CANONICAL"; do
  s=$(grep -c "^$START" "$f" || true)
  e=$(grep -c "^$END" "$f" || true)
  if [ "$s" != 1 ] || [ "$e" != 1 ]; then
    echo "::error::vendored-config markers not found exactly once in $f (start=$s end=$e)" >&2
    echo "  expected one '$START ...' line and one '$END ...' line" >&2
    exit 2
  fi
done

# Drop the block's contents (between the markers; the markers themselves are
# kept, so the surrounding lines stay aligned) so the sanctioned per-consumer
# values never register as drift; everything else is compared verbatim.
strip_block() {
  awk -v s="$START" -v e="$END" '
    index($0, s) == 1 { print; skip = 1; next }
    index($0, e) == 1 { skip = 0; print; next }
    skip { next }
    { print }
  ' "$1"
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
strip_block "$CANONICAL" >"$work/canonical"
strip_block "$CONSUMER" >"$work/consumer"

if diff -u "$work/canonical" "$work/consumer" >"$work/diff" 2>&1; then
  echo "vendored-installer drift check: OK ($CONSUMER matches canonical outside the config block)"
  exit 0
fi

echo "::error::vendored install.sh has drifted from the canonical release-ci installer: $CONSUMER" >&2
echo "  everything outside the '# ---- vendored config ----' block must be byte-identical (DESIGN.md D36)." >&2
echo "  re-vendor install.sh from the pinned release-ci tag to resolve. Diff (canonical > vendored):" >&2
sed 's/^/    /' "$work/diff" >&2
exit 1
