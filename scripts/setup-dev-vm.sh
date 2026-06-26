#!/usr/bin/env bash
set -euo pipefail

echo "Setting up remote dev VM..."

# System update
sudo apt-get update -y && sudo apt-get upgrade -y

# Core tools
sudo apt-get install -y \
  git curl wget unzip jq \
  openssh-server \
  build-essential \
  ca-certificates \
  gnupg lsb-release

# Enable SSH
sudo systemctl enable ssh
sudo systemctl start ssh
sudo sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/' /etc/ssh/sshd_config
sudo sed -i 's/#GatewayPorts no/GatewayPorts yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker "$USER"

# Node.js via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" | \
  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y gh

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Clone repo
mkdir -p "$HOME/workspace"
cd "$HOME/workspace"
if [ ! -d "remote-dev-runner-poc" ]; then
  gh repo clone skywalker2077/remote-dev-runner-poc
fi

echo ""
echo "Dev VM setup complete!"
echo "   Workspace: $HOME/workspace/remote-dev-runner-poc"
echo "   Node: $(node --version)"
echo "   gh: $(gh --version | head -1)"
echo "   Docker: $(docker --version)"
