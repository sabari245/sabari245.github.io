#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${CONFIG_URL:-https://vorden.dev}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sabari-dotfiles"
BASE_DIR="$STATE_DIR/base"
TMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TMP_DIR"' EXIT

echo "==> Sabari's dotfiles installer"
echo "==> Source: $BASE_URL"
echo ""

# Cache sudo credentials upfront
sudo -v
# Keep sudo alive in background
(while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done) &

# Detect distro
if command -v pacman &>/dev/null; then
    DISTRO="arch"
elif command -v apt &>/dev/null; then
    DISTRO="debian"
else
    echo "Error: Only Arch-based and Debian-based systems are supported."
    exit 1
fi

echo "==> Detected: $DISTRO"

# =============================================================================
# Install packages
# =============================================================================

if [ "$DISTRO" = "arch" ]; then
    echo "==> Syncing package database..."
    sudo pacman -Sy --noconfirm

    echo "==> Installing packages..."
    sudo pacman -S --needed --noconfirm \
        zsh tmux neovim git curl unzip \
        ripgrep zoxide eza fzf dua-cli \
        wl-clipboard xclip xsel \
        base-devel

elif [ "$DISTRO" = "debian" ]; then
    echo "==> Syncing package database..."
    sudo apt update

    echo "==> Installing packages..."
    sudo apt install -y \
        zsh tmux git curl unzip \
        ripgrep zoxide eza fzf \
        wl-clipboard xclip xsel \
        build-essential

    # Neovim - apt version is too old for 0.11+ features, install from release
    echo "==> Installing Neovim (latest stable)..."
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  NV_ARCH="x86_64" ;;
        aarch64) NV_ARCH="arm64" ;;
        *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    curl -LsSf "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NV_ARCH}.tar.gz" -o /tmp/nvim.tar.gz
    sudo rm -rf /opt/nvim-linux-"${NV_ARCH}"
    sudo tar xzf /tmp/nvim.tar.gz -C /opt/
    sudo ln -sf "/opt/nvim-linux-${NV_ARCH}/bin/nvim" /usr/local/bin/nvim
    rm /tmp/nvim.tar.gz

    # dua-cli (not in apt)
    echo "==> Installing dua-cli..."
    curl -LSfs https://raw.githubusercontent.com/Byron/dua-cli/master/ci/install.sh | \
        sh -s -- --git Byron/dua-cli --target x86_64-unknown-linux-musl --crate dua --tag v2.29.0
fi

# =============================================================================
# Zsh plugins
# =============================================================================

if [ ! -d ~/.zsh/fast-syntax-highlighting ]; then
    echo "==> Installing fast-syntax-highlighting..."
    mkdir -p ~/.zsh
    git clone --depth 1 https://github.com/zdharma-continuum/fast-syntax-highlighting ~/.zsh/fast-syntax-highlighting
else
    echo "==> fast-syntax-highlighting already installed, pulling latest..."
    git -C ~/.zsh/fast-syntax-highlighting pull
fi

# =============================================================================
# Download and install config files
# =============================================================================

echo "==> Installing config files..."

mkdir -p ~/.config/nvim
mkdir -p "$BASE_DIR"

backup_file() {
    local target="$1"
    local backup="${target}.bak.$(date +%Y%m%d_%H%M%S)"

    cp "$target" "$backup"
    echo "    Backed up $target -> $backup"
}

show_diff() {
    local target="$1"
    local incoming="$2"
    local diff_file="$TMP_DIR/diff"

    if command -v less &>/dev/null && [ -r /dev/tty ]; then
        git diff --no-index -- "$target" "$incoming" > "$diff_file" || true
        less -R "$diff_file" < /dev/tty > /dev/tty 2> /dev/tty || true
    else
        git diff --no-index -- "$target" "$incoming" || true
    fi
}

prompt_update_action() {
    local target="$1"
    local incoming="$2"
    local choice

    if [ ! -r /dev/tty ]; then
        UPDATE_ACTION="skip"
        return
    fi

    while true; do
        echo "" > /dev/tty
        echo "    $target already exists and differs from the incoming config." > /dev/tty
        printf "    [o]verwrite, [s]kip, [m]erge with nvimdiff, [d]iff, [q]uit: " > /dev/tty
        read -r choice < /dev/tty

        case "${choice,,}" in
            o|overwrite) UPDATE_ACTION="overwrite"; return ;;
            s|skip|"") UPDATE_ACTION="skip"; return ;;
            m|merge) UPDATE_ACTION="merge"; return ;;
            d|diff) show_diff "$target" "$incoming" ;;
            q|quit) UPDATE_ACTION="quit"; return ;;
            *) echo "    Unknown option: $choice" > /dev/tty ;;
        esac
    done
}

