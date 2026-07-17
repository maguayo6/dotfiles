#!/usr/bin/env bash
# shellcheck shell=bash
# Common helpers for bootstrap.sh: logging, platform detection, idempotent installers.
# Sourced by bootstrap.sh — relies on $DOTFILES, $BACKUP_DIR, and pkg_name/CORE_PKGS
# from lib/packages.sh being available.

# ---------------------------------------------------------------- logging ----
if [ -t 1 ]; then
  _c_b=$'\033[34m'; _c_g=$'\033[32m'; _c_y=$'\033[33m'; _c_r=$'\033[31m'; _c_0=$'\033[0m'
else
  _c_b=; _c_g=; _c_y=; _c_r=; _c_0=
fi
log()  { printf '%s==>%s %s\n' "$_c_b" "$_c_0" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$_c_g" "$_c_0" "$*"; }
warn() { printf '%s   !%s %s\n' "$_c_y" "$_c_0" "$*" >&2; }
err()  { printf '%s   x%s %s\n' "$_c_r" "$_c_0" "$*" >&2; }
die()  { err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# Run a command as root when needed. On Linux non-root: via sudo. As root or on
# macOS (brew must NOT be sudo'd): run directly.
as_root() {
  if [ -n "${SUDO:-}" ]; then sudo "$@"; else "$@"; fi
}

# ------------------------------------------------------ platform detection ----
# Sets globals: OS (linux|macos), MGR (apt|dnf|brew), SUDO ("" | "sudo")
detect_platform() {
  case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux)  OS=linux ;;
    *)      die "unsupported OS: $(uname -s) (need Linux or macOS)" ;;
  esac

  if [ "$OS" = macos ]; then
    MGR=brew
  elif have apt-get; then
    MGR=apt
  elif have dnf; then
    MGR=dnf
  else
    die "no supported package manager found (need apt, dnf, or brew)"
  fi

  if [ "$OS" = linux ] && [ "$(id -u)" -ne 0 ]; then SUDO=sudo; else SUDO=""; fi
  ok "platform: $OS via $MGR"
}

keep_sudo_alive() {
  [ -n "${SUDO:-}" ] || return 0
  sudo -v || die "sudo is required to install system packages"
  ( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit 0; done ) 2>/dev/null &
}

ensure_homebrew() {
  [ "$OS" = macos ] || return 0
  have brew && return 0
  log "installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if   [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ];    then eval "$(/usr/local/bin/brew shellenv)"
  fi
}

# --------------------------------------------------- package installation ----
pkg_refresh() {
  case "$MGR" in
    apt)  as_root apt-get update -qq ;;
    dnf)  as_root dnf -q -y makecache || true ;;
    brew) brew update >/dev/null || true ;;
  esac
}

# pkg_install <generic-name>...  (names mapped per-manager via pkg_name)
pkg_install() {
  local g; local mapped=()
  for g in "$@"; do mapped+=("$(pkg_name "$g")"); done
  case "$MGR" in
    apt)  as_root apt-get install -y "${mapped[@]}" ;;
    dnf)  as_root dnf install -y "${mapped[@]}" ;;
    brew) brew install "${mapped[@]}" ;;
  esac
}

# best-effort: install each optional package one at a time, never fatal
pkg_install_optional() {
  local g
  for g in "$@"; do
    if pkg_install "$g" >/dev/null 2>&1; then ok "installed $g"
    else warn "could not install '$g' (skipping — install manually if you want it)"; fi
  done
}

# ------------------------------------------------ git clone-or-update (idem) --
# clone_or_pull <git-url> <dest-dir>
clone_or_pull() {
  local url="$1" dest="$2"
  if [ -d "$dest/.git" ]; then
    if git -C "$dest" pull --ff-only --quiet 2>/dev/null; then ok "updated $(basename "$dest")"
    else warn "could not fast-forward $(basename "$dest") (left as-is)"; fi
  else
    log "cloning $(basename "$dest")"
    git clone --depth 1 --quiet "$url" "$dest"
  fi
}

# --------------------------------- stow with backup of pre-existing files ----
# backup_and_stow <package>...   (uses $DOTFILES and $BACKUP_DIR)
backup_and_stow() {
  local pkg f target linkdest
  for pkg in "$@"; do
    [ -d "$DOTFILES/$pkg" ] || { warn "no such stow package: $pkg"; continue; }
    while IFS= read -r f; do
      target="$HOME/$f"
      if [ -L "$target" ]; then
        linkdest="$(readlink "$target")"
        case "$linkdest" in
          *"dotfiles/$pkg/"*) continue ;;   # already our stow symlink — leave it
        esac
        _stash "$target" "$f"               # foreign symlink -> back up
      elif [ -e "$target" ]; then
        _stash "$target" "$f"               # real file -> back up
      fi
    done < <(cd "$DOTFILES/$pkg" && find . -type f | sed 's|^\./||')
    stow --dir="$DOTFILES" --target="$HOME" --restow "$pkg" && ok "stowed $pkg"
  done
}

_stash() {
  local target="$1" rel="$2"
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  mv "$target" "$BACKUP_DIR/$rel"
  warn "backed up existing $target -> $BACKUP_DIR/$rel"
}
