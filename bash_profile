[ -f ~/.bashrc ] && source ~/.bashrc

[ -x /usr/bin/fish ] && [ -n "$SSH_CONNECTION" ] && [[ $- == *i* ]] && exec /usr/bin/fish
