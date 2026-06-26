# remote-dev-runner-poc

POC demonstrating **VS Code Remote SSH + Self-Hosted GitHub Actions Runner** as an alternative to GitHub Codespaces and Microsoft Dev Box.

> Built by [@skywalker2077](https://github.com/skywalker2077) | Avanade DevOps Practice

---

## Why this exists

| Problem | This POC solves it |
|---|---|
| GitHub Codespaces blocked by enterprise IP allow-list | VS Code Remote SSH connects to an Azure VM inside the VNET |
| Microsoft Dev Box discontinued (Nov 2025) | Standard Azure VM + VS Code SSH = same experience |
| GitHub-hosted larger runners disabled by security policy | Self-hosted runner (`wdc-ubuntu-latest`) runs inside the Azure VNET |

---

## Architecture

```
Developer (VS Code local)
    │ Remote SSH (VPN or public IP for POC)
    ▼
Azure VM (vscode-ssh-demo-vm, eastus2)
    │ edit · GitHub Copilot · commit
    │ git push remote-build/<user>/<timestamp>
    ▼
GitHub (skywalker2077/remote-dev-runner-poc)
    │ GitHub Actions trigger
    ▼
Runner (ubuntu-latest for POC / wdc-ubuntu-latest for WDC production)
    │ build · test · package · scan
    ▼
Artifacts + Logs + PR Checks in GitHub Actions
```

---

## Quick Start

### 1. Provision the Azure VM
```bash
az login
bash scripts/create-azure-vm.sh
```

### 2. Bootstrap the VM
```bash
ssh -i ~/.ssh/remote_dev_id_rsa devuser@<PUBLIC_IP> 'bash -s' < scripts/setup-dev-vm.sh
```

### 3. Configure VS Code SSH
```bash
sed 's/<AZURE_VM_PUBLIC_IP>/<YOUR_IP>/' config/ssh-config.template >> ~/.ssh/config
```

Open VS Code → `Remote-SSH: Connect to Host` → `remote-dev-runner`

### 4. Trigger a remote build
In VS Code: `Tasks: Run Task` → `Remote Build: Full`

---

## WDC Production Mapping

| POC (this repo) | WDC Production |
|---|---|
| `ubuntu-latest` | `wdc-ubuntu-latest` |
| Azure VM public IP + port 22 | Azure VM private IP + VPN/Bastion |
| `skywalker2077` GitHub account | `WDC-TEST-PLAYORG` GitHub org |
| Personal Azure subscription | WDC Azure subscription |
| SSH key in `~/.ssh` | SSH key in Azure Key Vault |

---

## Previous Demo

See [copilot-devbox-demo](https://github.com/skywalker2077/copilot-devbox-demo) for the Dev Box + GitHub Copilot POC presented at the Avanade Americas DevOps Birds of a Feather call.
