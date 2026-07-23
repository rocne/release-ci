#!/usr/bin/env sh
# assert-vendored-installer.sh — assert a consumer's vendored install.sh has not
# drifted from the canonical release-ci installer. Everything outside the
# per-consumer "vendored config" block must be byte-identical to the canonical
# copy in the same release-ci tree (DESIGN.md §6.3, D5/D6, D36): the block holds
# the only sanctioned per-consumer values (REPO/BIN/SIGNER_REPO), so any diff
# elsewhere is a propagation bug — the class that left consumers on the old
# cosign-v2 verify path after the v3 installer shipped upstream (#52).
#
# The block itself is diff-exempt, so its contents are also constrained (D37):
# only comments and assignments to the three sanctioned variables may appear
# between the markers, or the block becomes a place to hide arbitrary lines from
# the byte-identity diff. This gate is also run non-bypassably from the inherited
# release.yml, so a drifted install.sh blocks a signed release (D37).
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
# Exit: 0 identical outside the config block and the block is well-formed;
#       1 drift, or an unsanctioned line inside the config block;
#       2 usage/structural error.

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

# The config block is diff-exempt, so whatever a consumer puts between the
# markers is otherwise unchecked — an injection point that hides from the
# byte-identity diff (D37). Constrain it: inside the block only comments, blank
# lines, and assignments to the three sanctioned variables (REPO, BIN,
# SIGNER_REPO), plus the canonical BIN default if a consumer keeps it in-block,
# are allowed. The quoted value forbids `$` and backtick (no expansion or
# command substitution), and the anchor forbids anything after the closing quote
# but whitespace and a comment (no `;`/`&&` statement chaining). Anything else is
# an unreviewed line the diff would silently pass — reject it. Only the consumer
# copy is validated; the canonical block is in-repo and reviewed.
validate_block() {
  awk -v s="$START" -v e="$END" '
    index($0, s) == 1 { inblk = 1; next }
    index($0, e) == 1 { inblk = 0; next }
    !inblk { next }
    /^[ \t]*$/ { next }                                                   # blank
    /^[ \t]*#/ { next }                                                   # comment
    /^(REPO|BIN|SIGNER_REPO)="[^"$`]*"[ \t]*(#.*)?$/ { next }             # sanctioned assignment
    # The in-block BIN default, as a STRING regex not a /.../ constant: it
    # contains a literal "/", which busybox/mawk lex as the end of a /.../ regex.
    $0 ~ "^BIN=\"[$][{]BIN:-[$][{]REPO##[*][/][}][}]\"[ \t]*(#.*)?$" { next }
    { print NR ": " $0; bad = 1 }
    END { exit bad ? 1 : 0 }
  ' "$1"
}

if ! offending=$(validate_block "$CONSUMER"); then
  echo "::error::vendored config block contains unsanctioned line(s): $CONSUMER" >&2
  echo "  only comments and REPO=/BIN=/SIGNER_REPO= assignments may appear between the" >&2
  echo "  '# ---- vendored config ----' markers — the block is diff-exempt, so any other" >&2
  echo "  line is an unreviewed injection point (DESIGN.md D37). Offending line(s):" >&2
  printf '%s\n' "$offending" | sed 's/^/    /' >&2
  exit 1
fi

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
