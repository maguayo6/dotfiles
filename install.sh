#!/usr/bin/bash

# Install apt packages
source packages.sh

stow git
stow zsh

# Change default shell
sudo chsh -s $(which zsh)

# Last step. Update settings
# source ~/.zshrc
exec zsh # <- This should replace the source line above
omz reload
