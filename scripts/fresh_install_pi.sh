#!/usr/bin/env bash

DOTFILES_DIR=${DOTFILES_DIR:-"${HOME}/.dotfiles"}
PERSONAL_BIN_DIR=${PERSONAL_BIN_DIR:-"${HOME}/bin"}

reboot_required=false

###########################################
# Download and source this utility script #
###########################################
echo "[INFO] - Loading utility functions"
if [ -f "${HOME}/.shellrc" ]; then
  source "${HOME}/.shellrc"
  if ! type info &> /dev/null 2>&1; then
    echo "[WARN] Incompatible version of '.shellrc' file found. Downloading the latest version"
    echo "[INFO] Downloading '${HOME}/.shellrc' file"
    curl -fsSL "https://raw.githubusercontent.com/dnitros/dotfiles/refs/heads/main/files/.shellrc" -o "${HOME}/.shellrc"
    source "${HOME}/.shellrc"
  fi
else
  echo "[INFO] Downloading '${HOME}/.shellrc' file"
  curl -fsSL "https://raw.githubusercontent.com/dnitros/dotfiles/refs/heads/main/files/.shellrc" -o "${HOME}/.shellrc"
  source "${HOME}/.shellrc"
fi
success "Utility functions initialized"

##############################
# Update SSH configuration   #
##############################
info "Updating SSH configuration to prevent locale issues"
if grep -q "^AcceptEnv LANG LC_*" /etc/ssh/sshd_config; then
  sudo sed -i '/^AcceptEnv LANG LC_\*/ s/^/#/' /etc/ssh/sshd_config
  success "SSH configuration updated successfully"
else
  info "SSH configuration already updated"
fi

#############################
# Update bootloader version #
#############################
info "Updating bootloader version"
if sudo rpi-eeprom-update; then
  info "Bootloader update available. Updating now..."
  sudo rpi-eeprom-update -a
  success "Bootloader updated successfully."
  reboot_required=true
else
  success "Bootloader is already up-to-date"
fi

##############################
# Disable WiFi and Bluetooth #
##############################
info "Disabling WiFi and Bluetooth"

# Disable WiFi
if ! grep -q "dtoverlay=disable-wifi" /boot/firmware/config.txt; then
  echo "dtoverlay=disable-wifi" | sudo tee -a /boot/firmware/config.txt > /dev/null
  success "WiFi disabled"
  reboot_required=true
else
  info "WiFi is already disabled"
fi

# Disable Bluetooth
if ! grep -q "dtoverlay=disable-bt" /boot/firmware/config.txt; then
  echo "dtoverlay=disable-bt" | sudo tee -a /boot/firmware/config.txt > /dev/null
  success "Bluetooth disabled"
  reboot_required=true
else
  info "Bluetooth is already disabled"
fi

###########################
# Update the apt packages #
###########################
info "Updating apt packages"
# Update package index
sudo apt-get update -qq

# Check for upgradable packages
needs_upgrade=$(sudo apt-get -s upgrade | grep -Eo '^[0-9]+ upgraded' | grep -vq '^0 upgraded' && echo "yes" || echo "no")

if [ "${needs_upgrade}" = "yes" ]; then
  info "Running update and upgrade"
  sudo apt-get update -y -q
  sudo apt-get upgrade -y -q
  sudo apt-get autoclean -y -q
  sudo apt-get autoremove -y -q
  success "Packages updated and upgraded"
else
  success "No packages to upgrade"
fi

########################
# Install dependencies #
########################
info "Installing dependencies"
xargs -a "${HOME}.packages" sudo apt-get install -y -q

##################
# Setup dotfiles #
##################
info "Setting up dotfiles"
if ! is_git_repo "${DOTFILES_DIR}"; then
  git clone -q "https://github.com/dnitros/dotfiles" "${DOTFILES_DIR}"
  sh "${DOTFILES_DIR}/scripts/install"
  load_bash_configs
  success "dotfiles setup successfully"
else
  load_bash_configs
  warn "skipping cloning the dotfiles repo since '${DOTFILES_DIR}' is not defined or already present"
fi

#######################
# Setup dev directory #
#######################
! is_directory "${HOME}/dev" && mkdir -p "${HOME}/dev"

######################
# Clone homelab repo #
######################
info "Cloning homelab repo"
if ! is_git_repo "${HOME}/dev/homelab"; then
  git clone https://github.com/dnitros/homelab.git "${HOME}/dev/homelab"
  success "homelab repo cloned successfully"
else
  info "homelab repo is already cloned"
fi

##################
# Install neovim #
##################
info "Installing neovim"
if ! command_exists nvim; then
  ! is_git_repo "${HOME}/dev/neovim" && git clone https://github.com/neovim/neovim.git "${HOME}/dev/neovim"
  cd "${HOME}/dev/neovim" || exit
  rm -r build/  # clear the CMake cache
  make CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=${PERSONAL_BIN_DIR}/neovim"
  make install
  success "neovim installed successfully"
else
  info "neovim is already installed"
fi

################
# Setup docker #
################
info "Installing docker"
if ! command_exists docker; then
  # Add Docker's official GPG key
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo usermod -aG docker "${USER}"
  success "Docker installed successfully"
else
  info "Docker is already installed"
fi

#############
# Reboot Pi #
#############
if [ "$reboot_required" = true ]; then
  info "Rebooting Pi in 5 seconds."
  sleep 5
  sudo reboot
else
  success "No reboot required"
fi