interactive_merge() {
    local target="$1"
    local base="$2"
    local incoming="$3"
    local label="$4"
    local merge_dir="$TMP_DIR/merge-${label}"
    local merged="$merge_dir/merged"
    local local_copy="$merge_dir/local"
    local base_copy="$merge_dir/base"
    local incoming_copy="$merge_dir/incoming"
    local answer

    if ! command -v nvim &>/dev/null; then
        echo "    nvim is required for interactive merge; skipping $target"
        return 1
    fi

    mkdir -p "$merge_dir"
    cp "$target" "$merged"
    cp "$target" "$local_copy"
    cp "$incoming" "$incoming_copy"

    if [ -f "$base" ]; then
        cp "$base" "$base_copy"
        git merge-file "$merged" "$base_copy" "$incoming_copy" || true
        echo "    Opening nvimdiff: edit and save the 'merged' buffer, then quit Neovim."
        nvim -d "$merged" "$local_copy" "$base_copy" "$incoming_copy" < /dev/tty > /dev/tty 2> /dev/tty
    else
        echo "    No previous managed base exists; opening a two-way nvimdiff."
        echo "    Edit and save the 'merged' buffer, then quit Neovim."
        nvim -d "$merged" "$incoming_copy" < /dev/tty > /dev/tty 2> /dev/tty
    fi

    if [ -r /dev/tty ]; then
        printf "    Use merged result for %s? [y/N]: " "$target" > /dev/tty
        read -r answer < /dev/tty
    else
        answer="n"
    fi

    case "${answer,,}" in
        y|yes)
            backup_file "$target"
            cp "$merged" "$target"
            cp "$incoming" "$base"
            echo "    Merged $target"
            ;;
        *)
            echo "    Skipped $target"
            ;;
    esac
}

install_managed_file() {
    local remote_path="$1"
    local target="$2"
    local base_name="$3"
    local incoming="$TMP_DIR/$base_name.incoming"
    local base="$BASE_DIR/$base_name"
    local action

    mkdir -p "$(dirname "$target")" "$(dirname "$base")"
    curl -LsSf "$BASE_URL/$remote_path" -o "$incoming"

    if [ ! -f "$target" ]; then
        cp "$incoming" "$target"
        cp "$incoming" "$base"
        echo "    Installed $target"
        return
    fi

    if cmp -s "$target" "$incoming"; then
        cp "$incoming" "$base"
        echo "    $target is already current"
        return
    fi

    prompt_update_action "$target" "$incoming"
    action="$UPDATE_ACTION"
    case "$action" in
        overwrite)
            backup_file "$target"
            cp "$incoming" "$target"
            cp "$incoming" "$base"
            echo "    Updated $target"
            ;;
        skip)
            echo "    Skipped $target"
            ;;
        merge)
            interactive_merge "$target" "$base" "$incoming" "$base_name"
            ;;
        quit)
            echo "Aborted."
            exit 1
            ;;
    esac
}

install_managed_file ".zshrc" "$HOME/.zshrc" "zshrc"
install_managed_file ".tmux.conf" "$HOME/.tmux.conf" "tmux.conf"
install_managed_file "init.lua" "$HOME/.config/nvim/init.lua" "nvim-init.lua"

# =============================================================================
# Set zsh as default shell
# =============================================================================

if [ "$SHELL" != "$(command -v zsh)" ]; then
    echo "==> Setting zsh as default shell..."
    sudo chsh -s "$(command -v zsh)" "$(whoami)"
fi

# =============================================================================
# Done
# =============================================================================

echo ""
echo "==> All done! Installed:"
echo "    - zsh + fast-syntax-highlighting"
echo "    - tmux"
echo "    - neovim (with lazy.nvim auto-bootstrap)"
echo "    - ripgrep, zoxide, eza, fzf, dua-cli"
echo "    - wl-clipboard, xclip, xsel"
echo ""
echo "    Config files placed in:"
echo "    ~/.zshrc"
echo "    ~/.tmux.conf"
echo "    ~/.config/nvim/init.lua"
echo ""
echo "    Restart your shell or run: exec zsh"
