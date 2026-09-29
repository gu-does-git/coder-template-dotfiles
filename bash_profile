[ -f ~/.bashrc ] && source ~/.bashrc

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
export BASH_ENV="$HOME/.bashenv"
# carrega o env tambem no shell interativo: o BASH_ENV so vale para bash
# nao-interativo, e o exec do fish abaixo so herda o que ja foi exportado
[ -f "$HOME/.bashenv" ] && . "$HOME/.bashenv"
alias cat='bat'
alias ls='eza'
alias ll='eza -la'
alias la='eza -a'

[ -x /usr/bin/fish ] && [ -n "$SSH_CONNECTION" ] && [[ $- == *i* ]] && exec /usr/bin/fish
