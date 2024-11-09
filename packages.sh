#!/usr/bin/bash

# Validate input
if [ "$#" -ne 2 ]; then
	echo "Usage: $0 <package_manager: apt, dnf...>"
	exit 1
fi
$MANAGER=$1
echo "Installing packages from $MANAGER";

# Install cli tools

# Ask for admin password upfront
sudo -v

# Keep-alive: update exisiting 'sudo' timestamp until the script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Update and upgrade already-installed stuff
$MANAGER update && $MANAGER upgrade -y

# Install binaries
# $MANAGER install build-essential
# $MANAGER install cmake make
# $MANAGER install docker docker-compose docker-buildx
# $MANAGER install gcc g++
# $MANAGER install gdb
$MANAGER install git
# $MANAGER install openssh openssl
$MANAGER install stow
# $MANAGER install tree
$MANAGER install zsh
$MANAGER install fontconfig  # For automatic Nerd Font install

# Install snaps
if [ $MANAGER -e "apt" ]; then
	snap install code
else if [ $MANAGER -e "dnf" ]; then
	echo "use a different manager"
fi

# Install gh
if [ $MANAGER -e "apt" ]; then
	(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
		&& sudo mkdir -p -m 755 /etc/apt/keyrings \
		&& wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
		&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
		&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
		&& sudo apt update \
		&& sudo apt install gh -y
else if [ $MANAGER -e "dnf" ]; then
	dnf install gh --repo gh-cli
fi

# Install oh-my-zsh --unattended since running from automated install script
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install powerlevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k


