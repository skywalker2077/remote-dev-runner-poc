#!/usr/bin/env bash
set -euo pipefail

# Configuration
RG="devbboxdemo"
LOCATION="eastus2"
VM_NAME="vscode-ssh-demo-vm"
VM_SIZE="Standard_B2s"
IMAGE="Ubuntu2204"
ADMIN_USER="devuser"
SSH_KEY_PATH="${HOME}/.ssh/remote_dev_id_rsa.pub"

echo "Creating Azure VM: $VM_NAME"
echo "   Resource Group: $RG"
echo "   Location:       $LOCATION"
echo "   Size:           $VM_SIZE"

# Check SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "SSH public key not found at $SSH_KEY_PATH"
  echo "   Generate it with: ssh-keygen -t ed25519 -f ~/.ssh/remote_dev_id_rsa"
  exit 1
fi

# Create VM
az vm create \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --image "$IMAGE" \
  --size "$VM_SIZE" \
  --admin-username "$ADMIN_USER" \
  --ssh-key-values "$SSH_KEY_PATH" \
  --public-ip-sku Standard \
  --output table

# Open SSH port
az vm open-port \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --port 22 \
  --priority 100

# Get public IP
PUBLIC_IP=$(az vm show \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --show-details \
  --query publicIps \
  --output tsv)

echo ""
echo "VM created successfully!"
echo "   Public IP: $PUBLIC_IP"
echo ""
echo "Next steps:"
echo "  1. Run the bootstrap script on the VM:"
echo "     ssh -i ~/.ssh/remote_dev_id_rsa $ADMIN_USER@$PUBLIC_IP 'bash -s' < scripts/setup-dev-vm.sh"
echo ""
echo "  2. Update your SSH config:"
echo "     sed 's/<AZURE_VM_PUBLIC_IP>/$PUBLIC_IP/' config/ssh-config.template >> ~/.ssh/config"
echo ""
echo "  3. Connect in VS Code: Remote-SSH: Connect to Host -> remote-dev-runner"
