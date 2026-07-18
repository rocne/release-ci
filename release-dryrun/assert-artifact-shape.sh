#!/usr/bin/env sh
# assert-artifact-shape.sh — assert the D34 artifact-shape contract against a
# GoReleaser dist/ directory. Canonical source: rocne/release-ci,
# release-dryrun/assert-artifact-shape.sh; consumed by each consumer via a
# tag-pinned checkout of release-ci (owned once, never copied) and called
# from its release-dryrun.yml after the snapshot build, so a drifting GoReleaser
# config fails its own dry-run instead of a user's install (#24, DESIGN.md D34).
#
# The contract (D34), all four elements checked here:
#   archive name     <project>_<tag>_<os>_<arch>.tar.gz
#   checksums name   <project>_<tag>_checksums.txt  (+ .sig and .pem beside it)
#   archive internals  the binary at the archive root (man/, completions/ when shipped)
#   build matrix     a linux_amd64 archive exists
#
# The check is tag-agnostic: it asserts the *shape* of the tag field, never a
# literal value, so snapshot builds (VERSION=v0.0.0-dryrun, or GoReleaser's
# -SNAPSHOT- suffix) pass exactly as a real release would.
#
# Usage:  assert-artifact-shape.sh <project> [dist-dir]
#   <project>   GoReleaser project_name, which is also the binary name and the
#               archive/checksums filename prefix (D34: ProjectName == binary).
#   dist-dir    defaults to ./dist
#
# Exit: 0 all elements present and shaped correctly; 1 a contract violation.

set -eu

PROJECT="${1:-}"
DIST="${2:-dist}"

if [ -z "$PROJECT" ]; then
  echo "error: no project name given" >&2
  echo "hint:  assert-artifact-shape.sh <project> [dist-dir]" >&2
  exit 2
fi
if [ ! -d "$DIST" ]; then
  echo "error: dist directory not found: $DIST" >&2
  echo "hint:  run the goreleaser snapshot build before this assertion" >&2
  exit 2
fi

fail=0
violation() {
  echo "::error::D34 artifact-shape contract violated: $1" >&2
  echo "  expected: $2" >&2
  fail=1
}

# The tag field is one-or-more chars with no underscore (underscore is the field
# separator). os and arch likewise. This matches gostow_v0.0.0-dryrun_linux_amd64.
tarball_re="^${PROJECT}_[^_]+_[^_]+_[^_]+\.tar\.gz$"

# --- element 1 + 2: archive names are correctly shaped ---
archives=$(find "$DIST" -maxdepth 1 -name '*.tar.gz' -type f | sort)
if [ -z "$archives" ]; then
  violation "no .tar.gz archives in $DIST" "${PROJECT}_<tag>_<os>_<arch>.tar.gz"
else
  for a in $archives; do
    base=$(basename "$a")
    if ! printf '%s' "$base" | grep -Eq "$tarball_re"; then
      violation "archive name '$base' does not match the contract" \
        "${PROJECT}_<tag>_<os>_<arch>.tar.gz"
    fi
  done
fi

# --- element 4: a linux_amd64 archive exists (the build-matrix floor) ---
amd64=$(find "$DIST" -maxdepth 1 -name "${PROJECT}_*_linux_amd64.tar.gz" -type f | sort | head -n 1)
if [ -z "$amd64" ]; then
  violation "no linux_amd64 archive" "${PROJECT}_<tag>_linux_amd64.tar.gz"
fi

# --- element 2: checksums file plus its cosign signature and certificate ---
checksums=$(find "$DIST" -maxdepth 1 -name "${PROJECT}_*_checksums.txt" -type f | sort | head -n 1)
if [ -z "$checksums" ]; then
  violation "no checksums file" "${PROJECT}_<tag>_checksums.txt"
else
  [ -f "${checksums}.sig" ] || violation "checksums signature missing" "$(basename "$checksums").sig beside the checksums file"
  [ -f "${checksums}.pem" ] || violation "checksums certificate missing" "$(basename "$checksums").pem beside the checksums file"
fi

# --- element 3: the binary sits at the archive root ---
if [ -n "$amd64" ]; then
  if ! tar -tzf "$amd64" | grep -Eq "^\.?/?${PROJECT}\$"; then
    violation "binary '$PROJECT' is not at the root of $(basename "$amd64")" \
      "the binary at the archive root (tar -tzf shows '$PROJECT', not 'dir/$PROJECT')"
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "D34 artifact-shape contract: FAILED" >&2
  exit 1
fi
echo "D34 artifact-shape contract: OK ($PROJECT, $(printf '%s\n' "$archives" | grep -c . ) archive(s), checksums signed)"
