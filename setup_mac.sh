DOT = $HOME/dotfiles

# $HOME
ln -fs $DOT/zsh/.zshrc $HOME/.zshrc
ln -fs $DOT/tmux/.tmux $HOME/.tmux
ln -fs $DOT/tmux/.tmux.conf $HOME/.tmux.conf
ln -fs $DOT/fzf/.fzf.zsh $HOME/.fzf.zsh

# .config
CONF = $HOME/.config

ln -fs $DOT/nvim $CONF/nvim
ln -fs $DOT/sheldon $CONF/sheldon
ln -fs $DOT/wezterm $CONF/wezterm
ln -fs $DOT/starship.toml $CONF/starship.toml





