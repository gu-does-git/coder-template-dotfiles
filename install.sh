#!/bin/bash

# NVM Install
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

nvm install node
nvm use node

# Deno install
curl -fsSL https://deno.land/install.sh | sh _ --yes

# Bun install
curl -fsSL https://bun.sh/install | bash

# Tailscale install
if [ "$OAUTH_CLIENT_SECRET" != "" ] ; then
    curl -fsSL https://tailscale.com/install.sh | sh
    sudo nohup /usr/sbin/tailscaled > ~/tailscaled.log 2>&1 & disown
    sudo tailscale up --auth-key=$OAUTH_CLIENT_SECRET --advertise-tags=tag:coder
fi

# Fish shell
sudo apt-add-repository ppa:fish-shell/release-4
sudo apt update
sudo apt install fish --yes

# Starship
curl -sS https://starship.rs/install.sh | sh -s -- -y
echo 'eval "$(starship init fish)"' >> ~/.config/fish/config.fish
starship preset no-runtime-versions -o ~/.config/starship.toml
sudo chsh -s /usr/bin/fish

# UV install
curl -LsSf https://astral.sh/uv/install.sh | sh