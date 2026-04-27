[ -f ~/.bashrc ] && source ~/.bashrc

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
export BASH_ENV="$HOME/.bashenv"

[ -x /usr/bin/fish ] && [ -n "$SSH_CONNECTION" ] && [[ $- == *i* ]] && exec /usr/bin/fish
