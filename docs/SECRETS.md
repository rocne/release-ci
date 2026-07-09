# Secrets and signing keys

Everything the release pipeline needs, how to create it from nothing, and how to
put it back if you've forgotten all of this. Written for future-you.

Throughout, **secrets manager** means 1Password.

## The three secrets

`.github/workflows/release.yml` reads exactly four secrets. One is free:
`GITHUB_TOKEN` is injected by GitHub Actions automatically — **you never create,
set, or rotate it.** The other three are yours to manage.

| Secret | What breaks without it | Comes from |
| --- | --- | --- |
| `GPG_PRIVATE_KEY` | `.deb` / `.rpm` package signing | You generate it locally with `gpg` |
| `HOMEBREW_TAP_GITHUB_TOKEN` | Pushing the cask to `rocne/homebrew-tap` | GitHub fine-grained PAT |
| `CLOUDSMITH_API_KEY` | Publishing to the `rocne/releases` apt/dnf repo | cloudsmith.io account settings |

### Two rules that explain everything else

**1. GitHub secrets are write-only.** Once you run `gh secret set`, you can
never read that value back out — not through the UI, not through the API. `gh
secret list` shows you names and dates, nothing more. **Your secrets manager is
the only copy that exists.** If a secret isn't in 1Password, it is gone, and
your only option is to generate a new one and re-set it everywhere.

**2. `rocne` is a personal account, not an organization.** Personal accounts
have no org-level secrets, so there is nothing to inherit *from*. Callers use
`secrets: inherit`, which passes **the calling repo's own secrets** into this
reusable workflow. That means every tool repo needs its own private copy of all
three secrets.

`release-ci` itself needs **zero** secrets — it only ever runs as a
`workflow_call` target, using the caller's.

## Which repos need what

Every tool repo that signs packages, publishes to Cloudsmith, and ships a cask
needs all three. Today that's `hud`, `gostow`, and `dot-dagger`.

Check the current state at any time:

```bash
for r in hud gostow dot-dagger; do
  echo "=== rocne/$r ==="
  gh secret list --repo "rocne/$r"
done
```

You want to see all three names listed for each repo. If one is missing, that
repo's next release will fail — see [Setting up a new tool repo](#setting-up-a-new-tool-repo).

---

## 1. `CLOUDSMITH_API_KEY`

Publishes the signed `.deb`/`.rpm` to the `rocne/releases` repo so `apt install
hud` works. Driven by the `cloudsmith` publisher in each tool's goreleaser
config.

### Already have it?

