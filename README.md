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

## POC Environment (2026-06-26)

| Resource | Value |
|---|---|
| VM name | `vscode-ssh-demo-vm` |
| Public IP | `20.122.73.183` |
| Resource Group | `devbboxdemo` (eastus2) |
| VM size | Standard_B2s (2 vCPU, 4 GB RAM) |
| SSH user | `devuser` |
| SSH key | `~/.ssh/remote_dev_id_rsa` (ed25519) |
| Workspace on VM | `~/workspace/remote-dev-runner-poc` |

> The public IP is ephemeral. If the VM is deallocated and restarted, update `~/.ssh/config` with the new IP.

---

## Quick Start

### 1. Generate SSH key
```bash
ssh-keygen -t ed25519 -f ~/.ssh/remote_dev_id_rsa -C "remote-dev-runner-poc"
```

### 2. Provision the Azure VM
```bash
az login
bash scripts/create-azure-vm.sh
```

### 3. Bootstrap the VM
```bash
ssh -i ~/.ssh/remote_dev_id_rsa devuser@<PUBLIC_IP> 'bash -s' < scripts/setup-dev-vm.sh
```

> **Known issue:** `gh repo clone` inside `setup-dev-vm.sh` requires the VM to be `gh auth login`-ed.  
> The script falls back gracefully; clone manually after first login:  
> `git clone https://github.com/skywalker2077/remote-dev-runner-poc.git ~/workspace/remote-dev-runner-poc`

### 4. Configure VS Code SSH
```bash
sed 's/<AZURE_VM_PUBLIC_IP>/20.122.73.183/' config/ssh-config.template >> ~/.ssh/config
```

Open VS Code → `Remote-SSH: Connect to Host` → `remote-dev-runner`

### 5. Trigger a remote build
In VS Code: `Tasks: Run Task` → `Remote Build: Full`

---

## Validated Flow (2026-06-26)

Full end-to-end test run: [actions/runs/28242614219](https://github.com/skywalker2077/remote-dev-runner-poc/actions/runs/28242614219)

| Job | Result | Duration |
|---|---|---|
| Setup | ✅ pass | 4s |
| Build | ✅ pass | 14s |
| Test | ✅ pass | 12s |
| Package | ✅ pass | 12s |
| Summary | ✅ pass | 5s |

**Total: ~1 minute** from `gh workflow run` to all artifacts available.

### Tool versions confirmed on VM

| Tool | Version |
|---|---|
| Node.js | v24.18.0 (nvm, LTS iron) |
| npm | v11.16.0 |
| Docker | v29.6.1 |
| gh CLI | v2.95.0 |
| git | v2.34.1 |

### Test results

```
PASS src/index.test.js
  GET /health    ✓ returns status ok
  GET /version   ✓ returns version info

Tests: 2 passed | Coverage: 83.33%
```

### Findings & known issues

| # | Finding | Severity | Fix |
|---|---|---|---|
| 1 | `nvm use --lts` fails in non-interactive `bash -s` sessions due to `set -u` + unbound `PROVIDED_VERSION` | Low | Removed `set -u` from nvm block; use `nvm install --lts` only |
| 2 | `gh repo clone` in `setup-dev-vm.sh` requires prior `gh auth login` on the VM | Low | Use `git clone https://...` for initial clone; `gh auth login` on first interactive session |
| 3 | `actions/checkout@v4`, `setup-node@v4`, `upload-artifact@v4` emit Node.js 20 deprecation warning | Info | Non-blocking for POC; upgrade to `@v5` before WDC production handoff |
| 4 | Public IP changes on VM deallocation | Low | Document; use Azure Bastion or static IP in production |

---

## WDC Production Mapping

| POC (this repo) | WDC Production |
|---|---|
| `ubuntu-latest` | `wdc-ubuntu-latest` |
| Azure VM public IP + port 22 | Azure VM private IP + VPN/Bastion |
| `skywalker2077` GitHub account | `WDC-TEST-PLAYORG` GitHub org |
| Personal Azure subscription | WDC Azure subscription (Moin/Srini) |
| SSH key in `~/.ssh` | SSH key in Azure Key Vault |
| `devuser` local sudo | Entra ID managed identity |

To switch from POC to WDC production: search for `# NOTE:` comments in both workflow files — each marks an `ubuntu-latest` that should become `wdc-ubuntu-latest`.

---

## Previous Demo

See [copilot-devbox-demo](https://github.com/skywalker2077/copilot-devbox-demo) for the Dev Box + GitHub Copilot POC presented at the Avanade Americas DevOps Birds of a Feather call (~200 attendees).
