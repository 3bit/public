#!/usr/bin/env bash

progress=()

LOGO="
 _____ _     _ _
|___ /| |__ (_) |_
  |_ \| '_ \| | __|
 ___) | |_) | | |_
|____/|_.__/|_|\__| Dotfile Installer
"

function write_header() {
  gum style --foreground 212 "$LOGO"
}

function write_progress() {
  clear
  write_header

  for line in "${progress[@]}"; do
    gum style --foreground 82 "✅ ${line}"
  done
}

function step_start() {
  write_progress
  echo
  gum style --foreground 212 "$1..."
}

function step_end() {
  progress+=("$1")
  write_progress
}

function install_required_packages() {
  step_start "Installing required packages"

  declare -a packages=(
    "curl"
    "gum"
    "chezmoi"
    "bw,bitwarden-cli"
  )

  install=false
  to_install=()

  # Loop through commands to check if they are installed
  for pkg in "${packages[@]}"; do
    cmd=$(echo "${pkg}" | cut -d "," -f 1)

    if ! command -v "${cmd}" &>/dev/null; then
      install=true
      pkg_name=$(echo "${pkg}" | cut -d "," -f 2)

      if [ -z "$pkg_name" ]; then
        pkg_name="${cmd}"
      fi

      to_install+=("${pkg_name}")
    fi
  done

  if ${install}; then
    sudo pacman -Syu  --noconfirm

    for pkg in "${to_install[@]}"; do
      echo "Installing ${pkg}"
      sudo pacman -S --needed --noconfirm ${pkg}
    done
    
  fi

  step_end "Installed required packages"
}

function configure_bitwarden_and_login() {
  step_start "Configuring Bitwarden and logging in"

  bw config server https://vault.bitwarden.eu >/dev/null 2>&1

  bw login --check --quiet
  if [ $? -eq 0 ]; then
    if [ -z "$BW_SESSION" ]; then
      export BW_SESSION=$(bw unlock --pretty --raw)
    fi
  else
    export BW_SESSION=$(bw login --pretty --method 0 --raw)
  fi


  if [ -z "$BW_SESSION" ]; then
    exit 1
  fi

  step_end "Bitwarden Setup and Login"
}

function test_github_access() {
  step_start "Testing access to Github"

  ssh-keyscan github.com >> $HOME/.ssh/known_hosts
  ssh -T git@github.com >/dev/null 2>&1
  if [ $? -eq 255 ]; then
    echo "Github Authentication failed."
    exit 1
  fi

  step_end "Access to Github is working"
}

function save_ssh_key() {
  step_start "Setup SSH Key for Github"

  mkdir -p $HOME/.ssh
  chmod 700 $HOME/.ssh
  ssh_key=$(bw get item ag@20251008 | jq .sshKey)
  if [ -z "ssh_key" ]; then
    echo "Failed loading SSH Key"
    exit 1
  fi

  echo $ssh_key | jq -r .privateKey > $HOME/.ssh/id_ed25519
  echo $ssh_key | jq -r .publicKey > $HOME/.ssh/id_ed25519.pub
  chmod 600 $HOME/.ssh/id_ed25519*

  step_end "SSH Key for Github is setup"
}

clear

install_required_packages
configure_bitwarden_and_login
save_ssh_key
test_github_access
