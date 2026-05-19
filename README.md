## Installation 
```bash 
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply https://github.com/hrabid/dotfiles.git
```
Source your `~/bashrc`
```bash
source ~/.bashrc
```
Run the Installation script for dependencies.
For `dnf` based systems:
```bash
dnf-install-dotfiles
```
For `apt` based systems:
```bash
apt-install-dotfiles
```
For `pacman` based systems:
```bash
pacman-install-dotfiles
```

