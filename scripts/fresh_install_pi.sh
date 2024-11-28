#!/usr/bin/env bash

###########################################
# Download and source this utility script #
###########################################
echo "[INFO] - Loading utility functions"
if ! type info /dev/null 2>&1; then
  echo "[INFO] Downloading '${HOME}/.shellrc' file"
  ! test -f "${HOME}/.shellrc" && curl -fsSL "https://raw.githubusercontent.com/dnitros/homelab/refs/heads/main/dotfiles/.shellrc" -o "${HOME}/.shellrc"
  source "${HOME}/.shellrc"
  success "Utility functions initialized"
else
  warn "Skipping downloading and sourcing of utility functions. Functions already initialized"
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
  sudo apt-get update -y
  sudo apt-get upgrade -y
  sudo apt-get autoclean -y
  sudo apt-get autoremove -y
  success "Packages updated and upgraded"
else
  success "No packages to upgrade"
fi

