#!/usr/bin/env bash
# shellcheck shell=bash
# Package sets + generic-name -> per-manager name mapping, consumed by lib/common.sh.
#
# For the current tool set the package names happen to be identical across
# apt / dnf / brew, so pkg_name is mostly a pass-through. It's the single place
# to add a divergence when one shows up (add a "MGR:name) echo realname" case).
# Note: apt's `bat` installs the binary as `batcat` — the zsh-bat plugin already
# handles that, so no mapping is needed here.

pkg_name() {
  local g="$1"
  case "$MGR:$g" in
    # example of how to add a divergence:
    # dnf:fd) echo fd-find ;;
    *) echo "$g" ;;
  esac
}

# Essential — install must succeed (bootstrap aborts otherwise).
CORE_PKGS=(git stow zsh tmux curl unzip)

# Linux-only — fontconfig provides fc-cache for the Nerd Font install.
LINUX_PKGS=(fontconfig)

# Nice-to-have — best-effort; a failure here only warns (availability varies by distro).
NICE_PKGS=(fzf bat)
