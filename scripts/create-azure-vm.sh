#!/usr/bin/env bash
set -euo pipefail

# Provisions the Azure VM for the VS Code Remote SSH POC.
# Idempotent: re-running skips already-existing resources.
# Prerequisites: az CLI logged in, SSH key generated.

RESOURCE_GROUP="devbboxdemo"
LOCATION="eastus2"
VM_NAME="vscode-ssh-demo-vm"
VM_SIZE="Standard_B2s"
IMAGE="Ubuntu2204"
ADMIN_USER="devuser"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/vscode_demo_id_rsa}"

if [[ ! -f "${SSH_KEY_PATH}.pub" ]]; then
  echo "SSH public key not found at ${SSH_KEY_PATH}.pub"
  echo "Generate one with: ssh-keygen -t rsa -b 4096 -f ${SSH_KEY_PATH} -N ''"
  exit 1
fi

SSH_PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")

echo "=== Provisioning Azure VM: ${VM_NAME} ==="

# Create VM (no-op if already exists with same name)
az vm create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VM_NAME}" \
  --size "${VM_SIZE}" \
  --image "${IMAGE}" \
  --admin-username "${ADMIN_USER}" \
  --ssh-key-values "${SSH_KEY_PATH}.pub" \
  --public-ip-sku Standard \
  --output table

# Open port 22
az vm open-port \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VM_NAME}" \
  --port 22 \
  --priority 100 \
  --output none

VM_IP=$(az vm show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VM_NAME}" \
  --show-details \
  --query publicIps \
  --output tsv)

echo ""
echo "VM IP: ${VM_IP}"
echo ""
echo "=== Running bootstrap script on VM ==="

# Upload and run setup script
az vm run-command invoke \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VM_NAME}" \
  --command-id RunShellScript \
  --scripts "$(cat "$(dirname "$0")/setup-dev-vm.sh")" \
  --parameters "SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY}" \
  --output table

echo ""
echo "=== VM ready ==="
echo ""
echo "Next steps:"
echo "1. Add to ~/.ssh/config:"
echo "     Host vscode-ssh-demo"
echo "       HostName ${VM_IP}"
echo "       User ${ADMIN_USER}"
echo "       IdentityFile ${SSH_KEY_PATH}"
echo "       ForwardAgent yes"
echo "       ServerAliveInterval 60"
echo "       ServerAliveCountMax 10"
echo ""
echo "2. Open VS Code → Remote-SSH: Connect to Host → vscode-ssh-demo"
