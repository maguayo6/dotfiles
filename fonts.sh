#!/usr/bin/bash

## Install Meslo NF font
wget -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Meslo.zip \
	&& cd ~/.local/share/fonts \
	&& unzip JetBrainsMono.zip \
	&& rm JetBrainsMono.zip \
	&& fc-cache -fv