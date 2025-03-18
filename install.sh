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
curl -fsSL https://tailscale.com/install.sh | sh
nohup /usr/sbin/tailscaled > ~/tailscaled.log 2>&1 & disown
sudo tailscale up