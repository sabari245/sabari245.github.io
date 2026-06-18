# dotfiles

Portable zsh + tmux + neovim config for Debian and Arch-based systems.

## Install

```sh
curl -LsSf https://vorden.dev/install.sh | bash
```

## What's included

| File | Description |
|------|-------------|
| `.zshrc` | Zsh config with history, completions, prompt, zoxide, fzf, eza |
| `.tmux.conf` | Tmux config with vi mode, blue theme, mouse support, clipboard passthrough |
| `init.lua` | Neovim config with lazy.nvim, telescope, treesitter, LSP, completion, portable clipboard |

## Packages installed

**Both distros:** zsh, tmux, neovim, git, curl, ripgrep, zoxide, eza, fzf, dua-cli, wl-clipboard, xclip, xsel

Neovim is installed from the latest GitHub release on Debian (apt version is too old for 0.11+ features).

## Clipboard behavior

Local Neovim sessions use the native clipboard provider (`wl-copy` on Wayland, `xclip`/`xsel` on X11), both inside and outside tmux.

SSH Neovim sessions use OSC 52 so copy/paste goes through the local terminal clipboard, both inside and outside tmux. Terminal emulators must allow OSC 52 clipboard access for paste queries to work.

## Managed updates

The installer stores the last installed version of each managed config in `~/.local/state/sabari-dotfiles/base`. When an existing local file differs from the incoming version, the installer asks whether to overwrite, skip, show a diff, or perform an interactive `nvimdiff` merge.
