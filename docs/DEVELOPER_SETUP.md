# Developer Setup Guide

VS Code Remote SSH + Self-Hosted GitHub Actions Runner — POC

Target audience: mid-level DevOps engineer familiar with Git but new to GitHub Actions self-hosted runners.

---

## Prerequisites

| Tool | Install |
|------|---------|
| VS Code | https://code.visualstudio.com |
| Remote - SSH extension | VS Code → Extensions → `ms-vscode-remote.remote-ssh` |
| Azure CLI | https://learn.microsoft.com/cli/azure/install-azure-cli |
| GitHub CLI | https://cli.github.com |
| SSH key pair | `ssh-keygen -t rsa -b 4096 -f ~/.ssh/vscode_demo_id_rsa -N ""` |

Log in before running the setup scripts:

```bash
az login
gh auth login
```

---

## Step 1 — Provision the Azure VM

```bash
# From repo root
chmod +x scripts/create-azure-vm.sh
SSH_KEY_PATH=~/.ssh/vscode_demo_id_rsa ./scripts/create-azure-vm.sh
```

The script:
- Creates VM `vscode-ssh-demo-vm` (Standard_B2s, Ubuntu 22.04) in RG `devbboxdemo`
- Opens port 22
- Runs `setup-dev-vm.sh` remotely to install all dev tools
- Prints the VM's public IP at the end

Expected time: **3–5 minutes**

---

## Step 2 — Configure VS Code SSH

1. Copy `config/ssh-config.template` to `~/.ssh/config` (append if the file exists):

```bash
cat config/ssh-config.template >> ~/.ssh/config
```

2. Replace `<AZURE_VM_PUBLIC_IP>` with the IP printed by the create script:

```
Host vscode-ssh-demo
  HostName 20.x.x.x        ← replace this
  User devuser
  IdentityFile ~/.ssh/vscode_demo_id_rsa
  ForwardAgent yes
  ServerAliveInterval 60
  ServerAliveCountMax 10
```

---

## Step 3 — Connect via VS Code Remote SSH

1. Press `F1` → **Remote-SSH: Connect to Host…**
2. Select **vscode-ssh-demo**
3. VS Code opens a new window connected to the Azure VM
4. Extensions listed in `.vscode/settings.json` install automatically on the remote

You are now editing files **on the Azure VM** through your local VS Code.

---

## Step 4 — Edit & Commit

Work exactly as you would locally:

```bash
cd ~/workspace/remote-dev-runner-poc
git checkout -b feature/my-change
# ... edit files ...
git add .
git commit -m "my change"
```

GitHub Copilot (if installed) works transparently over the SSH tunnel.

---

## Step 5 — Trigger a Remote Build

Open the VS Code Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`):

1. **Tasks: Run Task**
2. Choose one of:
   - **Remote Build: Full** — install + build + test + package
   - **Remote Build: Test Only** — install + test
   - **Remote Build: Package** — install + build + package

What happens under the hood:
1. A branch `remote-build/<username>/<timestamp>` is pushed to GitHub
2. `gh workflow run remote-build.yml` triggers the Actions workflow
3. `gh run watch` streams the logs live in the VS Code terminal
4. The Actions URL is printed at the end

Expected time: **~2 minutes** for a full build on `ubuntu-latest`.

---

## Step 6 — Read Results

- **Logs** — streamed in VS Code terminal, also at GitHub → Actions tab
- **Artifacts** — `.tar.gz` package available for 7 days under the Actions run
- **PR status check** — `remote-build/ci` check appears on any open PR targeting the same SHA

To open the last run in a browser:

**Tasks: Run Task → Open GitHub Actions**

---

## Step 7 — Remote Build Branches are Auto-Cleaned

A scheduled workflow (`cleanup-remote-build-branches.yml`) runs daily at 02:00 UTC and deletes all `remote-build/**` branches older than 7 days. No manual cleanup needed.

---

## WDC Production Mapping

| POC (personal) | WDC Production |
|---|---|
| `ubuntu-latest` runner | `wdc-ubuntu-latest` self-hosted runner |
| Azure VM public IP + port 22 | Azure VM private IP + VPN / Azure Bastion |
| `skywalker2077/remote-dev-runner-poc` | `WDC-TEST-PLAYORG` GitHub org repo |
| Personal Azure subscription | WDC Azure subscription (Moin / Srini) |
| SSH key in `~/.ssh` | SSH key managed via Azure Key Vault |
| `devuser` local sudo | AD/Entra ID managed identity |

To move from POC to WDC production:
1. Replace `ubuntu-latest` → `wdc-ubuntu-latest` in both workflow files (search for the `# NOTE:` comments)
2. Update `RESOURCE_GROUP` and `LOCATION` in `scripts/create-azure-vm.sh`
3. Remove public IP / port 22 exposure; use Bastion or VPN for SSH access
4. Swap SSH key management to Azure Key Vault
