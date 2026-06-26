# VS Code Remote SSH + Self-Hosted Runner — POC Implementation
## Claude Code Prompt | repo: skywalker2077/remote-dev-runner-poc

---

## Context

This is a **personal POC** built in Walker's personal GitHub account (`skywalker2077`) to demonstrate the **VS Code Remote SSH + Self-Hosted Runner** approach as an alternative to GitHub Codespaces (blocked at WDC) and Microsoft Dev Box (discontinued November 2025).

The same repo was previously used for the **Dev Box + Copilot POC** presented at the Avanade Americas DevOps Birds of a Feather call (~200 attendees).

This POC will be used to:
1. Validate the architecture before proposing it to WDC
2. Demo the full developer flow to Karsten Strecke (WDC DevOps Lead) and Chris Norotsky (PM)
3. Serve as reference implementation for the WDC Wave 2 rollout

**Target repo:** `github.com/skywalker2077/remote-dev-runner-poc`  
**GitHub handle:** `skywalker2077`  
**Runner:** GitHub-hosted `ubuntu-latest` for POC (WDC production will use `wdc-ubuntu-latest` self-hosted)  
**Azure:** Personal Azure subscription (same used for `ghes-demo-vm` in RG `devbboxdemo`, eastus2)

---

## What to Implement

### 1. Azure VM Bootstrap Script (`scripts/setup-dev-vm.sh`)

Create a shell script that provisions an Ubuntu 22.04 Azure VM as the developer environment. It must:

- Install required tools:
  - `git`, `curl`, `wget`, `unzip`, `jq`
  - `openssh-server` (enabled and started)
  - `gh` CLI (GitHub CLI, latest version)
  - `docker` (Docker Engine)
  - Node.js LTS via `nvm`
  - Python 3 + `pip`
  - Azure CLI (`az`)
- Configure SSH:
  - Enable `sshd` on boot
  - Set `AllowTcpForwarding yes` and `GatewayPorts yes` in `/etc/ssh/sshd_config`
  - Restart `sshd`
- Create a `devuser` user with sudo access
- Add SSH public key to `~/.ssh/authorized_keys`
- Clone `skywalker2077/remote-dev-runner-poc` into `/home/devuser/workspace/`
- Print connection instructions at the end

Also create a companion Azure CLI script (`scripts/create-azure-vm.sh`) that provisions the VM:
- Resource Group: `devbboxdemo` (existing, eastus2)
- VM size: `Standard_B2s` (2 vCPU, 4GB RAM — cost-effective for POC)
- Image: `Ubuntu2204`
- VM name: `vscode-ssh-demo-vm`
- Open port 22 via NSG
- Run `setup-dev-vm.sh` as custom script extension after provisioning

---

### 2. VS Code SSH Config Template (`config/ssh-config.template`)

Generate a template for `~/.ssh/config`:

```
Host vscode-ssh-demo
  HostName <AZURE_VM_PUBLIC_IP>
  User devuser
  IdentityFile ~/.ssh/vscode_demo_id_rsa
  ForwardAgent yes
  ServerAliveInterval 60
  ServerAliveCountMax 10
```

Also create `.vscode/settings.json` with recommended remote SSH settings:
```json
{
  "remote.SSH.defaultExtensions": [
    "github.copilot",
    "github.copilot-chat",
    "ms-python.python",
    "eamodio.gitlens",
    "ms-azuretools.vscode-docker"
  ],
  "remote.SSH.connectTimeout": 60,
  "git.autofetch": true,
  "terminal.integrated.defaultProfile.linux": "bash"
}
```

---

### 3. GitHub Actions Workflow — Remote Build (`workflows/remote-build.yml`)

Create `.github/workflows/remote-build.yml`:

```yaml
name: Remote Build

on:
  workflow_dispatch:
    inputs:
      build_type:
        description: 'Build type'
        required: true
        default: 'full'
        type: choice
        options:
          - full
          - test-only
          - package-only
  push:
    branches:
      - 'remote-build/**'
```

Requirements:
- Use `runs-on: ubuntu-latest` for POC (production WDC will use `wdc-ubuntu-latest`)
- Jobs:
  1. **setup** — checkout, print runner info, set environment variables
  2. **build** — `npm install && npm run build` (or `make build` if Makefile present)
  3. **test** — run test suite, publish JUnit XML results
  4. **package** — create `.tar.gz` artifact
  5. **summary** — post build summary as job summary (`$GITHUB_STEP_SUMMARY`)
- Upload artifacts with `actions/upload-artifact@v4` (retention: 7 days)
- Post PR status check via `actions/github-script`
- Add a clear comment to every step: `# NOTE: In WDC production, replace ubuntu-latest with wdc-ubuntu-latest`

---

### 4. Branch Cleanup Workflow (`workflows/cleanup-remote-build-branches.yml`)