**Open your secrets manager and search for `Cloudsmith API key`.** If it's
there, skip to [Set it on GitHub](#set-it-on-github). You do not need to
generate a new one — the same key works for every repo.

### If you don't have it

The Cloudsmith repo `rocne/releases` must exist and be **public** first
(cloudsmith.io → Repositories). It already does; you only make a new one if
you're starting over.

1. Go to <https://cloudsmith.io/user/settings/api/>.
2. Copy the API key shown. (Click **Regenerate** only if you're rotating — that
   immediately breaks every repo still using the old one.)
3. **Save it to your secrets manager now, before doing anything else.** Create
   a Password item named `Cloudsmith API key`. Cloudsmith will show it again,
   but don't rely on that.

Verify it works before you set it anywhere:

```bash
pipx install cloudsmith-cli   # if you don't have it
CLOUDSMITH_API_KEY='<paste>' cloudsmith whoami
```

That should print your Cloudsmith username.

### Set it on GitHub

```bash
for r in hud gostow dot-dagger; do
  gh secret set CLOUDSMITH_API_KEY --repo "rocne/$r"
done
```

Each iteration prompts `? Paste your secret`. Paste, press Enter. (Pasting the
same value three times is correct and expected — see rule 2.)

---

## 2. `HOMEBREW_TAP_GITHUB_TOKEN`

GoReleaser commits the generated cask file into `rocne/homebrew-tap` on your
behalf. The automatic `GITHUB_TOKEN` only has access to the repo being
released, never a *second* repo, which is why this separate token exists.

### Already have it?

**Open your secrets manager and search for `GitHub PAT — homebrew-tap`.** If
it's there, skip to [Set it on GitHub](#set-it-on-github-1).

Fine-grained PATs **expire**. If the item in your secrets manager has an expiry
date in the past, GoReleaser will fail with `resource not accessible by
integration` and you need to generate a fresh one below.

### If you don't have it

The tap repo `rocne/homebrew-tap` must exist and be public first — GoReleaser
pushes into it, it will not create it. Confirm:

```bash
gh repo view rocne/homebrew-tap --json name,visibility
```

If that 404s, create it (the `homebrew-` name prefix is what makes `brew tap
rocne/tap` work):

```bash
gh repo create rocne/homebrew-tap --public \
  --description "Homebrew tap for rocne tools"
```

Now mint the token:

1. Go to <https://github.com/settings/personal-access-tokens/new>.
2. **Token name:** `homebrew-tap push (release-ci)`
3. **Expiration:** 1 year. Put the expiry date in your calendar today.
4. **Repository access:** *Only select repositories* → pick **`rocne/homebrew-tap`**.
   Do not grant access to all repos.
5. **Repository permissions:** set **Contents** to **Read and write**. Leave
   everything else alone (Metadata → Read-only is added for you automatically).
6. Click **Generate token** and copy it.
7. **Save it to your secrets manager immediately — GitHub will never show it
   again.** Create a Password item named `GitHub PAT — homebrew-tap`, and record
   the expiration date in the item so future-you sees it.

Verify the token actually has write access before setting it:

```bash
GH_TOKEN='<paste>' gh api repos/rocne/homebrew-tap --jq '.permissions'
```

You want `"push": true` in the output. If you see `false`, you picked the wrong
permission in step 5.

### Set it on GitHub

```bash
for r in hud gostow dot-dagger; do
  gh secret set HOMEBREW_TAP_GITHUB_TOKEN --repo "rocne/$r"
done
```

---

## 3. `GPG_PRIVATE_KEY`

The package-signing key. The workflow writes it to a file and hands the path to
GoReleaser as `GPG_KEY_PATH`, which nfpm uses to sign the `.deb` and `.rpm`
(`release.yml:80-86`, and `rpm.signature.key_file` in each tool's goreleaser
config).

This is **not** the key that signs the apt/dnf repository index — Cloudsmith
does that server-side with its own key. This one signs the packages themselves,
and its private half never leaves your control.

### Already have it?

**Open your secrets manager and search for `GPG package signing key
(rocne/releases)`.** The item should hold the full armored private key, the text
block starting `-----BEGIN PGP PRIVATE KEY BLOCK-----`. If it's there, save it
to a file and skip to [Set it on GitHub](#set-it-on-github-2):

```bash
umask 077
# paste the armored block into this file
vim ~/gpg-private.asc
```

If it is **not** in your secrets manager, it is unrecoverable — you cannot read
it back out of GitHub, and it is not on this machine (`gpg --list-secret-keys`
is empty). Generate a new one below and re-set it on all three repos. Nothing
breaks: already-published packages keep their old signatures, and Cloudsmith's
repo index signature — which is what `apt`/`dnf` actually check on install — is
unaffected.

### If you don't have it

The key **must have an empty passphrase.** nfpm looks for a passphrase in
`$NFPM_<ID>_<FORMAT>_PASSPHRASE`, `$NFPM_<ID>_PASSPHRASE`, then
`$NFPM_PASSPHRASE`. The workflow sets none of them, so a passphrase-protected
key simply cannot be unlocked in CI. The `--passphrase ''` below is deliberate,
not laziness. It is safe because the key exists only as a GitHub secret and a
1Password item.

Generate it (RSA-4096, sign-only, no expiry — an expired signing key silently
breaks releases years from now):

```bash
gpg --batch --pinentry-mode loopback --passphrase '' \
  --quick-generate-key "Rocne Scribner (package signing) <rocne.ks@gmail.com>" \
  rsa4096 sign never
```

Grab the fingerprint and export both halves:

```bash
umask 077
FPR=$(gpg --list-secret-keys --with-colons rocne.ks@gmail.com \
        | awk -F: '/^fpr:/{print $10; exit}')
echo "fingerprint: $FPR"

gpg --batch --pinentry-mode loopback --passphrase '' \
  --armor --export-secret-keys "$FPR" > ~/gpg-private.asc

gpg --armor --export "$FPR" > ~/gpg-public.asc
```

**Save to your secrets manager now.** Create a Password item named `GPG package
signing key (rocne/releases)` with:

- the **entire contents of `~/gpg-private.asc`**, including both `-----BEGIN-----`
  and `-----END-----` lines, in the password/notes field
- the **fingerprint** (`$FPR` above) in a custom field
- the **contents of `~/gpg-public.asc`** in a second custom field — it's not
  secret, but you'll want it if you ever publish a key for users to verify
  package signatures with
- a note: *passphrase is intentionally empty; CI cannot unlock a protected key*

### Set it on GitHub

Read straight from the file so the armor block survives intact — do **not**
paste a multi-line key at the `gh secret set` prompt:

```bash
for r in hud gostow dot-dagger; do
  gh secret set GPG_PRIVATE_KEY --repo "rocne/$r" < ~/gpg-private.asc
done
```

### Clean up

The private key is now in GitHub and 1Password. Do not leave it on disk:

```bash
shred -u ~/gpg-private.asc
rm ~/gpg-public.asc
```

Optionally drop it from your local keyring too — CI is the only thing that
needs it:

```bash
gpg --batch --yes --delete-secret-and-public-key "$FPR"
```

---

## Setting up a new tool repo

When you add a fourth tool that calls this workflow, it needs all three secrets
before its first release. Pull all three out of your secrets manager, then:

```bash
NEW_REPO=rocne/<newtool>

# GPG: from a file (multi-line armor block)
gh secret set GPG_PRIVATE_KEY --repo "$NEW_REPO" < ~/gpg-private.asc

# The other two: paste at the prompt
gh secret set HOMEBREW_TAP_GITHUB_TOKEN --repo "$NEW_REPO"
gh secret set CLOUDSMITH_API_KEY --repo "$NEW_REPO"

gh secret list --repo "$NEW_REPO"   # expect all three
```

Then `shred -u ~/gpg-private.asc`.

## Rotating a secret

Same steps as generating, plus cleanup of the old credential:

- **`CLOUDSMITH_API_KEY`** — regenerating at cloudsmith.io kills the old key
  instantly. Re-set all repos in the same sitting, or releases fail in between.
- **`HOMEBREW_TAP_GITHUB_TOKEN`** — mint the new token *first*, set it on all
  repos, confirm a release works, then delete the old token at
  <https://github.com/settings/personal-access-tokens>.
- **`GPG_PRIVATE_KEY`** — generate, set on all repos, done. No revocation
  needed; nothing verifies against the old key.

Always update the secrets manager item in the same sitting. A rotated secret
that only lives in GitHub is a secret you have already lost.
