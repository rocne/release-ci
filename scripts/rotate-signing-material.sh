#!/usr/bin/env bash
# rotate-signing-material.sh — regenerate the org's name-bearing signing creds with
# clean neutral names, store them in 1Password, distribute to GitHub + Cloudsmith.
#
# SKELETON: the 1Password get/set helpers are written and tested. The generation,
# Cloudsmith-upload, and GitHub-distribution steps are marked `TODO(local-claude)`
# with what/why — fill them in on the machine that has op + cloudsmith + gh authed.
#
# What rotates (everything with a tool name baked in):
#   1. package-signing GPG key   -> GitHub secret GPG_PRIVATE_KEY on all repos
#   2. Cloudsmith repo-INDEX key -> uploaded to the rocne/releases Cloudsmith repo
#   3. homebrew-tap PAT          -> minted by hand (no API), then distributed
# The Cloudsmith API key is NOT rotated (no name embedded) — read from 1P, distribute.
#
# ⚠️  Stage 2 re-signs the apt/dnf index: every machine that already ran setup.deb.sh /
#     setup.rpm.sh must re-import the new public key before its next update succeeds.
#
# Requires: op (signed in), gh (authed), gpg, jq, curl.

set -euo pipefail

# ------------------------------------------------------------------ config ----
REPOS=(gostow dot-dagger hud dstow)
declare -A BIN=( [gostow]=gostow [dot-dagger]=dotd [hud]=hud [dstow]=dstow )
OP_VAULT="${OP_VAULT:-Private}"
CS_OWNER=rocne; CS_REPO=releases
EMAIL=rocne.ks@gmail.com

# neutral names — no tool baked in
PKG_UID="Rocne Scribner (rocne/releases package signing) <$EMAIL>"
IDX_UID="Rocne Scribner (rocne/releases repository index signing) <$EMAIL>"
PAT_NAME="rocne/homebrew-tap push (release-ci)"

# 1Password item titles
OP_PKG_ITEM="GPG package signing key (rocne/releases)"
OP_IDX_ITEM="GPG repository index signing key (Cloudsmith, rocne/releases)"
OP_PAT_ITEM="GitHub PAT — homebrew-tap"
OP_CS_ITEM="Cloudsmith API key"

# ============================================================================
# 1PASSWORD GETTERS / SETTERS  — the part you asked for. Tested syntax.
# ============================================================================

# op_get FIELD_REF  — read a single secret value.
# Uses op's secret-reference syntax: op://<vault>/<item>/<field>
# e.g. op_get "$OP_CS_ITEM/password"  ->  the Cloudsmith API key
op_get() { # ITEM/FIELD (relative to $OP_VAULT)
  op read "op://$OP_VAULT/$1"
}

# op_put_key ITEM_TITLE PRIV PUB FPR  — upsert a GPG keypair item.
# Multiline armored blocks go in via shell vars (integrity is preserved; only the
# 1P *UI* renders multiline oddly — the stored value is exact, verified by round-trip).
# Edits keep 1Password version history, so the previous key stays recoverable.
op_put_key() { # ITEM_TITLE PRIV PUB FPR
  local title="$1" priv="$2" pub="$3" fpr="$4"
  local -a f=(
    "private key[password]=$priv"
    "public key[text]=$pub"
    "fingerprint[text]=$fpr"
    "notesPlain=passphrase intentionally empty (CI can't unlock a protected key). Rotated by rotate-signing-material.sh."
  )
  if op item get "$title" --vault "$OP_VAULT" >/dev/null 2>&1; then
    op item edit   "$title" --vault "$OP_VAULT" "${f[@]}" >/dev/null
  else
    op item create --category "Secure Note" --title "$title" --vault "$OP_VAULT" "${f[@]}" >/dev/null
  fi
}

# op_put_token ITEM_TITLE VALUE [NOTE]  — upsert a single-secret item (PAT, etc.)
op_put_token() { # ITEM_TITLE VALUE [NOTE]
  local title="$1" val="$2" note="${3:-}"
  local -a f=( "credential[password]=$val" )
  [[ -n "$note" ]] && f+=( "notesPlain=$note" )
  if op item get "$title" --vault "$OP_VAULT" >/dev/null 2>&1; then
    op item edit   "$title" --vault "$OP_VAULT" "${f[@]}" >/dev/null
  else
    op item create --category "API Credential" --title "$title" --vault "$OP_VAULT" "${f[@]}" >/dev/null
  fi
}

