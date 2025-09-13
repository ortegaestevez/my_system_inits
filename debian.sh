#!/usr/bin/env bash

# This script sets up a Debian-based system WHICH USES GNOME as the desktop environment.

DEBIAN_VERSION=$(lsb_release -rs | cut -d. -f1)

snap_apps = ("nvim" "alacritty" "tmux")

# Update and install necessary packages
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y fd-find ripgrep snapd flatpak podman

# Install flatpak plugin for GNOME Software
sudo apt install gnome-software-plugin-flatpak
# Add Flathub repository if not already added
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install virt-manager via Flatpak
sudo flatpak install flathub org.virt_manager.virt-manager -y

# Install KVM and related packages (for virtualization)
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

# Enable and start libvirtd service
sudo systemctl enable --now libvirtd

# Add current user to libvirt and kvm groups
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Install MEGAsync
wget "https://mega.nz/linux/repo/Debian_$DEBIAN_VERSION/amd64/megasync-Debian_${DEBIAN_VERSION}_amd64.deb" && sudo dpkg -i "megasync-Debian_${DEBIAN_VERSION}_amd64.deb"

# Install Brave browser
curl -fsS https://dl.brave.com/install.sh | sh

# Install snap applications if not already installed
for app in "${snap_apps[@]}"; do
    if ! snap list | grep -q "$app"; then
        sudo snap install --classic "$app"
    else
        echo "$app is already installed."
    fi
done

# Install starship
curl -sS https://starship.rs/install.sh | sh

# Set up configuration files
mkdir -p $XDG_CONFIG_HOME
bash git clone "https://github.com/ortegaestevez/my_starship_config"
bash mv my_starship_config/starship.toml $XDG_CONFIG_HOME/starship.toml
bash rmdir my_starship_config

bash git clone "https://github.com/ortegaestevez/my_alacritty_config"
bash mv my_alacritty_config/alacritty.toml $XDG_CONFIG_HOME/alacritty.toml
bash rmdir my_alacritty_config

bash git clone "https://github.com/ortegaestevez/my_nvim_config"
bash mv my_nvim_config/ $XDG_CONFIG_HOME/nvim

bash git clone "https://github.com/ortegaestevez/my_tmux_config"
bash mv my_tmux_config/ $XDG_CONFIG_HOME/tmux
