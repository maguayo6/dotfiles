#!/usr/bin/env bash
# bootstrap.sh — install & link these dotfiles on a fresh machine.
# Supports apt (Debian/Ubuntu), dnf (Fedora), and Homebrew (macOS).
# Idempotent: safe to re-run any time. See README.md.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES
# shellcheck source=lib/common.sh
. "$DOTFILES/lib/common.sh"
# shellcheck source=lib/packages.sh
. "$DOTFILES/lib/packages.sh"

WANT_EXTRAS=0
for arg in "$@"; do
  case "$arg" in
    --extras)  WANT_EXTRAS=1 ;;
    -h|--help) printf 'usage: ./bootstrap.sh [--extras]\n'; exit 0 ;;
    *)         die "unknown option: $arg (see --help)" ;;
  esac
done

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
export BACKUP_DIR
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

main() {
  detect_platform
  ensure_homebrew
  keep_sudo_alive

  log "installing packages"
  pkg_refresh
  pkg_install "${CORE_PKGS[@]}"
  [ "$OS" = linux ] && pkg_install "${LINUX_PKGS[@]}"
  pkg_install_optional "${NICE_PKGS[@]}"
  [ "$OS" = linux ] && pkg_install_optional "${LINUX_CLIP_PKGS[@]}"

  install_omz
  install_omz_extras
  install_nvm
  install_font

  log "linking configs with stow"
  backup_and_stow zsh git tmux

  install_tpm            # after stow: reads the just-linked ~/.tmux.conf
  scaffold_locals
  set_default_shell
  [ "$WANT_EXTRAS" = 1 ] && install_extras

  printf '\n'
  ok "all done — start a new shell:  exec zsh"
  ok "set your terminal font to 'MesloLGS Nerd Font' so prompt/tmux glyphs render"
  [ -d "$BACKUP_DIR" ] && warn "pre-existing files were backed up under $BACKUP_DIR"
}

install_omz() {
  if [ -d "$HOME/.oh-my-zsh" ]; then ok "oh-my-zsh present"; return; fi
  log "installing oh-my-zsh"
  RUNZSH=no KEEP_ZSHRC=yes CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended --keep-zshrc
}

install_omz_extras() {
  log "installing zsh plugins + powerlevel10k"
  clone_or_pull https://github.com/zsh-users/zsh-autosuggestions     "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  clone_or_pull https://github.com/MichaelAquilina/zsh-you-should-use "$ZSH_CUSTOM/plugins/you-should-use"
  clone_or_pull https://github.com/fdellwing/zsh-bat                 "$ZSH_CUSTOM/plugins/zsh-bat"
  clone_or_pull https://github.com/romkatv/powerlevel10k             "$ZSH_CUSTOM/themes/powerlevel10k"
}

install_nvm() {
  if [ -d "$HOME/.nvm" ]; then ok "nvm present"; return; fi
  log "installing nvm"
  # PROFILE=/dev/null so the installer doesn't append its snippet to our .zshrc
  # (our tracked .zshrc already sources nvm). Node itself: run `nvm install --lts`.
  PROFILE=/dev/null bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh)"
}

install_tpm() {
  local tpm="$HOME/.tmux/plugins/tpm"
  clone_or_pull https://github.com/tmux-plugins/tpm "$tpm"
  if [ -x "$tpm/bin/install_plugins" ]; then
    log "installing tmux plugins"
    "$tpm/bin/install_plugins" >/dev/null 2>&1 && ok "tmux plugins installed" \
      || warn "tmux plugin install reported issues (run 'prefix + I' in tmux)"
  fi
}

font_installed() {
  if [ "$OS" = macos ]; then
    ls "$HOME/Library/Fonts" 2>/dev/null | grep -qi "MesloLGS"
  else
    fc-list 2>/dev/null | grep -qi "MesloLGS"
  fi
}

install_font() {
  if font_installed; then ok "MesloLGS Nerd Font present"; return; fi
  log "installing MesloLGS Nerd Font"
  if [ "$OS" = macos ]; then
    brew install --cask font-meslo-lg-nerd-font || warn "font cask failed"
    return
  fi
  local dir="$HOME/.local/share/fonts" tmp
  mkdir -p "$dir"
  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/Meslo.zip" \
       https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Meslo.zip; then
    unzip -oq "$tmp/Meslo.zip" -d "$dir"
    fc-cache -f "$dir" >/dev/null 2>&1 || true
    ok "MesloLGS Nerd Font installed"
  else
    warn "could not download the Nerd Font"
  fi
  rm -rf "$tmp"
}

scaffold_locals() {
  if [ ! -f "$HOME/.gitconfig.local" ]; then
    cat > "$HOME/.gitconfig.local" <<'EOF'
# Machine-local git identity — not tracked. Fill in your details.
# DEFAULT identity for all repos. For a second (e.g. work) account, uncomment
# core.sshCommand to pin its SSH key.
[user]
	name = Your Name
	email = you@example.com
#[core]
#	sshCommand = ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes
EOF
    warn "created ~/.gitconfig.local — edit it to set your git name/email"
  fi
  if [ ! -f "$HOME/.gitconfig-personal.local" ]; then
    cat > "$HOME/.gitconfig-personal.local" <<'EOF'
# Machine-local PERSONAL identity + SSH key — not tracked. Applied in personal
# repos (~/dotfiles, ~/personal/*) via the includeIf blocks in ~/.gitconfig.
# Fill in + uncomment only if you use a separate personal git account.
#[user]
#	name = Your Name
#	email = you@personal.example
#[core]
#	sshCommand = ssh -i ~/.ssh/id_personal -o IdentitiesOnly=yes
EOF
    ok "created ~/.gitconfig-personal.local stub"
  fi
  if [ ! -f "$HOME/.zshrc.local" ]; then
    printf '%s\n' '# Machine-local zsh config — not tracked. Per-host PATH, tools, secrets.' \
      > "$HOME/.zshrc.local"
    ok "created ~/.zshrc.local stub"
  fi
}

set_default_shell() {
  local zsh_path; zsh_path="$(command -v zsh || true)"
  [ -n "$zsh_path" ] || { warn "zsh not found on PATH; skipping chsh"; return; }
  case "${SHELL:-}" in
    *zsh) ok "default shell already zsh"; return ;;
  esac
  log "setting default shell to zsh"
  if [ "$OS" = macos ] && ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi
  chsh -s "$zsh_path" || warn "chsh failed — set your shell manually: chsh -s $zsh_path"
}

# ------- optional extras (opt-in via --extras): GitHub CLI + VS Code ----------
install_extras() {
  log "installing extras"
  install_gh
  if [ "$MGR" = brew ]; then
    brew install --cask visual-studio-code || warn "VS Code cask failed"
  else
    warn "VS Code: install from https://code.visualstudio.com (method varies by distro)"
  fi
}

install_gh() {
  have gh && { ok "gh present"; return; }
  case "$MGR" in
    brew) brew install gh || warn "gh install failed" ;;
    dnf)  as_root dnf install -y gh || warn "gh install failed" ;;
    apt)
      as_root mkdir -p -m 755 /etc/apt/keyrings
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | as_root tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
      as_root chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | as_root tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      as_root apt-get update -qq && as_root apt-get install -y gh || warn "gh install failed"
      ;;
  esac
}

main "$@"
