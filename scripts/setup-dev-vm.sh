#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for Ubuntu 22.04 Azure VM as developer environment.
# Safe to run multiple times (idempotent).

SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"
REPO="skywalker2077/remote-dev-runner-poc"
DEVUSER="devuser"
WORKSPACE="/home/${DEVUSER}/workspace"

echo "=== Starting dev VM setup ==="

# -------------------------------------------------------------------
# 1. System packages
# -------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
  git curl wget unzip jq \
  openssh-server \
  python3 python3-pip \
  ca-certificates gnupg lsb-release apt-transport-https \
  software-properties-common

# -------------------------------------------------------------------
# 2. GitHub CLI
# -------------------------------------------------------------------
if ! command -v gh &>/dev/null; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list
  apt-get update -y
  apt-get install -y gh
fi

# -------------------------------------------------------------------
# 3. Docker Engine
# -------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable docker
  systemctl start docker
fi

# -------------------------------------------------------------------
# 4. Azure CLI
# -------------------------------------------------------------------
if ! command -v az &>/dev/null; then
  curl -sL https://aka.ms/InstallAzureCLIDeb | bash
fi

# -------------------------------------------------------------------
# 5. devuser
# -------------------------------------------------------------------
if ! id "${DEVUSER}" &>/dev/null; then
  useradd -m -s /bin/bash "${DEVUSER}"
fi
usermod -aG sudo,docker "${DEVUSER}"
echo "${DEVUSER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${DEVUSER}"
chmod 440 "/etc/sudoers.d/${DEVUSER}"

# -------------------------------------------------------------------
# 6. nvm + Node.js LTS (run as devuser)
# -------------------------------------------------------------------
if [[ ! -d "/home/${DEVUSER}/.nvm" ]]; then
  sudo -u "${DEVUSER}" bash -c '
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm alias default node
  '
fi

# -------------------------------------------------------------------
# 7. SSH configuration
# -------------------------------------------------------------------
systemctl enable ssh
systemctl start ssh

SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i 's/^#AllowTcpForwarding.*/AllowTcpForwarding yes/' "${SSHD_CONFIG}"
sed -i 's/^AllowTcpForwarding.*/AllowTcpForwarding yes/' "${SSHD_CONFIG}"
grep -q "^AllowTcpForwarding" "${SSHD_CONFIG}" || echo "AllowTcpForwarding yes" >> "${SSHD_CONFIG}"

sed -i 's/^#GatewayPorts.*/GatewayPorts yes/' "${SSHD_CONFIG}"
sed -i 's/^GatewayPorts.*/GatewayPorts yes/' "${SSHD_CONFIG}"
grep -q "^GatewayPorts" "${SSHD_CONFIG}" || echo "GatewayPorts yes" >> "${SSHD_CONFIG}"

systemctl restart ssh

# -------------------------------------------------------------------
# 8. SSH authorized_keys
# -------------------------------------------------------------------
if [[ -n "${SSH_PUBLIC_KEY}" ]]; then
  SSH_DIR="/home/${DEVUSER}/.ssh"
  mkdir -p "${SSH_DIR}"
  echo "${SSH_PUBLIC_KEY}" >> "${SSH_DIR}/authorized_keys"
  sort -u "${SSH_DIR}/authorized_keys" -o "${SSH_DIR}/authorized_keys"
  chmod 700 "${SSH_DIR}"
  chmod 600 "${SSH_DIR}/authorized_keys"
  chown -R "${DEVUSER}:${DEVUSER}" "${SSH_DIR}"
fi

# -------------------------------------------------------------------
# 9. Clone repo
# -------------------------------------------------------------------
mkdir -p "${WORKSPACE}"
chown "${DEVUSER}:${DEVUSER}" "${WORKSPACE}"
if [[ ! -d "${WORKSPACE}/remote-dev-runner-poc/.git" ]]; then
  sudo -u "${DEVUSER}" git clone \
    "https://github.com/${REPO}.git" \
    "${WORKSPACE}/remote-dev-runner-poc"
fi

# -------------------------------------------------------------------
# 10. Done
# -------------------------------------------------------------------
VM_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo ""
echo "=== Setup complete ==="
echo ""
echo "Connect with VS Code Remote SSH:"
echo "  ssh ${DEVUSER}@${VM_IP}"
echo ""
echo "Or add to ~/.ssh/config:"
echo "  Host vscode-ssh-demo"
echo "    HostName ${VM_IP}"
echo "    User ${DEVUSER}"
echo "    IdentityFile ~/.ssh/vscode_demo_id_rsa"
echo "    ForwardAgent yes"
echo "    ServerAliveInterval 60"
echo "    ServerAliveCountMax 10"