# op_get_pub ITEM_TITLE  — pull a stored public key back out (for committing).
op_get_pub() { op item get "$1" --vault "$OP_VAULT" --fields "public key" --reveal; }

# ============================================================================
# The rest — placeholders. Fill in with the same op_* helpers above.
# ============================================================================

# preflight: assert op/gh/gpg/jq/curl present; `op whoami` and `gh auth status` ok;
# `op vault get "$OP_VAULT"`. Load the Cloudsmith API key you'll need in stage 2/4:
#   CS_KEY=$(op_get "$OP_CS_ITEM/password")
# TODO(local-claude): write the guards.

# gen_key UID -> sets REPLY_FPR / REPLY_PRIV / REPLY_PUB
# Generate in an EPHEMERAL GNUPGHOME (mktemp -d, chmod 700, rm -rf after) so no private
# key ever lands on persistent disk. RSA-4096, sign-only, no expiry, EMPTY passphrase
# (CI cannot unlock a protected key). This sequence is verified working:
#   home=$(mktemp -d); chmod 700 "$home"
#   GNUPGHOME=$home gpg --batch --pinentry-mode loopback --passphrase '' \
#       --quick-generate-key "$UID" rsa4096 sign never
#   REPLY_FPR=$(GNUPGHOME=$home gpg --list-secret-keys --with-colons "$UID" | awk -F: '/^fpr:/{print $10; exit}')
#   REPLY_PRIV=$(GNUPGHOME=$home gpg --batch --pinentry-mode loopback --passphrase '' --armor --export-secret-keys "$REPLY_FPR")
#   REPLY_PUB=$(GNUPGHOME=$home gpg --armor --export "$REPLY_FPR"); rm -rf "$home"
# TODO(local-claude): paste as a function.

# gh_set NAME VALUE — set a secret on every repo (personal acct = no org secrets;
# each repo needs its own copy). `printf %s "$VALUE" | gh secret set NAME --repo rocne/<r>`.
# TODO(local-claude).

# ---- STAGE 1: package key ----
# gen_key "$PKG_UID"; op_put_key "$OP_PKG_ITEM" "$REPLY_PRIV" "$REPLY_PUB" "$REPLY_FPR"
# gh_set GPG_PRIVATE_KEY "$REPLY_PRIV"
# write "$REPLY_PUB" to out/<bin>-signing-key.asc for each repo (content identical; filename differs).
# TODO(local-claude).

# ---- STAGE 2: Cloudsmith index key  ⚠️ re-signs the index ----
# gen_key "$IDX_UID"; op_put_key "$OP_IDX_ITEM" "$REPLY_PRIV" "$REPLY_PUB" "$REPLY_FPR"
# Upload the PRIVATE half to Cloudsmith so it re-signs the repo index server-side:
#   BODY=$(jq -n --arg k "$REPLY_PRIV" '{gpg_private_key:$k}')          # jq escapes the armor safely
#   curl -sS -X POST "https://api.cloudsmith.io/v1/repos/$CS_OWNER/$CS_REPO/gpg/" \
#     -H "X-Api-Key: $CS_KEY" -H "Content-Type: application/json" --data "$BODY"
#   # expect 200/201; response .fingerprint should match REPLY_FPR
# write "$REPLY_PUB" to out/<bin>-repo-signing-key.asc for each repo.
# TODO(local-claude): add a "type yes" confirm before the POST — this breaks existing installs.

# ---- STAGE 3: homebrew PAT (manual mint — GitHub has no create-PAT API) ----
# Print the create URL + settings (name=$PAT_NAME, expire 1y, repo=rocne/homebrew-tap,
# Contents=Read/write). read -rsp the pasted token. Verify:
#   GH_TOKEN=$PAT gh api repos/rocne/homebrew-tap --jq '.permissions.push'  # want true
# op_put_token "$OP_PAT_ITEM" "$PAT" "fine-grained; expires 1y; rotate before expiry"
# gh_set HOMEBREW_TAP_GITHUB_TOKEN "$PAT"
# TODO(local-claude).

# ---- STAGE 4: Cloudsmith API key (distribute, don't rotate) ----
# gh_set CLOUDSMITH_API_KEY "$CS_KEY"
# TODO(local-claude).

# ---- AFTER: non-secret follow-ups ----
# Commit out/<bin>-signing-key.asc and out/<bin>-repo-signing-key.asc to each repo root,
# confirm they're under release.extra_files in each goreleaser config, and announce the
# index-key rotation (existing apt/dnf users must re-import). Ask Claude to open the 4 PRs.
