# Developer Setup Guide

VS Code Remote SSH + Self-Hosted GitHub Actions Runner — Step-by-Step

Target audience: mid-level DevOps engineer familiar with Git, new to GitHub Actions self-hosted runners.

---

## 1. Prerequisites

Install the following tools on your **local machine** before starting:

| Tool | How to install |
|------|---------------|
| VS Code | https://code.visualstudio.com |
| Remote - SSH extension | VS Code → Extensions → `ms-vscode-remote.remote-ssh` |
| Azure CLI | https://learn.microsoft.com/cli/azure/install-azure-cli |
| GitHub CLI | https://cli.github.com |

Log in before running the setup scripts:

```bash
az login
gh auth login
```

---

## 2. Generate SSH Key Pair

Generate a dedicated key pair for this project (do not reuse your personal GitHub key):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/remote_dev_id_rsa -C "remote-dev-runner-poc"
```

This creates:
- `~/.ssh/remote_dev_id_rsa` — private key (never share this)
- `~/.ssh/remote_dev_id_rsa.pub` — public key (will be added to the Azure VM)

---

## 3. Provision the Azure VM

From the repo root, run:

```bash
bash scripts/create-azure-vm.sh
```

The script creates VM `vscode-ssh-demo-vm` (Standard_B2s, Ubuntu 22.04) in resource group `devbboxdemo` (eastus2), opens port 22, and prints the public IP at the end.

Expected time: **3–4 minutes**.

If the VM already exists (idempotent re-run), the script continues and prints the current IP.

---

## 4. Bootstrap the VM

Copy and run the setup script on the VM:

```bash
ssh -i ~/.ssh/remote_dev_id_rsa devuser@<PUBLIC_IP> 'bash -s' < scripts/setup-dev-vm.sh
```

This installs on the VM:
- `git`, `curl`, `wget`, `unzip`, `jq`
- Docker Engine
- Node.js LTS via nvm
- GitHub CLI (`gh`)
- Azure CLI (`az`)
- Clones this repo to `~/workspace/remote-dev-runner-poc`

Expected time: **4–6 minutes** on first run, ~1 minute on re-run.

---

## 5. Configure VS Code SSH

Add the VM to your SSH config:

```bash
# Replace <YOUR_IP> with the public IP from step 3
sed 's/<AZURE_VM_PUBLIC_IP>/<YOUR_IP>/' config/ssh-config.template >> ~/.ssh/config
```

The resulting block in `~/.ssh/config`:

```
Host remote-dev-runner
  HostName 20.x.x.x
  User devuser
  IdentityFile ~/.ssh/remote_dev_id_rsa
  ForwardAgent yes
  ServerAliveInterval 60
  ServerAliveCountMax 10
```

---

## 6. Connect via VS Code Remote SSH

1. Open VS Code on your local machine
2. Press `F1` → **Remote-SSH: Connect to Host…**
3. Select **remote-dev-runner**
4. VS Code opens a new window connected to the Azure VM
5. Extensions in `.vscode/settings.json` (Copilot, GitLens, Python, Docker) install automatically on the remote

You are now editing files **on the Azure VM** as if they were local. Copilot suggestions come from your local VS Code license but execute through the SSH tunnel.

---

## 7. Daily Workflow (edit → commit → remote build)

Inside the VS Code Remote SSH window:

```bash
cd ~/workspace/remote-dev-runner-poc
git checkout -b feature/my-change

# ... edit files with VS Code, Copilot assists inline ...

git add .
git commit -m "my change"
```

To trigger a remote build without leaving VS Code:

1. `Ctrl+Shift+P` → **Tasks: Run Task**
2. Choose:
   - **Remote Build: Full** — install + build + test + package
   - **Remote Build: Test Only** — install + test only
   - **Remote Build: Package Only** — install + package only

What `.vscode/scripts/remote-build.sh` does:
1. Creates a timestamped branch: `remote-build/<username>/<timestamp>`
2. Pushes it to GitHub
3. Waits 3 seconds for the Actions runner to pick up the run
4. Runs `gh run watch` to stream logs live in the VS Code terminal

---

## 8. Reading Results in GitHub Actions

After a build completes:

- **Logs** — streamed live in the VS Code terminal; also visible at GitHub → Actions tab
- **Test results** — JUnit XML uploaded as artifact (`test-results/`) — available for 7 days
- **Package** — `.tar.gz` artifact uploaded (`app-package-<sha>`) — available for 7 days
- **Job summary** — build/test/package status table posted under the Actions run summary tab
- **PR check** — if a PR targets the same SHA, the `remote-build/ci` status check appears

To open the last run directly:

**Tasks: Run Task → Open GitHub Actions**

---

## 9. Troubleshooting

**SSH timeout when connecting**
- Verify the VM is running: `az vm show -g devbboxdemo -n vscode-ssh-demo-vm --show-details --query powerState`
- Start it if stopped: `az vm start -g devbboxdemo -n vscode-ssh-demo-vm`
- Check port 22 is open: `az network nsg rule list -g devbboxdemo --nsg-name vscode-ssh-demo-vmNSG`

**`gh run watch` shows "no runs found"**
- The push may have taken longer than 3 seconds to trigger the workflow. Run manually:
  ```bash
  gh run list --branch remote-build/<your-branch> --limit 5
  ```

**Docker permission denied on VM**
- The `setup-dev-vm.sh` adds `$USER` to the docker group, but the change only takes effect in new shell sessions.
- Fix: `newgrp docker` or log out and back in via VS Code Remote SSH (Disconnect → Reconnect).

**`nvm: command not found` in VS Code terminal**
- nvm is sourced in `.bashrc` but not in non-login shells. Add to `~/.bashrc`:
  ```bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  ```
  Then reload: `source ~/.bashrc`

**VPN not connected (WDC production)**
- In WDC production, the Azure VM uses a private IP — you must connect via the WDC VPN or Azure Bastion before opening VS Code Remote SSH.
- For the POC (public IP), no VPN is required.

---

## 10. WDC Production Mapping

| POC (this repo) | WDC Production |
|---|---|
| `ubuntu-latest` runner | `wdc-ubuntu-latest` self-hosted runner |
| Azure VM public IP + port 22 | Azure VM private IP + WDC VPN / Azure Bastion |
| `skywalker2077/remote-dev-runner-poc` | `WDC-TEST-PLAYORG` GitHub org repo |
| Personal Azure subscription | WDC Azure subscription (Moin / Srini) |
| SSH key in `~/.ssh` | SSH key managed via Azure Key Vault |
| `devuser` local sudo | Entra ID (Azure AD) managed identity |

**How to migrate from POC to WDC production:**

1. Replace `ubuntu-latest` → `wdc-ubuntu-latest` in both workflow files (search for `# NOTE:` comments)
2. Update `RG`, `LOCATION`, and `VM_SIZE` in `scripts/create-azure-vm.sh` to WDC values
3. Remove the public IP / NSG port 22 rule; configure Bastion or VPN for SSH access
4. Store the SSH private key in Azure Key Vault; retrieve it at connection time
5. Transfer the repo to `WDC-TEST-PLAYORG` and update the remote URL in `setup-dev-vm.sh`
