#!/usr/bin/env bash

# This script sets up a Debian-based system which uses GNOME as the desktop environment.

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Setup logging
LOG_FILE="/tmp/debian_setup_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Logging functions
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $*" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $*"
}

# Error handler
error_handler() {
    local line_number=$1
    log_error "Script failed at line $line_number. Check $LOG_FILE for details."
    exit 1
}

trap 'error_handler $LINENO' ERR

log_info "Starting Debian system setup script"
log_info "Log file: $LOG_FILE"

# Check if running on Debian-based system
if ! command -v lsb_release >/dev/null 2>&1; then
    log_error "lsb_release not found. Please install lsb-release package first."
    exit 1
fi

DEBIAN_VERSION=$(lsb_release -rs | cut -d. -f1)
log_info "Detected Debian version: $DEBIAN_VERSION"

# Fixed array declaration (no spaces around =)
snap_apps=("nvim" "alacritty" "tmux")

# Set XDG_CONFIG_HOME if not set
if [ -z "${XDG_CONFIG_HOME:-}" ]; then
    XDG_CONFIG_HOME="$HOME/.config"
    log_info "XDG_CONFIG_HOME not set, using default: $XDG_CONFIG_HOME"
fi

# Update and install necessary packages
log_info "Updating package lists and upgrading system"
sudo apt update -y && sudo apt upgrade -y
log_success "System updated successfully"

log_info "Installing base packages: fd-find, ripgrep, snapd, flatpak, podman"
sudo apt install -y fd-find ripgrep snapd flatpak podman
log_success "Base packages installed successfully"

# Install flatpak plugin for GNOME Software
log_info "Installing GNOME Software flatpak plugin"
sudo apt install -y gnome-software-plugin-flatpak
log_success "GNOME Software flatpak plugin installed"

# Add Flathub repository if not already added
log_info "Adding Flathub repository"
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
log_success "Flathub repository configured"

# Install virt-manager via Flatpak
log_info "Installing virt-manager via Flatpak"
sudo flatpak install flathub org.virt_manager.virt-manager -y
log_success "virt-manager installed successfully"

# Install KVM and related packages (for virtualization)
log_info "Installing KVM and virtualization packages"
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
log_success "KVM packages installed successfully"

# Enable and start libvirtd service
log_info "Enabling and starting libvirtd service"
sudo systemctl enable --now libvirtd
log_success "libvirtd service enabled and started"

# Add current user to libvirt and kvm groups
log_info "Adding user $USER to libvirt and kvm groups"
sudo usermod -aG libvirt "$USER"
sudo usermod -aG kvm "$USER"
log_success "User added to virtualization groups"

# Install MEGAsync
log_info "Installing MEGAsync"
MEGASYNC_DEB="megasync-Debian_${DEBIAN_VERSION}_amd64.deb"
if wget "https://mega.nz/linux/repo/Debian_$DEBIAN_VERSION/amd64/$MEGASYNC_DEB"; then
    sudo dpkg -i "$MEGASYNC_DEB"
    # Fix any dependency issues
    sudo apt-get install -f -y
    rm -f "$MEGASYNC_DEB"
    log_success "MEGAsync installed successfully"
else
    log_warning "Failed to download MEGAsync for Debian $DEBIAN_VERSION"
fi

# Install Brave browser
log_info "Installing Brave browser"
if curl -fsS https://dl.brave.com/install.sh | sh; then
    log_success "Brave browser installed successfully"
else
    log_error "Failed to install Brave browser"
fi

# Install Xodo PDF Reader
log_info "Installing Xodo PDF Reader"
if curl -fsS https://getpdfstudio.xodo.com/xodopdfstudio/XodoPDFStudio_linux64.sh | sh; then
    log_success "Xodo PDF Reader installed successfully"
else
    log_error "Failed to install Xodo PDF Reader"
fi

# Install snap applications if not already installed
log_info "Installing snap applications: ${snap_apps[*]}"
for app in "${snap_apps[@]}"; do
    log_info "Checking if $app is installed"
    if ! snap list | grep -q "^$app "; then
        log_info "Installing $app via snap"
        sudo snap install --classic "$app"
        log_success "$app installed successfully"
    else
        log_info "$app is already installed"
    fi
done

# Install starship
log_info "Installing starship prompt"
if curl -sS https://starship.rs/install.sh | sh -s -- -y; then
    log_success "Starship installed successfully"
else
    log_error "Failed to install starship"
fi

# Set up configuration files
log_info "Setting up configuration files"
mkdir -p "$XDG_CONFIG_HOME"

# Function to clone and move config
setup_config() {
    local repo_name=$1
    local config_name=$2
    local target_path=$3
    
    log_info "Setting up $config_name configuration"
    
    # Clean up any existing directory
    if [ -d "$repo_name" ]; then
        rm -rf "$repo_name"
    fi
    
    if git clone "https://github.com/ortegaestevez/$repo_name"; then
        if [ -d "$repo_name" ]; then
            mv "$repo_name/$config_name" "$target_path"
            rm -rf "$repo_name"
            log_success "$config_name configuration installed to $target_path"
        else
            log_error "Failed to find cloned directory $repo_name"
        fi
    else
        log_error "Failed to clone $repo_name repository"
    fi
}

# Setup configurations
setup_config "my_starship_config" "starship.toml" "$XDG_CONFIG_HOME/starship.toml"
setup_config "my_alacritty_config" "alacritty.toml" "$XDG_CONFIG_HOME/alacritty.toml"
setup_config "my_nvim_config" "." "$XDG_CONFIG_HOME/nvim"
setup_config "my_tmux_config" "." "$XDG_CONFIG_HOME/tmux"

log_success "All configurations installed successfully"

# Final message
log_success "Debian system setup completed successfully!"
log_info "Log file saved to: $LOG_FILE"

echo ""
echo "REMEMBER:"
echo "1. Restart your system to apply all changes and group memberships."
echo "2. Set alacritty as the default terminal emulator."
echo "3. Configure starship in your shell configuration file (e.g., .bashrc or .zshrc) by adding:"
echo '   eval "$(starship init bash)"  # or zsh, fish, etc.'
echo "4. Download a nerd font."
echo ""
echo "Setup log saved to: $LOG_FILE"