Create a scheduled workflow:
- Runs daily at `02:00 UTC`
- Lists all branches matching `remote-build/**`
- Deletes branches older than 7 days
- Uses `gh` CLI with `${{ secrets.GITHUB_TOKEN }}`
- Uses `runs-on: ubuntu-latest`

---

### 5. VS Code Tasks (`.vscode/tasks.json`)

Create tasks so the developer can trigger remote builds from VS Code Command Palette:

- **Remote Build: Full** — push to `remote-build/<username>/<timestamp>`, trigger workflow, open Actions URL
- **Remote Build: Test Only** — same flow with `build_type: test-only`
- **Remote Build: Package** — same flow with `build_type: package-only`
- **Open GitHub Actions** — open the last Actions run URL in browser

Each task must:
- Use `gh workflow run` to trigger the workflow
- Use `gh run watch` to stream logs in the VS Code terminal
- Print the Actions URL at the end

---

### 6. Sample App (`src/`)

Create a minimal Node.js app to make the POC demonstrable end-to-end:

- `src/index.js` — simple Express server with `/health` and `/version` endpoints
- `src/index.test.js` — Jest tests for both endpoints
- `package.json` — with scripts: `start`, `build`, `test`
- `Dockerfile` — multi-stage build (node:18-alpine)
- `.nvmrc` — Node.js version pin

This gives the remote build something real to build, test, and package.

---

### 7. Developer Setup Guide (`docs/DEVELOPER_SETUP.md`)

Create a step-by-step guide covering:

1. **Prerequisites** — VS Code, Remote SSH extension, Azure CLI, SSH key generation
2. **Provision the Azure VM** — run `scripts/create-azure-vm.sh`
3. **Configure VS Code SSH** — copy `config/ssh-config.template` to `~/.ssh/config`, fill in VM IP
4. **Connect** — `Remote-SSH: Connect to Host` → `vscode-ssh-demo`
5. **Edit & commit** — normal VS Code flow on the remote VM
6. **Trigger a remote build** — `Tasks: Run Task` → `Remote Build: Full`
7. **Read results** — GitHub Actions logs, artifacts, PR checks
8. **WDC production mapping** — table showing how each POC component maps to WDC production

Include a **WDC Production Mapping** table:

| POC (personal) | WDC Production |
|---|---|
| `ubuntu-latest` | `wdc-ubuntu-latest` |
| Azure VM public IP + port 22 | Azure VM private IP + VPN/Bastion |
| Personal GitHub repo | `WDC-TEST-PLAYORG` GitHub org |
| Personal Azure subscription | WDC Azure subscription (Moin/Srini) |
| SSH key in `~/.ssh` | SSH key managed via Azure Key Vault |

---

### 8. README (`README.md`)

Update the repo README to cover both demos:

- **Demo 1 (previous):** Dev Box + Copilot POC (Avanade BoF) — `copilot-devbox-demo`
- **Demo 2 (this):** VS Code Remote SSH + Self-Hosted Runner POC (WDC alternative architecture) — `remote-dev-runner-poc`

Add architecture diagram in ASCII or Mermaid:

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

---

## File Structure to Generate

```
remote-dev-runner-poc/
├── .github/
│   └── workflows/
│       ├── remote-build.yml
│       └── cleanup-remote-build-branches.yml
├── .vscode/
│   ├── tasks.json
│   └── settings.json
├── config/
│   └── ssh-config.template
├── scripts/
│   ├── create-azure-vm.sh
│   └── setup-dev-vm.sh
├── src/
│   ├── index.js
│   ├── index.test.js
│   └── Dockerfile
├── docs/
│   └── DEVELOPER_SETUP.md
├── .nvmrc
├── package.json
└── README.md
```

---

## Success Criteria

- [ ] Running `scripts/create-azure-vm.sh` provisions a ready-to-use Azure VM in under 5 minutes
- [ ] Developer connects via VS Code Remote SSH in under 2 minutes
- [ ] Running `Remote Build: Full` task triggers a GitHub Actions run
- [ ] Build + test + package completes successfully on the runner
- [ ] Artifacts are downloadable from GitHub Actions
- [ ] Remote build branches are auto-deleted after 7 days
- [ ] `docs/DEVELOPER_SETUP.md` is clear enough for a WDC developer to follow independently
- [ ] README clearly explains both POC demos and the WDC production mapping

---

## Notes for Claude Code

- Commit all files with descriptive commit messages
- Use `gh` CLI where possible instead of raw API calls
- Keep scripts idempotent (safe to run multiple times)
- Add `set -euo pipefail` to all shell scripts
- Use `.env.example` for any environment variables — never commit real values
- Target audience for docs: mid-level DevOps engineer at WDC who knows Git but may not know GitHub Actions
