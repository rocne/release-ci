# Prior art: how mature `curl | sh` installers actually behave

Survey date: 2026-07-16. Commissioned by [#1](https://github.com/rocne/release-ci/issues/1)
(open question 1) and [#3](https://github.com/rocne/release-ci/issues/3).

Purpose: ground `rocne/release-ci`'s canonical `install.sh` in outside convention rather
than one author's habits, specifically on the axis that matters most to us —
**presence-check-and-exit-cleanly**. Prior to this, every convention in #1 derived from
two sibling scripts (`gostow`, `dot-dagger`) sharing one author and one lineage.

All claims below are sourced from the **actual installer script source** (fetched via
`curl` and grepped directly, with line numbers against the fetched copy) unless marked
"docs only" or "could not verify." Line numbers refer to the copy fetched on 2026-07-16
(`master`/`main`/`latest`) — they drift as upstream changes; re-fetch before relying on
exact numbers. Raw copies are **not committed** (third-party scripts; reproducible from
the Sources index at the end).

> ## Reviewer's note — verification pass, 2026-07-16
>
> Spot-checked independently against the fetched sources rather than accepted as written.
> Three headline claims **verified**: `XDG_BIN_HOME` appears in uv's installer and no
> other surveyed script; no surveyed script exposes a bare `INSTALL_DIR` as user-facing
> env; mise's `MISE_INSTALL_SKIP_IF_EXISTS` (`mise.run:289`), `~/.local/bin` default
> (`:282`), `MISE_QUIET` (`:15`) and checksum hard-abort (`:122`) are all real.
>
> **One synthesis claim is wrong.** Convention #1 below asserts *"errors to stderr,
> informational output to stdout — universal … the one true, unanimous convention in the
> whole survey."* It is not unanimous. **mise routes `info()` to stderr**
> (`mise.run:20` — `info() { echo "$@" >&2; }`), as does Volta (the survey's own table
> says "always verbose (stderr)"). At least 2 of 15 put informational output on stderr.
> The defensible claim is the weaker one: **errors/warnings go to stderr universally;
> where informational output goes is not settled.** Treat "universal" in that section as
> "errors only."
>
> **Two findings the synthesis under-weights**, both from mise — the closest precedent to
> our design:
> 1. **mise's skip branch is exactly our contract**: `info "...skipping install"` then
>    `return 0` — speaks, exits 0. Combined with `MISE_QUIET` making `info()` a no-op,
>    mise independently implements the level-vs-exit-code split #1 specifies.
> 2. **mise deliberately does *not* check the wider PATH.** Verbatim (`mise.run:286-288`):
>    *"Only the install path is checked (not the wider PATH) so that skipping never leaves
>    install_path missing."* #1's floor specifies `command -v` (wider PATH). That is a
>    real, load-bearing design fork with a documented rationale on the other side — see
>    #1's open questions.
>
> The `sources/` directory the original text referenced also **omitted mise**, despite
> mise being cited as the single closest precedent; those claims were re-fetched and
> verified directly rather than left resting on an absent source.

---

## Per-tool findings

### 1. rustup (`sh.rustup.rs` → `rustup-init.sh`)
Source: https://raw.githubusercontent.com/rust-lang/rustup/master/rustup-init.sh (verified, 930 lines)

- **Presence check**: **None.** Grepped for "already" — zero matches. The shell wrapper
  unconditionally downloads a `rustup-init` binary and execs it; that binary (not this
  script) is what decides whether to install fresh or update. The shell script itself is
  install-logic-free.
- **Force/version**: `-y, --yes` (line 47, doc'd) skips the confirmation prompt and sets
  `need_tty=no` (lines 137-140). No `--force` flag. `RUSTUP_VERSION` env selects a
  specific rustup-init archive (not the installed Rust version). No `CARGO_HOME` /
  `RUSTUP_HOME` / `XDG_*` references anywhere in this script (grepped, zero matches) —
  entirely delegated to the downloaded binary.
- **Output**: `-q, --quiet` (line 45 doc, line 134: sets `RUSTUP_QUIET=yes`) and
  `-v, --verbose` (doc only, line 43; not actually handled by this wrapper — passed
  through to the binary). All messaging via `say()`/`err()`/`warn()`, all to **stderr**.
- **Install dir**: Not handled by this script at all (delegated to `rustup-init`
  binary/`CARGO_HOME`/`RUSTUP_HOME`). `--no-modify-path` (line 61) is documented and
  passed through.
- **Verification**: None in this wrapper — no checksum/signature check before executing
  the downloaded `rustup-init` binary.
- **Exit codes**: `exit 1` on failures via `err()`. No structured exit-code taxonomy.
- **CI/non-interactive**: TTY-based — checks `[ ! -t 0 ]` / `[ ! -t 1 ]` (lines ~150-160);
  `-y` bypasses. No `CI=` env detection.

### 2. Homebrew (`Homebrew/install` `install.sh`)
Source: https://raw.githubusercontent.com/Homebrew/install/master/install.sh (verified, 1178 lines)

- **Presence check**: **None** for "is Homebrew already here, exit." Grep for
  "already" only matches a PATH comment (line 229) — no installed-check/upgrade branch.
  It runs `git clone`/tap logic regardless.
- **Force/version**: No force flag. `NONINTERACTIVE=1` and `CI=1` env vars (usage text,
  lines 93-96) suppress prompts; `INTERACTIVE=1` forces prompting even off a non-TTY
  stdin. Setting both `INTERACTIVE` and `NONINTERACTIVE` aborts (lines 28-33):
  `abort 'Both $INTERACTIVE and $NONINTERACTIVE are set...'`. Setting `CI` + `INTERACTIVE`
  together also aborts (lines 22-25).
- **Output**: No `--quiet`/`--verbose` flags. `ohai()` → stdout; `warn()` → stderr.
  Analytics suppressed via `HOMEBREW_NO_ANALYTICS_THIS_RUN=1`.
- **Install dir**: Hardcoded by platform/arch, **not user-overridable by flag**:
  `/opt/homebrew` (ARM macOS, line 160), `/usr/local` (Intel macOS, line 164),
  `/home/linuxbrew/.linuxbrew` (Linux, line 180). No XDG anything. PATH is **not**
  modified by the script — it only prints the exact `echo >> ~/.zprofile` commands for
  the user to run themselves.
- **Verification**: None — clones via `git`, no checksum/signature step.
- **Exit codes**: `abort()` → `printf ... >&2; exit 1`. No 0/1/2 taxonomy beyond that.
- **CI/non-interactive**: `CI=1` → non-interactive with a warning (lines 116-121);
  `[[ ! -t 0 ]]` (non-tty stdin) → non-interactive with a warning (line ~127) unless
  `INTERACTIVE=1` is set.

### 3. Docker (`get.docker.com` → `docker-install/install.sh`)
Source: https://raw.githubusercontent.com/docker/docker-install/master/install.sh (verified, 778 lines)

- **Presence check**: **Warns, does not exit.** `do_install()` (line 424):
  `if [ "$REPO_ONLY" != "1" ] && command_exists docker; then` (line 427) prints an
  8-line warning to stderr ("Warning: the "docker" command appears to already exist on
  this system... You may press Ctrl+C now to abort") then **`sleep 20`** (line 441) and
  continues installing/overwriting anyway. This is the "loud but non-blocking" pattern —
  distinct from both "silent exit" and "silent reinstall."
- **Force/version**: `VERSION` env (stripped of leading `v`, line 105), `CHANNEL`
  (default `stable`, also `test`), `DOWNLOAD_URL` (default
  `https://download.docker.com`, line 115-117), `DRY_RUN` env (line 131) — when set,
  `sh_c="echo"` so commands are printed, not executed. `--mirror Aliyun`/`AzureChinaCloud`
  swap the download host. No explicit `--force`.
- **Output**: No quiet/verbose flags. Uses package-manager quiet flags internally
  (`apt-get -qq`). Warnings/errors → stderr via heredoc `cat >&2`.
- **Install dir**: None — delegates entirely to the OS package manager (apt/dnf/yum);
  no custom bin dir, no XDG, no PATH/rc modification.
- **Verification**: GPG key fetched and installed into the apt/dnf keyring
  (`/etc/apt/keyrings/docker.asc`); actual signature verification is then handled by
  the OS package manager itself, not this script. No fallback if GPG tooling is absent
  — it's assumed present as part of the package-manager toolchain.
- **Exit codes**: `exit 1` on unsupported distro / missing privilege escalation / bad
  version. `deprecation_notice()` prints a red warning and sleeps 10s before continuing
  rather than aborting.
- **CI/non-interactive**: No explicit `CI=` detection. `DRY_RUN` is the closest analog.
  Designed to run unattended via curl|sh regardless.

### 4. Deno (`deno.land/install.sh`)
Source: https://raw.githubusercontent.com/denoland/deno_install/master/install.sh (verified, 128 lines)

- **Presence check**: **None.** Unconditionally downloads and overwrites
  `$deno_install/bin/deno`.
- **Force/version**: `-y, --yes` skips shell-setup prompt. Positional first non-flag arg
  is a version pin; else fetches `https://dl.deno.land/release-latest.txt`.
  `--no-modify-path` is documented but this copy shows PATH setup fully delegated (see
  below), so its effect lives downstream. No `--force`.
- **Output**: No quiet/verbose flags. `curl --progress-bar`. Errors to stderr
  (e.g. missing `unzip`/`7z`).
- **Install dir**: `deno_install="${DENO_INSTALL:-$HOME/.deno}"` (line 79, confirmed).
  No XDG support. **PATH/rc setup is delegated to a separate downloaded tool**:
  `"$exe run -A --reload jsr:@deno/installer-shell-setup/bundled"` — the shell script
  itself does not touch rc files directly.
- **Verification**: None.
- **Exit codes**: `exit 1` if neither `unzip` nor `7z` present.
- **CI/non-interactive**: `if { [ -z "$CI" ] && [ -t 1 ]; } || $should_run_shell_setup;`
  — skips the interactive shell-setup delegate when `CI` is set or stdout isn't a TTY.

### 5. Bun (`bun.sh/install`)
Source: https://bun.sh/install (verified, 326 lines; not on GitHub as a standalone raw
file — served dynamically from oven-sh infra)

- **Presence check**: **None before install** (always downloads/overwrites). There is a
  **post-install** `command -v bun` check (around line 196) purely to decide whether to
  print `"Run 'bun --help' to get started"` — not a guard.
- **Force/version**: No force flag found. `BUN_INSTALL` env controls dir (see below).
- **Output**: No quiet/verbose flags; color only gated by `[[ -t 1 ]]`. `error()` →
  `echo ... >&2; exit 1` (confirmed pattern). Completions install is explicitly
  silenced: `... completions &>/dev/null || :`.
- **Install dir**: `install_env=BUN_INSTALL` (line 137); `install_dir=${!install_env:-$HOME/.bun}`
  (line 140, confirmed). **Actively rewrites shell rc files** (bash: `.bash_profile`/
  `.bashrc`; zsh: `.zshrc`; fish: `.config/fish/config.fish`), guarded by a
  `[[ -w $config ]]` writability check with a print-only fallback. Partial XDG use:
  `$XDG_CONFIG_HOME` is consulted only to find *additional bash config file paths* to
  edit, not for the binary directory itself.
- **Verification**: None — downloads a zip from GitHub releases via `curl --fail`, no
  checksum/signature step.
- **Exit codes**: `exit 1` on all errors via `error()`.
- **CI/non-interactive**: None explicit; only TTY-gated color.

### 6. uv / Astral (`astral.sh/uv/install.sh`)
Source (after 301 redirect): https://releases.astral.sh/installers/uv/latest/uv-installer.sh
(verified, 2194 lines — this is the shared `cargo-dist` shell installer template astral
also uses for other Rust CLI tools)

- **Presence check**: **None** — unconditionally (re)installs; effectively an
  always-upgrade model. No "already installed, skip" branch found.
- **Force/version**: No `--force` reinstall flag as such, but a **"force install dir"**
  concept: `UV_INSTALL_DIR` env (line 1237) or `CARGO_DIST_FORCE_INSTALL_DIR` (line
  1239) sets `_force_install_dir`, which short-circuits the normal XDG/`~/.cargo`
  priority chain. `UV_UNMANAGED_INSTALL` (line 61) forces `NO_MODIFY_PATH=1` and
  disables the self-updater. `UV_DISABLE_UPDATE=1` skips installing the updater
  component.
- **Output**: `--quiet`/`--verbose` flags plus matching env vars `UV_PRINT_QUIET`/
  `UV_PRINT_VERBOSE`. `say()` is gated on `PRINT_QUIET`; errors via `err()` always show,
  to stderr, red if `tput` is available.
- **Install dir — the most XDG-aware of the whole survey**: documented priority order
  (lines ~139-140, confirmed) is:
  1. `$XDG_BIN_HOME` (line 1295, confirmed: `if [ -n "${XDG_BIN_HOME:-}" ]; then _install_dir="$XDG_BIN_HOME"`)
  2. `$XDG_DATA_HOME/../bin` (line 1307-1308)
  3. `$HOME/.local/bin` fallback (line 1320: `_install_dir="$INFERRED_HOME/.local/bin"`)
  — **uv is the one script in this survey that explicitly and verifiably honors
  `XDG_BIN_HOME`.** It also **actively writes rc files**: creates a self-contained
  `${install_dir}/env` shim script and sources it from `.profile`, `.bashrc`,
  `.bash_profile`, `.bash_login`, `.zshrc`, `.zshenv` (function calls at ~line 1494+,
  confirmed by grep), falling back to printed instructions only if that fails.
- **Verification**: Real checksum verification (sha256/sha512/sha3/blake2s/blake2b
  supported). **If the hashing tool is missing, it explicitly *skips* verification and
  proceeds** — confirmed pattern: `if ! check_cmd sha256sum; then say "skipping sha256
  checksum verification..."; return 0; fi`. Mismatch is fatal
  (`"checksum mismatch want: X got: Y"`).
- **Exit codes**: 0 success / 1 failure via `err()`.
- **CI/non-interactive**: Detects GitHub Actions specifically via `$GITHUB_PATH` and
  appends the install dir to it for subsequent-step PATH visibility. No generic `CI=`
  handling found.

### 7. Starship (`starship.rs/install.sh`)
Source: https://raw.githubusercontent.com/starship/starship/master/install/install.sh (verified, 554 lines)

- **Presence check**: **Documented as an upgrade, not actually implemented as a
  version-diff check.** The `usage()` text says (lines 159-160, confirmed verbatim):
  *"Fetch and install the latest version of starship, if starship is already installed
  it will be updated to the latest version."* But there is no code that inspects an
  existing binary/version before proceeding — it downloads and overwrites
  unconditionally; the "update" claim is really just "same as install, files get
  replaced." This is a **doc/code mismatch worth flagging** — don't take a tool's usage
  text as proof of behavior; always check the code.
- **Force/version**: `-f, -y, --force, --yes` (all four spellings map to the same
  behavior, line 469: `FORCE=1`) skip the confirmation prompt; also settable via `FORCE`
  env, checked at `if [ -z "${FORCE-}" ]` (line 272).
- **Output**: `-V, --verbose` sets `VERBOSE=1`→`v`, changes `tar` flags from `xzof` to
  `xzvof`. No `-q/--quiet`. Info → stdout via custom formatting; errors (`x`) → stderr.
- **Install dir**: `BIN_DIR` env or `-b, --bin-dir` flag (line 448: `BIN_DIR="$2"`),
  default `/usr/local/bin` (lines 421-422, confirmed: `if [ -z "${BIN_DIR-}" ]; then
  BIN_DIR=/usr/local/bin`). No XDG support. **Print-only** for shell config — it never
  edits rc files, only prints the `eval "$(starship init ...)"` line to add.
- **Verification**: None — direct tar extraction, no checksum/signature.
- **Exit codes**: `exit 1` on errors, printed via a red `x` marker to stderr.
- **CI/non-interactive**: `-f/-y/--force/--yes` is the only mechanism; no `CI=` env
  detection.

### 8. nvm (`nvm-sh/nvm` `install.sh`)
Source: https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh (verified, 533 lines)

- **Presence check**: **Yes — the strongest "detect and act" example after k3s/Helm/
  Volta.** Checks `[ -d "$INSTALL_DIR/.git" ]` (line ~171, confirmed message text:
  `"=> nvm is already installed in $INSTALL_DIR, trying to update using git"`) and a
  parallel check for a script-mode install (`"=> nvm is already installed in
  $INSTALL_DIR, trying to update the script"`, line ~271). In both cases it **updates in
  place via git fetch/checkout**, not a clean exit — there is no "skip, already present"
  terminal state; reinstall requires manually deleting `$NVM_DIR` first.
- **Force/version**: No force flag. `NVM_INSTALL_VERSION` pins the nvm release itself
  (not a Node version). `METHOD=git|script` forces install mechanism. `PROFILE=/dev/null`
  disables the automatic rc-file edit.
- **Output**: No quiet/verbose flags. All output via `nvm_echo()`; explicit `>&2` for
  errors.
- **Install dir**: `nvm_default_install_dir()` — honors `${XDG_CONFIG_HOME}/nvm` if
  `XDG_CONFIG_HOME` is set, else `$HOME/.nvm`; `NVM_DIR` env takes final precedence.
  **Actively rewrites shell rc files**: `nvm_detect_profile()` searches
  `~/.bashrc`→`~/.bash_profile` (bash), `${ZDOTDIR:-$HOME}/.zshrc`→`.zprofile` (zsh),
  falling back to `~/.profile`. It **appends** `export NVM_DIR=...` and the
  `nvm.sh`/`bash_completion` source lines, but is idempotent about it — checks for
  "source string already in $NVM_PROFILE" before appending again (confirmed at lines
  ~488, ~495).
- **Verification**: None — `nvm_download()` wraps curl/wget with `--fail` only.
- **Exit codes**: 0 success; 1 general validation failures; 2 directory/permission/git
  failures; 3 chmod failure on `nvm-exec`. Errors prefixed `"=> "` to stderr.
- **CI/non-interactive**: No `CI=` detection; it does actively **reject** being sourced
  by zsh/non-bash: `if [ -z "${BASH_VERSION}" ] || [ -n "${ZSH_VERSION}" ]; then ... exit
  1; fi` — i.e. it demands `bash` specifically, not just any POSIX `sh`.

### 9. fnm (`Schniz/fnm` `.ci/install.sh`)
Source: https://raw.githubusercontent.com/Schniz/fnm/master/.ci/install.sh (verified, 237 lines)

- **Presence check**: **None.** No existing-install detection; always (re)installs.
- **Force/version**: `--force-install` / `--force-no-brew` (line 37, confirmed) — but
  this is *not* a reinstall-guard bypass; it's specifically "skip the Homebrew branch on
  macOS and download the raw GitHub binary instead," printed with the warning
  `` `--force-install`: I hope you know what you're doing. `` (line 38). `-d,
  --install-dir` overrides the target dir. `-r, --release` pins version.
- **Output**: No quiet/verbose flags.
- **Install dir**: Priority chain confirmed at file top (lines 12-19): `$HOME/.fnm` if
  it already exists → `$XDG_DATA_HOME/fnm` if `XDG_DATA_HOME` set → macOS
  `~/Library/Application Support/fnm` → else `~/.local/share/fnm`. **Honors
  `XDG_DATA_HOME`** (not `XDG_BIN_HOME`). **Actively rewrites rc files**: zsh
  (`${ZDOTDIR:-$HOME}/.zshrc`), bash (`~/.profile` on Darwin, `~/.bashrc` elsewhere),
  fish (`~/.config/fish/conf.d/fnm.fish`), appending PATH export +
  `eval "$(fnm env ...)"`. `-s, --skip-shell` disables this.
- **Verification**: None.
- **Exit codes**: `exit 1` on unrecognized args / unsupported OS / missing deps /
  unsupported shell / download failure.
- **CI/non-interactive**: `--skip-shell` is the relevant flag; no `-y`/`CI=` detection.

### 10. Volta (`volta-cli/volta` `dev/unix/volta-install.sh`)
Source: https://raw.githubusercontent.com/volta-cli/volta/master/dev/unix/volta-install.sh
(verified, 395 lines). **Note: Volta is publicly stated to be unmaintained/EOL** — found
via secondary source (lilting.ch migration guide, not independently confirmed against an
official Volta announcement) — treat Volta's conventions as historical, not
actively-curated best practice.

- **Presence check**: **Yes — real version-aware guard**, function `upgrade_is_ok()`
  (confirmed, line 85). Locates an existing `volta` binary at `$install_dir/volta` or
  `$install_dir/bin/volta`; if found, compares its `--version` to the version being
  installed. **Exact version match → refuses and exits 1**:
  `eprintf "Version $will_install_version already installed"` (line 115, confirmed);
  `return 1` bubbles up to abort the install. Newer version → proceeds (upgrade,
  silent). This is the cleanest "**presence check → clean exit when already
  current**" example found in the whole survey.
- **Force/version**: No `--force` to bypass the same-version guard. `--version <ver>`
  flag pins target version. `--dev`/`--release` build from source locally, and dev
  builds explicitly skip the equality check (`is_dev_install`).
- **Output**: No quiet flag — always verbose to **stderr** (`info()`/`error()`/
  `warning()` all redirect `>&2`).
- **Install dir**: `VOLTA_HOME` env, default `$HOME/.volta` (line 226, confirmed). No
  XDG support. Runs `volta setup` (a separate subcommand of the just-installed binary)
  to touch shell startup files, unless `--skip-setup` is passed.
- **Verification**: None found — plain curl download, no checksum/signature step.
- **Exit codes**: 1 on failure / 0 on success, via `error()`/return codes.
- **CI/non-interactive**: None — no prompts exist in the script at all, so it's
  inherently CI-safe by omission rather than by explicit detection.

### 11. Atuin (`atuinsh/atuin` `install.sh`)
Source: https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh (verified, 197 lines)

- **Presence check**: **None** — calls `__atuin_install_binary` unconditionally
  (confirmed near line 40; no version/existence check beforehand).
- **Force/version**: `--non-interactive` flag (confirmed lines 4-17) sets
  `ATUIN_NON_INTERACTIVE`. No force/version-pin flag found in this script (delegates to
  a Rust-based `cargo install`/binary-download path not fully inlined here).
- **Output**: No dedicated quiet/verbose flags.
- **Install dir**: `$HOME/.atuin/bin/atuin` (confirmed ~line 62). **Rewrites rc files
  directly**: appends to `~/.zshrc` (using `${ZDOTDIR:-$HOME}` — partial XDG-adjacent
  handling for zsh only), `~/.bashrc`, `~/.config/fish/config.fish`. No general XDG
  support for the binary dir itself.
- **Verification**: None beyond TLS transport (`curl --proto '=https' --tlsv1.2`) — no
  checksum/signature of the payload itself.
- **Exit codes**: Not rigorously coded — largely permissive/best-effort script.
- **CI/non-interactive**: **TTY + `/dev/tty` probe**, confirmed verbatim (lines 13-17):
  ```sh
  if [ "$ATUIN_NON_INTERACTIVE" != "yes" ]; then
    if [ -t 0 ] || { true </dev/tty; } 2>/dev/null; then
      ATUIN_NON_INTERACTIVE="no"
    else
      ATUIN_NON_INTERACTIVE="yes"
    fi
  fi
  ```
  This is the most careful TTY-detection in the survey — it doesn't just check stdin,
  it also tries opening `/dev/tty` directly (covers the classic `curl | sh` case where
  stdin is the pipe but a real terminal is still attached).

### 12. mise (`mise.run` → `jdx/mise install.sh`)
Source: `curl -sL https://mise.run` (verified directly, 371 lines; not committed as a
standalone file in the `jdx/mise` GitHub tree — served dynamically, version-pinned
checksums baked in at serve time)

- **Presence check**: **The single most relevant precedent in this whole survey** — an
  **explicit, named, opt-in "skip if already present" flag**. Confirmed verbatim
  (lines 286-298):
  ```sh
  # Opt-in: skip the download/install if the binary already at the install
  # path matches the requested version. Only the install path is checked (not
  # the wider PATH) so that skipping never leaves install_path missing.
  skip_if_exists="${MISE_INSTALL_SKIP_IF_EXISTS-}"
  if [ "$skip_if_exists" = "1" ] || [ "$skip_if_exists" = "true" ]; then
    if [ -x "$install_path" ]; then
      existing_version="$(installed_mise_version "$install_path")"
      if [ -n "$existing_version" ] && [ "$existing_version" = "$version" ]; then
        info "mise: $install_path is already at version $version, skipping install"
        return 0
      fi
    fi
  fi
  ```
  Two things to note precisely: (a) it is **opt-in via `MISE_INSTALL_SKIP_IF_EXISTS`**,
  not the default — by default mise always reinstalls/overwrites; (b) it deliberately
  checks **only the specific install path**, not the wider `PATH`, with an explicit
  comment explaining why (so skipping never leaves the target path empty). This is
  closer to "idempotent re-run of a known target" than "detect any existing install
  anywhere and back off."
- **Force/version**: `MISE_VERSION` pins version (default baked into the served script,
  e.g. `v2026.7.7` at fetch time). `MISE_INSTALL_FROM_GITHUB=1` changes the download
  source. No literal `--force` flag; overwriting is simply default behavior when the
  skip-if-exists opt-in isn't set.
- **Output**: `MISE_DEBUG=1` → `debug()` prints to stderr; `MISE_QUIET=1` → `info()`
  becomes a no-op (confirmed lines 15-23, both env-gated, both routed through stderr
  when active — even `info` goes to `>&2`, never stdout).
- **Install dir**: `MISE_INSTALL_PATH`, default `$HOME/.local/bin/mise` (confirmed line
  282: `install_path="${MISE_INSTALL_PATH:-$HOME/.local/bin/mise}"`). No XDG var
  consulted directly (though the default coincides with the common XDG convention for
  user binaries). **Does not modify shell rc files itself** — only prints an
  `after_finish_help()` block (confirmed lines 341-365) with the exact `eval
  "$(mise activate bash)" >> ~/.bashrc`-style line to add, gated by `$SHELL` detection;
  suppressible via `MISE_INSTALL_HELP=0`.
- **Verification**: **Real, mandatory checksum verification.** For the exact version
  matching what the script was served with, checksums are inlined as literals in the
  script itself (baked in when `mise.run` serves it); for any other pinned
  `MISE_VERSION`, it fetches `SHASUMS256.txt` from the GitHub release and greps the
  matching line (confirmed lines 126-233). Verification runs via
  `"$(shasum_bin)" -c` after download (line 312) — **and if neither `shasum` nor
  `sha256sum` exists, it hard-fails**: `error "mise install requires shasum or
  sha256sum but neither is installed. Aborting."` (line 122) — this is the opposite of
  uv's "skip and proceed" policy on missing hash tooling. A `# TODO: verify with
  minisign or gpg if available` comment (line 225) confirms no signature verification
  yet, checksum-only today. (Docs additionally mention a separate GPG-signed variant of
  the install script itself, `install.sh.sig`, verifiable independently before running
  — this was not independently confirmed in the fetched script but is documented at
  https://mise.jdx.dev/installing-mise.html.)
- **Exit codes**: `error()` → `echo ... >&2; exit 1`. Clean single-path exit-0 on
  success or on the skip-if-exists early return.
- **CI/non-interactive**: No TTY/`CI=` check — script has zero interactive prompts, so
  it's unconditionally pipe-safe. `MISE_QUIET=1` is the closest lever for CI log
  hygiene.

### 13. k3s (`get.k3s.io` → `k3s-io/k3s install.sh`)
Source: https://raw.githubusercontent.com/k3s-io/k3s/master/install.sh (verified, 1215 lines)

- **Presence check**: **Yes — hash-comparison based, not version-based.** Function
  `installed_hash_matches()` (confirmed lines 476-483):
  ```sh
  installed_hash_matches() {
      if [ -x ${BIN_DIR}/k3s ]; then
          HASH_INSTALLED=$(sha256sum ${BIN_DIR}/k3s)
          HASH_INSTALLED=${HASH_INSTALLED%%[[:blank:]]*}
          if [ "${HASH_EXPECTED}" = "${HASH_INSTALLED}" ]; then
              return
          fi
      fi
      return 1
  }
  ```
  Called at the point of binary install (confirmed lines 766-772):
  `if installed_hash_matches; then info 'Skipping binary downloaded, installed k3s
  matches hash'; return; fi`. **Speaks about it** (not silent) — prints an explicit
  `[INFO]`-level message when skipping. Same pattern reused for the `kubectl`/`crictl`/
  `ctr` symlinks: skip-and-say if already present (`"Skipping ${BIN_DIR}/${cmd} symlink
  to k3s, already exists"`, confirmed).
- **Force/version**: `INSTALL_K3S_FORCE_RESTART` (confirmed line 26) forces a service
  restart even if the binary was unchanged. `INSTALL_K3S_VERSION` pins version.
  `INSTALL_K3S_SKIP_DOWNLOAD=true|binary|selinux` skips fetching but still requires an
  executable binary already present. `INSTALL_K3S_SYMLINK=force|skip` controls the
  symlink-overwrite behavior independently.
- **Output**: Three-tier logging confirmed: `info()` → stdout with `[INFO]`; `warn()` →
  stderr with `[WARN]`; `fatal()` → stderr with `[ERROR]`, `exit 1`. No dedicated
  quiet/verbose flag — most command output is redirected to `/dev/null` internally
  rather than gated by a user flag.
- **Install dir**: `INSTALL_K3S_BIN_DIR` env, default `/usr/local/bin`, with an
  automatic fallback to `/opt/bin` if `/usr/local/bin` isn't writable (confirmed lines
  232-239). No XDG. No PATH/rc modification — only binary symlinks in `$BIN_DIR`.
- **Verification**: Mandatory SHA256 check (`download_hash` → `verify_binary`),
  **fatal on mismatch**: `"Download sha256 does not match"`. `curl`/`wget` both absent
  is fatal too. No GPG/signature layer.
- **Exit codes**: `fatal()` is always `exit 1`. No differentiated codes.
- **CI/non-interactive**: None explicit — it's a systemd/openrc service installer, zero
  prompts by design, inherently pipe-safe.

### 14. Helm (`get_helm.sh` / `get-helm-3`)
Source: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 (verified, 347 lines)

- **Presence check**: **Yes — version-string comparison, cleanest "check → skip"
  control-flow in the survey.** Function `checkHelmInstalledVersion()` (confirmed lines
  134-148):
  ```sh
  checkHelmInstalledVersion() {
    if [[ -f "${HELM_INSTALL_DIR}/${BINARY_NAME}" ]]; then
      local version=$("${HELM_INSTALL_DIR}/${BINARY_NAME}" version --template="{{ .Version }}")
      if [[ "$version" == "$TAG" ]]; then
        echo "Helm ${version} is already ${DESIRED_VERSION:-latest}"
        return 0
      else
        echo "Helm ${TAG} is available. Changing from version ${version}."
        return 1
      fi
    else
      return 1
    fi
  }
  ```
  Wired directly into the main control flow (confirmed lines 341-345):
  `if ! checkHelmInstalledVersion; then downloadFile; verifyFile; installFile; fi`.
  **Speaks on stdout either way** (present-and-current, or present-but-stale, or
  absent) — never silent.
- **Force/version**: `--version|-v <version>` (confirmed in flag parsing, ~lines
  227-246) sets `DESIRED_VERSION`, used directly by the version-match check above — so
  `--version` **does not force a reinstall of the same version**; it changes what
  "current" means, and if the installed version already matches, it still skips.
  `--no-sudo` avoids privilege escalation. No literal `--force` flag exists.
- **Output**: `DEBUG=true` env → `set -x` for full trace. No `--quiet`. Checksum step's
  stderr is redirected to `/dev/null` unless `DEBUG=true`.
- **Install dir**: `HELM_INSTALL_DIR` env, default `/usr/local/bin` (confirmed line 25:
  `: ${HELM_INSTALL_DIR:="/usr/local/bin"}`). No CLI flag for it, env-only. No XDG. No
  PATH/rc modification.
- **Verification**: Mandatory SHA256 via `openssl sha1 -sha256`
  (`verifyChecksum()`/`verifyFile`, confirmed lines 168-176). **If `openssl` is
  missing, the script aborts** rather than skipping:
  `"In order to verify checksum, openssl must first be installed."` (confirmed). Also
  `VERIFY_CHECKSUM="true"` by default — settable to `false` to opt out entirely, but
  no silent auto-skip on missing tooling (contrast with uv, which auto-skips).
- **Exit codes**: 0 success, 1 all failure paths (unsupported OS/arch, missing tools,
  checksum failure). `fail_trap()` on `EXIT` prints a support-URL hint on any non-zero
  exit.
- **CI/non-interactive**: No explicit `CI=`/TTY detection; script has no interactive
  prompts at all (only CLI flags), so it's unconditionally pipe-safe.

### 15. Go-ecosystem installers: golangci-lint, go-task

Both are built on the **same public-domain boilerplate**, `client9/shlib`
(https://github.com/client9/shlib), which is itself the ancestor of the GoReleaser
"install.sh" template still recommended in GoReleaser docs for distributing prebuilt
Go binaries.

- **golangci-lint** — https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh
  (verified, 433 lines). Explicit attribution confirmed at lines 141-143 and 389
  ("End of functions from https://github.com/client9/shlib").
- **go-task** — https://raw.githubusercontent.com/go-task/task/main/install-task.sh
  (verified, 381 lines). Identical attribution confirmed at lines 115-117, 337.

Both scripts, confirmed identical in relevant behavior:
- **Presence check**: **None** — `install "${srcdir}/${binexe}" "${BINDIR}/"` (both,
  confirmed) unconditionally overwrites.
- **Force/version**: No force flag; no version-pin flag beyond a positional tag arg in
  some shlib-derived variants. `BINDIR` env or `-b <dir>` flag.
- **Output**: `-d` → debug logging (`log_set_priority 10`); `-x` → `set -x` shell
  trace. No quiet flag — default is already fairly terse (`log_info`).
- **Install dir**: `BINDIR=${BINDIR:-./bin}` (confirmed both, e.g. golangci-lint line
  24, task line 29) — **defaults to a relative `./bin` in the current directory**, not
  a system or user-home path at all. This is a meaningfully different convention from
  every other tool surveyed (all of which default to an absolute path). Override via
  `-b` flag or `BINDIR` env. No XDG support.
- **Verification**: Mandatory SHA256 (`hash_sha256_verify`), confirmed in both. No
  silent skip if checksum file/tool missing — logs `log_crit` and returns nonzero,
  which under `set -e` halts the script.
- **Exit codes**: `exit 2` on usage/flag-parse error; `exit 1` on all other failures
  (unsupported platform, missing hash command, checksum mismatch). This 2-vs-1 split
  (usage error vs. runtime error) is unique to this boilerplate family in the survey.
- **CI/non-interactive**: None — zero prompts by construction.

**Not independently surveyed / could not verify**: I did not find a distinct, actively
maintained GoReleaser-authored canonical `install.sh` outside this shlib lineage —
GoReleaser's own docs point users to this same client9/shlib-descended pattern
(godownloader-generated) rather than shipping a different convention. If
`rocne/release-ci` wants a second, non-shlib Go-ecosystem data point, I was not able to
find one in scope for this pass; flagging rather than guessing.

---

## Cross-project comparison table

| Tool | Presence check? | On match, does | Force flag | Version pin (env/flag) | Quiet | Verbose | Install dir default | Override (flag/env) | XDG honored? | Modifies rc files? | Checksum/sig | Missing-verify-tool behavior | Non-interactive detection |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rustup | No | — | none | `RUSTUP_VERSION` | `-q`/`--quiet` | `-v`/`--verbose` (doc only) | delegated to binary | delegated | No | delegated to binary | None | N/A | TTY (`-t 0/1`), `-y` |
| Homebrew | No | — | none | none | none | none | `/opt/homebrew`, `/usr/local`, or `/home/linuxbrew/.linuxbrew` | none (env `HOMEBREW_PREFIX` only) | No | print-only | None | N/A | `CI=1`, `NONINTERACTIVE=1`, TTY |
| Docker | Warns, sleeps 20s, proceeds | overwrite | none | `VERSION=` env | none | none | none (pkg mgr) | N/A | No | No | GPG key + pkg-mgr signature check | assumed present, no fallback | none explicit (`DRY_RUN`) |
| Deno | No | — | none | positional version arg | none | none | `$HOME/.deno` | `DENO_INSTALL` env | No | delegates to separate tool | None | N/A | `CI=`, `[ -t 1 ]` |
| Bun | No (post-install check only) | — | none | none in script | none | none | `$HOME/.bun` | `BUN_INSTALL` env | partial (config search only) | Yes, direct | None | N/A | none (TTY for color only) |
| uv/Astral | No | — | none (has "force install *dir*", not force-reinstall) | `UV_VERSION`-style via URL, not confirmed as flag | `--quiet`/`UV_PRINT_QUIET` | `--verbose`/`UV_PRINT_VERBOSE` | `$XDG_BIN_HOME` → `$XDG_DATA_HOME/../bin` → `~/.local/bin` | `UV_INSTALL_DIR` env | **Yes, `XDG_BIN_HOME` explicitly** | Yes, via `env` shim + rc sourcing | sha256/512/blake2 | **skips verification, proceeds** | GitHub Actions (`$GITHUB_PATH`) only |
| Starship | Doc says "updates," code doesn't check | overwrite (undocumented-as-check) | `-f`/`-y`/`--force`/`--yes`/`FORCE=` | `-V` selects version elsewhere in flow | none | `-V`/`--verbose` | `/usr/local/bin` | `-b`/`--bin-dir` flag or `BIN_DIR` env | No | print-only | None | N/A | `-f/-y/--force/--yes` only |
| nvm | **Yes** (git-dir / script presence) | **update via git fetch**, not exit | none | `NVM_INSTALL_VERSION` | none | none | `$HOME/.nvm` (or `$XDG_CONFIG_HOME/nvm`) | `NVM_DIR` env | Yes, `XDG_CONFIG_HOME` | Yes, idempotent append | None | N/A | none (requires bash explicitly) |
| fnm | No | — | `--force-install`/`--force-no-brew` (means "skip brew," not "reinstall") | `-r`/`--release` | none | none | `$HOME/.fnm` → `$XDG_DATA_HOME/fnm` → OS default | `-d`/`--install-dir` flag | Yes, `XDG_DATA_HOME` | Yes, direct | None | N/A | `--skip-shell` only |
| Volta | **Yes**, version-exact match | **exit 1, refuses to reinstall same version** | none (no bypass) | `--version` flag | none | always verbose (stderr) | `$HOME/.volta` | `VOLTA_HOME` env | No | Yes, via `volta setup` subcommand | None | N/A | none (no prompts to begin with) |
| Atuin | No | — | none | none found | none | none | `$HOME/.atuin/bin` | none found | No | Yes, direct (zsh partially `ZDOTDIR`-aware) | TLS only, no payload checksum | N/A | `--non-interactive` + TTY + `/dev/tty` probe |
| mise | **Yes, opt-in** (`MISE_INSTALL_SKIP_IF_EXISTS`) | **skip, return 0, informs via stderr** | none (opt-out is the "force") | `MISE_VERSION` env | `MISE_QUIET=1` | `MISE_DEBUG=1` | `$HOME/.local/bin/mise` | `MISE_INSTALL_PATH` env | No (default coincides with convention) | print-only (`after_finish_help`) | sha256, mandatory | **hard-fails if sha256sum/shasum missing** | none (no prompts) |
| k3s | **Yes**, sha256 hash match | **skip binary write, still may restart service; informs via stdout** | `INSTALL_K3S_FORCE_RESTART` | `INSTALL_K3S_VERSION` env | none | none | `/usr/local/bin` (fallback `/opt/bin`) | `INSTALL_K3S_BIN_DIR` env | No | No | sha256, mandatory | fatal if curl+wget both absent | none (systemd install, no prompts) |
| Helm | **Yes**, version-string match | **skip entirely, informs via stdout** | none (`--version` changes target, doesn't force) | `--version`/`-v` flag, `DESIRED_VERSION` env | none | `DEBUG=true` env | `/usr/local/bin` | `HELM_INSTALL_DIR` env only | No | No | sha256 via openssl, mandatory | **aborts if openssl missing** | none (no prompts) |
| golangci-lint / go-task (shlib) | No | — | none | positional tag arg | none | `-d` | `./bin` (relative!) | `-b` flag / `BINDIR` env | No | No | sha256, mandatory | `log_crit`, halts via `set -e` | none |

---

## Synthesis

### Where there IS a genuine cross-project convention

1. **Errors to stderr, informational output to stdout (when it exists at all) — universal.**
   Every script that has a logging convention (rustup, Homebrew, Docker, k3s, Helm,
   mise, uv, Volta, Starship, nvm, Bun) routes error/warning text to `>&2`. This is the
   one true, unanimous convention in the whole survey.

2. **Env-var override for the install/target directory is universal; a matching
   `--flag` is optional and inconsistent.** Every tool that lets you customize the
   install location does so via an environment variable (`DENO_INSTALL`, `BUN_INSTALL`,
   `NVM_DIR`, `VOLTA_HOME`, `HELM_INSTALL_DIR`, `INSTALL_K3S_BIN_DIR`,
   `MISE_INSTALL_PATH`, `UV_INSTALL_DIR`, `BINDIR`). Only about half also expose a CLI
   flag for the same thing (fnm `-d`/`--install-dir`, Starship `-b`/`--bin-dir`,
   golangci-lint/task `-b`). **There is no single spelling.** See below — `INSTALL_DIR`
   is not dominant.

3. **Mandatory SHA256 checksum verification is the norm among tools that ship prebuilt
   binaries directly from GitHub releases** (k3s, Helm, mise, golangci-lint, go-task,
   uv). Tools that install via an OS package manager (Docker) or another package
   manager (Homebrew via git+brew) delegate trust to that layer instead. Tools that are
   thin wrappers around a second-stage installer (rustup, Deno's shell-setup, Docker's
   apt/dnf) don't verify anything themselves.

4. **`-y`/`--yes` (or `--force`/`-f` as a synonym) is the dominant non-interactive-
   consent spelling** where a confirmation prompt exists at all (rustup, Deno, Starship,
   Homebrew's near-equivalent `NONINTERACTIVE=1`/`CI=1`). But roughly half the survey
   (Docker, k3s, Helm, mise, golangci-lint, go-task, Volta, Atuin's alternate spelling)
   has **no interactive prompt to begin with**, making the flag moot — "no prompts, so
   nothing to bypass" is at least as common as "flag to bypass a prompt."

5. **When a script speaks about a decision it made (skip, warn, upgrade), it always
   speaks on informational output, never fully silently** — k3s, Helm, mise, nvm, Docker
   all print something even when taking the "do nothing" branch. **Fully silent
   presence-check-and-exit (zero output on the happy path) is not attested anywhere in
   this survey.** If `release-ci`'s script wants to be silent-on-match, that is a
   deliberate departure from observed convention, not a continuation of one — worth
   flagging explicitly in the script's own comments/docs.

### Where there is NO convention — genuinely fragmented, not manufactured consensus

1. **Install-directory env-var spelling is tool-specific, not standardized.**
   `DENO_INSTALL`, `BUN_INSTALL`, `NVM_DIR`, `VOLTA_HOME`, `HELM_INSTALL_DIR`,
   `INSTALL_K3S_BIN_DIR`, `MISE_INSTALL_PATH`, `UV_INSTALL_DIR`, `BINDIR`,
   `HOMEBREW_PREFIX`. **No two tools in this survey use the identical env var name for
   "where does the binary go."** `INSTALL_DIR` as a bare, unprefixed name **does
   appear** as a plain shell variable inside nvm and fnm's scripts, but it is a fully
   tool-namespaced or locally-scoped variable in every case — never a env var a *user*
   is expected to set (fnm's user-facing surface is the `-d/--install-dir` flag, not an
   `INSTALL_DIR=` env var; nvm's user-facing surface is `NVM_DIR`). **Nobody in this
   survey exposes a bare `INSTALL_DIR` env var as public API for the *user* to set** —
   it's always tool-prefixed (`UV_INSTALL_DIR`, `MISE_INSTALL_PATH`,
   `INSTALL_K3S_BIN_DIR`). `--dir`, `--install-dir` (fnm), and `--bin-dir` (Starship)
   are three different flag spellings for conceptually the same override.

2. **Presence-check behavior on match is genuinely inconsistent, not just in whether it
   exists but in *what happens*:** exit-with-refusal (Volta), skip-with-message (Helm,
   k3s, mise-opt-in), upgrade-in-place (nvm, Docker's "warn and proceed," Starship's
   claimed-but-unimplemented "auto-update"), or simply absent (rustup, Homebrew, Deno,
   Bun, Atuin, uv, fnm, golangci-lint, go-task). **Roughly 5 of 15 (Volta, nvm, k3s,
   Helm, mise) implement any check at all; that's a minority, not a majority.**

3. **Default install directory is not converging on one location.** `~/.local/bin`
   (mise, and uv's fallback tier) is used by only 2 of 15. Most tools use a
   **tool-specific home directory**: `~/.cargo/bin` (rustup, not directly confirmed in
   this script but the standard rustup outcome via the delegated binary), `~/.deno`,
   `~/.bun`, `~/.nvm`, `~/.volta`, `~/.fnm`/`~/.local/share/fnm`, `~/.atuin/bin`. System
   tools default to a shared system path instead: `/usr/local/bin` (Starship, Helm, k3s
   default) or platform-conditional (Homebrew). golangci-lint/go-task default to a
   **relative `./bin`** — meaningfully different from every other tool surveyed.
   **`~/.local/bin` is not "the" common default — it's one of at least four competing
   patterns** (tool-specific home dir, `/usr/local/bin`, `~/.local/bin`, relative
   `./bin`), and the tool-specific-home-dir pattern is actually the most common single
   bucket.

4. **`XDG_BIN_HOME` is honored by exactly one tool in this survey: uv.** fnm and nvm
   honor a *different* XDG var (`XDG_DATA_HOME`, `XDG_CONFIG_HOME` respectively) for a
   *different* purpose (state/config dir, not necessarily the binary itself, though fnm
   does put the binary there too). No tool besides uv treats `XDG_BIN_HOME` as
   authoritative for "where does the executable go." **If `release-ci`'s install.sh
   wants to honor `XDG_BIN_HOME`, it would be following uv's precedent specifically —
   not a broad ecosystem norm.**

5. **Verbose/quiet flag spelling and semantics are inconsistent.** rustup, Starship,
   uv, mise, golangci-lint/go-task all have *some* quiet/verbose/debug axis but none
   share exact flag names beyond the very generic `-q`/`-v`/`--quiet`/`--verbose`
   shape rustup and uv share coincidentally. Roughly half the survey (Homebrew, Docker,
   Deno, Bun, nvm, fnm, Volta, Atuin, k3s, Helm) has **no user-facing verbosity control
   at all** — output level is fixed.

6. **Missing-verification-tool behavior is split roughly down the middle between
   "abort" and "skip and proceed."** uv explicitly skips and proceeds when
   `sha256sum` is absent. mise, Helm, and golangci-lint/go-task explicitly abort when
   their hash/checksum tool is absent. This is a real, unresolved disagreement in the
   ecosystem, not an oversight in this research — cite both camps if
   `rocne/release-ci` picks one.

### Is presence-check-and-exit-quietly common, rare, or unheard of?

**Rare, and never fully silent.** Only 5 of the 15 tools surveyed (Volta, nvm, k3s,
Helm, mise) implement any form of "detect what's already there and change behavior
accordingly" — the majority (rustup, Homebrew, Docker*, Deno, Bun, Starship, Atuin,
fnm, uv, golangci-lint, go-task) simply download-and-overwrite unconditionally on every
run, treating the installer as idempotent-by-brute-force rather than
idempotent-by-detection. (*Docker is a partial exception: it detects and warns but
still proceeds — a middle case.)

Among the 5 that do check:
- **None are silent on the "already present" branch** — Helm, k3s, and mise all print
  an explicit informational message when skipping; Volta and nvm print/take visible
  action too. A truly silent, zero-output "detected present, exiting 0, said nothing"
  installer **does not appear anywhere in this survey**.
- **mise's `MISE_INSTALL_SKIP_IF_EXISTS`** is the closest primary-source precedent for
  exactly the "check for the tool and exit cleanly when present" pattern
  `rocne/release-ci` wants — but note it is **opt-in via an env var, not the default**,
  and mise's own default behavior is still unconditional overwrite. If
  `release-ci`'s install.sh makes presence-check-and-exit the *default* (not opt-in),
  that is a deliberate, defensible design choice but should be described as such rather
  than "what everyone does" — it's actually a minority pattern, and where it exists
  (mise) it's opt-in, not default.
- **Volta and Helm are the cleanest "exit cleanly, no work done" precedents** on an
  exact version/content match; **k3s and mise are the cleanest "skip work, print info,
  return success" precedents.** None of the four are silent.

### Anti-patterns / criticisms of `curl | sh` from authoritative discussion (secondary
sources — not primary docs, flagged as such)

- The core, widely-repeated technical objections (found via general web search, not a
  single canonical authoritative document): (1) no local inspection of the script
  before execution — a compromised or MITM'd server can serve arbitrary code that runs
  immediately with the invoking user's privileges; (2) partial/truncated downloads on
  network failure can execute a syntactically-valid-but-incomplete script, since shells
  don't require a full parse before starting execution of already-received lines in
  some invocation styles; (3) it collapses "download," "verify," and "execute" into one
  step, removing the natural checkpoint a separate `chmod +x && ./install.sh` flow
  would have. Source: general discussion (Hacker News thread
  https://news.ycombinator.com/item?id=10277470; "Curl to shell isn't so bad" rebuttal
  at https://www.arp242.net/curl-to-sh.html) — **these are opinion/blog-tier sources,
  not vendor primary docs, and are cited here only because the task explicitly asked
  for a synthesis of criticisms; treat as secondhand, not verified against an
  authoritative spec.**
- GitHub's own Actions-hardening guidance is reported (via the above search, not
  independently fetched from a GitHub primary doc in this pass) to discourage
  `curl | sh` / `curl | bash` inside CI workflows specifically because it bypasses
  code review and supply-chain pinning — **I could not independently verify the exact
  wording or locate the specific GitHub doc URL in this pass; flagging as unverified
  secondhand rather than citing a URL I didn't actually load.**
- The strongest **primary-source, in-script evidence of the vendors' own risk-awareness**
  found in this survey is Docker's explicit warning-and-20-second-sleep before
  reinstalling over an existing `docker` command (confirmed in script, cited above) —
  that's the vendors themselves building in a manual abort window, which is a tacit
  acknowledgment that unconditionally re-running the installer over an existing state
  is risky enough to warrant a deliberate pause.

### Direct answers to the specific questions posed

- **Is `INSTALL_DIR` or `--dir` the common spelling?** No. Neither is common. Every
  tool namespaces its install-dir env var with the tool's own name
  (`UV_INSTALL_DIR`, `MISE_INSTALL_PATH`, `BUN_INSTALL`, `VOLTA_HOME`,
  `HELM_INSTALL_DIR`, `INSTALL_K3S_BIN_DIR`, `NVM_DIR`, `DENO_INSTALL`). The only
  **unprefixed** spelling seen anywhere is `BINDIR` (golangci-lint, go-task, shared
  client9/shlib lineage) and `BIN_DIR` (Starship, k3s — as an env var derived from a
  prefixed flag). `--dir` as a bare flag was not seen; the closest flag spellings were
  `--install-dir` (fnm), `--bin-dir` (Starship), and `-b` (golangci-lint/go-task,
  Starship).
- **Does ANYONE honor `XDG_BIN_HOME`?** Yes — exactly one: **uv**, and it's the
  first-priority location in uv's own fallback chain (confirmed, uv-installer.sh lines
  ~1294-1296). No other tool in the survey references `XDG_BIN_HOME` at all.
- **Is `~/.local/bin` actually the common default?** No. It's used by mise (default)
  and uv (third-tier fallback only, after the two XDG tiers) — 2 of 15. The more common
  pattern by count is a **tool-specific dot-directory under `$HOME`**
  (`~/.cargo` via rustup's delegated binary, `~/.deno`, `~/.bun`, `~/.nvm`, `~/.volta`,
  `~/.fnm`, `~/.atuin`) — 7+ of 15 — followed by a shared **`/usr/local/bin`** for
  system-level tools (Starship, Helm, k3s) — 3 of 15.

---

## Sources index (all fetched/grepped directly on 2026-07-16 unless marked docs-only)

- rustup: https://raw.githubusercontent.com/rust-lang/rustup/master/rustup-init.sh
- Homebrew: https://raw.githubusercontent.com/Homebrew/install/master/install.sh
- Docker: https://raw.githubusercontent.com/docker/docker-install/master/install.sh (served at https://get.docker.com)
- Deno: https://raw.githubusercontent.com/denoland/deno_install/master/install.sh (served at https://deno.land/install.sh)
- Bun: https://bun.sh/install
- uv/Astral: https://astral.sh/uv/install.sh → 301 → https://releases.astral.sh/installers/uv/latest/uv-installer.sh
- Starship: https://raw.githubusercontent.com/starship/starship/master/install/install.sh (served at https://starship.rs/install.sh)
- nvm: https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh
- fnm: https://raw.githubusercontent.com/Schniz/fnm/master/.ci/install.sh
- Volta: https://raw.githubusercontent.com/volta-cli/volta/master/dev/unix/volta-install.sh (served at https://get.volta.sh); EOL status per https://lilting.ch/en/articles/volta-discontinued-migration-guide (secondary, unverified against an official Volta source)
- Atuin: https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh
- mise: fetched live via `curl https://mise.run`; docs at https://mise.jdx.dev/installing-mise.html
- k3s: https://raw.githubusercontent.com/k3s-io/k3s/master/install.sh (served at https://get.k3s.io)
- Helm: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 (served at https://get.helm.sh/get_helm.sh style URLs referenced in Helm docs)
- golangci-lint: https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh
- go-task: https://raw.githubusercontent.com/go-task/task/main/install-task.sh
- client9/shlib (shared ancestor of golangci-lint/go-task installers): https://github.com/client9/shlib

### Not reached / not independently verified
- A GoReleaser-authored (as opposed to shlib-descended) canonical Go-ecosystem
  `install.sh` convention distinct from client9/shlib — not found in scope.
- Exact wording of GitHub's Actions-hardening guidance on `curl | sh` — referenced only
  via secondary search result, not loaded from a GitHub primary doc in this pass.
- mise's separate GPG-signed install script variant (`install.sh.sig`) — documented on
  the mise docs page but not independently fetched/verified in this pass.
- Volta's official end-of-life statement — only found via a third-party migration-guide
  blog post, not an official Volta README/announcement in this pass.
