# remote-dev-runner-poc

Personal POC repo for Walker's WDC architecture proposals, using the `skywalker2077` GitHub account.

---

## Demo 1 — Dev Box + Copilot POC *(previous)*

**Branch:** `copilot-devbox-demo`  
**Presented at:** Avanade Americas DevOps Birds of a Feather call (~200 attendees)  
**Topic:** Microsoft Dev Box + GitHub Copilot as a cloud developer environment

> Microsoft Dev Box was discontinued in November 2025. This demo is archived for reference.

---

## Demo 2 — VS Code Remote SSH + Self-Hosted Runner *(this)*

**Branch:** `main`  
**Audience:** Karsten Strecke (WDC DevOps Lead) · Chris Norotsky (PM)  
**Purpose:** Validate the VS Code Remote SSH + Self-Hosted Runner architecture as the WDC alternative to Codespaces (blocked) and Dev Box (discontinued)

### Architecture

```
Developer (VS Code local)
    │ Remote SSH
    ▼
Azure VM (vscode-ssh-demo-vm) ── edit · Copilot · commit
    │ git push remote-build/<user>/<ts>
    ▼
GitHub (skywalker2077/remote-dev-runner-poc)
    │ GitHub Actions trigger
    ▼
Runner (ubuntu-latest / wdc: wdc-ubuntu-latest)
    │ build · test · package
    ▼
Artifacts + Logs + PR Checks
```

### Key components

| File | Purpose |
|------|---------|
| `scripts/create-azure-vm.sh` | Provision Azure VM in one command |
| `scripts/setup-dev-vm.sh` | Bootstrap VM with all dev tools |
| `config/ssh-config.template` | VS Code SSH config template |
| `.vscode/settings.json` | Remote SSH extension settings |
| `.vscode/tasks.json` | One-click remote build tasks |
| `.github/workflows/remote-build.yml` | CI: build · test · package |
| `.github/workflows/cleanup-remote-build-branches.yml` | Daily branch cleanup |
| `src/` | Sample Node.js app (Express) |
| `docs/DEVELOPER_SETUP.md` | Step-by-step setup guide |

### Quick start

```bash
# 1. Provision the VM (requires az + gh login)
SSH_KEY_PATH=~/.ssh/vscode_demo_id_rsa ./scripts/create-azure-vm.sh

# 2. Add SSH config (fill in VM IP)
cat config/ssh-config.template >> ~/.ssh/config

# 3. Connect: VS Code → Remote-SSH: Connect to Host → vscode-ssh-demo

# 4. Trigger build: VS Code → Tasks: Run Task → Remote Build: Full
```

Full walkthrough: [`docs/DEVELOPER_SETUP.md`](docs/DEVELOPER_SETUP.md)

### WDC Production Mapping

| POC (personal) | WDC Production |
|---|---|
| `ubuntu-latest` | `wdc-ubuntu-latest` |
| Azure VM public IP + port 22 | Azure VM private IP + VPN/Bastion |
| Personal GitHub repo | `WDC-TEST-PLAYORG` GitHub org |
| Personal Azure subscription | WDC Azure subscription (Moin/Srini) |
| SSH key in `~/.ssh` | SSH key via Azure Key Vault |

---

*Built by Walker Gomes Viana · Avanade · 2026*
