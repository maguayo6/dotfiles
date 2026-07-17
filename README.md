# dotfiles

Personal dotfiles — zsh (oh-my-zsh + powerlevel10k), tmux, git — managed with
[GNU Stow](https://www.gnu.org/software/stow/) and a single cross-platform
bootstrap script. Works on **Debian/Ubuntu (apt)**, **Fedora (dnf)**, and **macOS (Homebrew)**.

## Quick start (fresh machine)

```sh
git clone git@github.com:maguayo6/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

Then `exec zsh` (or just open a new terminal). Only `git` and `curl` need to
already exist — the script installs everything else.

`bootstrap.sh` is **idempotent**: re-run it any time to pull new dependencies or
repair a machine. It never clobbers your data — anything it would overwrite is
moved to `~/.dotfiles-backup/<timestamp>/` first.

## What `bootstrap.sh` does

1. Detects the OS + package manager (apt / dnf / brew; installs Homebrew on macOS if missing).
2. Installs packages: `git stow zsh tmux curl unzip` (+ `fontconfig` on Linux), best-effort `fzf` + `bat`.
3. Installs oh-my-zsh, powerlevel10k, and the zsh plugins (`zsh-autosuggestions`, `zsh-syntax-highlighting`, `you-should-use`, `zsh-bat`).
4. Installs `nvm`, TPM + the tmux plugins, and the **MesloLGS Nerd Font**.
5. Stows `zsh`, `git`, `tmux` into `$HOME` (backing up any pre-existing files).
6. Sets `zsh` as the default shell.

Optional GUI/aux tools:

```sh
./bootstrap.sh --extras     # GitHub CLI (gh); VS Code on macOS, guidance elsewhere
```

## Machine-local & private settings

Host-specific or private values stay **out of the repo**, in two git-ignored files
that the tracked configs pull in automatically (scaffolded on first run):

| File | Holds | Wired via |
|------|-------|-----------|
| `~/.gitconfig.local` | default git `name`/`email` + SSH key (work) | `include` in `git/.gitconfig` |
| `~/.gitconfig-personal.local` | personal git `name`/`email` + SSH key | `includeIf` (personal folders) in `git/.gitconfig` |
| `~/.zshrc.local` | per-host `PATH`, work tools, secrets | sourced near the end of `zsh/.zshrc` |

Edit `~/.gitconfig.local` after the first run to set your identity.

## Multiple git accounts (work + personal)

Both the commit identity **and** the SSH key are chosen automatically by a repo's
folder — no per-repo setup, SSH host aliases, or remote-URL edits:

- **`~/dotfiles` and `~/personal/*`** → personal account (`~/.gitconfig-personal.local`)
- **everything else** (e.g. `~/neros/*`) → default/work account (`~/.gitconfig.local`)

It works via `includeIf "gitdir:…"` in `git/.gitconfig`; each identity file also sets
`core.sshCommand = ssh -i ~/.ssh/<key> -o IdentitiesOnly=yes`, so a plain
`git@github.com:…` clone authenticates with the right key based on where it lives.
Keep personal repos under `~/dotfiles` / `~/personal/`; SSH keys stay in `~/.ssh/` (never tracked).

## One manual step (per machine)

Set your terminal emulator's font to **“MesloLGS Nerd Font”** so the powerline
glyphs in the prompt and tmux status bar render. (The font file itself is installed
for you.)

## Layout

```
bootstrap.sh        # idempotent entry point
lib/common.sh       # helpers: platform detect, installers, stow-with-backup
lib/packages.sh     # package sets + per-manager name mapping
zsh/  git/  tmux/    # GNU Stow packages (symlinked into $HOME)
```

## Adding a config

Create a new stow package dir (e.g. `nvim/.config/nvim/init.lua`), add it to the
`backup_and_stow ...` line in `bootstrap.sh`, and re-run `./bootstrap.sh`.
