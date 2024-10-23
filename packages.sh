#!/usr/bin/env bash

# Install cli tools

# Ask for admin password upfront
sudo -v

# Keep-alive: update exisiting 'sudo' timestamp until the script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Update and upgrade already-installed stuff
apt update && apt upgrade -y

# Install binaries
apt install build-essential
apt install cmake make
apt install gcc g++
apt install gdb
apt install git
apt install openssh openssl
apt install stow
apt install tree
apt install zsh zsh-autosuggestions

# Install snaps
snap install code

# Install gh
(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y
