#!/user/bin/env bash

# Install apt packages
source packages.sh

# Last step. Update settings
source ~/.zshrc
omz reload
