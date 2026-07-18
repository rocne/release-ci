#!/usr/bin/env sh
# assert-version-contract.sh — assert the D30 --version parse rule against the
# output of `<tool> --version`. Canonical source: rocne/release-ci,
# release-dryrun/assert-version-contract.sh; consumed by each consumer via a
# tag-pinned checkout of release-ci (owned once, never copied) and called
# from its release-dryrun.yml (parse-conformance, tag-agnostic), and mirrored by
# the release smoke (release.yml, equals-version), so a tool whose --version
# drifts fails its own dry-run instead of #1's ensure-check on a user's machine
# (#15, DESIGN.md D30).
#
# The contract (D30): the FIRST LINE of `<tool> --version` contains the tool's own
# version as the FIRST semver-shaped token on that line. A parse rule, not a
# format — the surrounding tokens are free (gostow prints
# "gostow 0.4.0 (GNU Stow 2.4.1 compatible)"; the load-bearing part is that its
# own 0.4.0 comes before the compat 2.4.1, not any fixed layout).
#
# Usage:  <tool> --version 2>&1 | assert-version-contract.sh [expected-version]
#   expected-version  optional. When given, the parsed token must equal it
#                     (a leading 'v' is ignored on both sides) — the release-time
#                     check, where the tag is known. Omitted → parse-conformance
#                     only, which is tag-agnostic and so passes on snapshot /
#                     pseudo-version builds (v0.0.0-dryrun) exactly as a real
#                     release would — the dry-run check.
#
# Reads the --version output on stdin (pipe `2>&1` if the tool prints to stderr),
# mirroring assert-artifact-shape.sh's "hand it the thing to inspect" seam so the
# rule is exercised against plain strings, no live binary needed.
#
# Exit: 0 conformant; 1 contract violation; 2 usage / no input.

set -eu

EXPECTED="${1:-}"

line1=$(head -n 1)
if [ -z "$line1" ]; then
  echo "error: no --version output on stdin" >&2
  echo "hint:  <tool> --version 2>&1 | assert-version-contract.sh [expected-version]" >&2
  exit 2
fi

# A semver-shaped token: major.minor.patch with an optional -prerelease / +build
# tail. grep -Eo lists matches left-to-right, so head -n1 is the *first* such
# token on the line (D30's load-bearing "first"). A no-match grep exits 1; the
# pipeline is guarded so an absent token becomes an empty string, not an abort.
semver_re='[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)*'
token=$(printf '%s\n' "$line1" | grep -Eo "$semver_re" | head -n 1 || true)

if [ -z "$token" ]; then
  echo "::error::D30 --version parse rule violated: no semver token on the first line" >&2
  echo "  first line: $line1" >&2
  echo "  expected:   a semver-shaped token (e.g. 1.2.3) as the first such token on line 1" >&2
  echo "D30 --version parse rule: FAILED" >&2
  exit 1
fi

if [ -n "$EXPECTED" ]; then
  want=${EXPECTED#v}
  got=${token#v}
  if [ "$want" != "$got" ]; then
    echo "::error::D30 --version parse rule violated: reported version does not match the release" >&2
    echo "  first line: $line1" >&2
    echo "  parsed:     $got" >&2
    echo "  expected:   $want" >&2
    echo "D30 --version parse rule: FAILED" >&2
    exit 1
  fi
  echo "D30 --version parse rule: OK (parsed $token, matches ${EXPECTED#v})"
else
  echo "D30 --version parse rule: OK (parsed $token)"
fi
