# remote-dev-runner-poc — First Commit
## Claude Code Prompt | github.com/skywalker2077/remote-dev-runner-poc

---

## Your Mission

You are inside the repo `skywalker2077/remote-dev-runner-poc`, which was just initialized with only a `README.md` and `.gitignore`.

Implement the full **VS Code Remote SSH + Self-Hosted GitHub Actions Runner** POC from scratch, commit everything, and push to `main`.

---

## Step 0 — Verify repo state

```bash
git status
git log --oneline
ls -la
```

Confirm you are on `main`, the repo is clean, and only `README.md` and `.gitignore` exist.

---

## Step 1 — Create all files

Implement the following structure exactly:

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
├── .env.example
├── package.json
└── README.md   ← update existing file
```

---

## File Specifications

### `.github/workflows/remote-build.yml`

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

jobs:
  setup:
    name: Setup
    # NOTE: In WDC production, replace ubuntu-latest with wdc-ubuntu-latest
    runs-on: ubuntu-latest
    outputs:
      run_url: ${{ steps.run_url.outputs.url }}
    steps:
      - uses: actions/checkout@v4
      - name: Print runner info
        run: |
          echo "Runner: $RUNNER_NAME"
          echo "OS: $RUNNER_OS"
          echo "Build type: ${{ inputs.build_type }}"
          echo "Branch: $GITHUB_REF_NAME"
      - name: Set run URL
        id: run_url
        run: echo "url=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID" >> $GITHUB_OUTPUT

  build:
    name: Build
    needs: setup
    # NOTE: In WDC production, replace ubuntu-latest with wdc-ubuntu-latest
    runs-on: ubuntu-latest
    if: ${{ inputs.build_type == 'full' || inputs.build_type == '' }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: '.nvmrc'
          cache: 'npm'
      - run: npm ci
      - run: npm run build --if-present

  test:
    name: Test
    needs: build
    # NOTE: In WDC production, replace ubuntu-latest with wdc-ubuntu-latest
    runs-on: ubuntu-latest
    if: ${{ inputs.build_type == 'full' || inputs.build_type == 'test-only' || inputs.build_type == '' }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: '.nvmrc'
          cache: 'npm'
      - run: npm ci
      - run: npm test -- --ci --reporters=default --reporters=jest-junit
        env:
          JEST_JUNIT_OUTPUT_DIR: ./test-results
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: test-results/
          retention-days: 7

  package:
    name: Package
    needs: test
    # NOTE: In WDC production, replace ubuntu-latest with wdc-ubuntu-latest
    runs-on: ubuntu-latest
    if: ${{ inputs.build_type == 'full' || inputs.build_type == 'package-only' }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: '.nvmrc'
          cache: 'npm'
      - run: npm ci --omit=dev
      - name: Create artifact
        run: |
          tar -czf remote-dev-runner-poc-${{ github.sha }}.tar.gz \
            src/ package.json .nvmrc
      - uses: actions/upload-artifact@v4
        with:
          name: app-package-${{ github.sha }}
          path: remote-dev-runner-poc-*.tar.gz
          retention-days: 7

  summary:
    name: Summary
    needs: [build, test, package]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Post job summary
        run: |
          echo "## Remote Build Summary" >> $GITHUB_STEP_SUMMARY
          echo "| Step | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|---|---|" >> $GITHUB_STEP_SUMMARY
          echo "| Build | ${{ needs.build.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Test  | ${{ needs.test.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Package | ${{ needs.package.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "> **Runner note:** POC uses \`ubuntu-latest\`. WDC production uses \`wdc-ubuntu-latest\` (self-hosted, Azure VNET)." >> $GITHUB_STEP_SUMMARY
```

---

### `.github/workflows/cleanup-remote-build-branches.yml`

```yaml
name: Cleanup Remote Build Branches

on:
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:

jobs:
  cleanup:
    name: Delete remote-build branches older than 7 days
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - name: Delete old remote-build branches
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          CUTOFF=$(date -d '7 days ago' +%s)
          echo "Deleting remote-build/** branches older than 7 days..."
          gh api repos/${{ github.repository }}/branches \
            --paginate \
            --jq '.[] | select(.name | startswith("remote-build/")) | .name' | \
          while read branch; do
            LAST_COMMIT=$(gh api repos/${{ github.repository }}/commits \
              --field sha="$(gh api repos/${{ github.repository }}/branches/$branch --jq '.commit.sha')" \
              --jq '.[0].commit.committer.date' 2>/dev/null || echo "")
            if [ -z "$LAST_COMMIT" ]; then continue; fi
            COMMIT_TS=$(date -d "$LAST_COMMIT" +%s)
            if [ "$COMMIT_TS" -lt "$CUTOFF" ]; then
              echo "Deleting branch: $branch (last commit: $LAST_COMMIT)"
              gh api -X DELETE repos/${{ github.repository }}/git/refs/heads/$branch
            fi
          done
          echo "Cleanup complete."
```

---

### `.vscode/tasks.json`

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Remote Build: Full",
      "type": "shell",
      "command": "bash .vscode/scripts/remote-build.sh full",
      "group": "build",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "Remote Build: Test Only",
      "type": "shell",
      "command": "bash .vscode/scripts/remote-build.sh test-only",
      "group": "test",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "Remote Build: Package Only",
      "type": "shell",
      "command": "bash .vscode/scripts/remote-build.sh package-only",
      "group": "build",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "Open GitHub Actions",
      "type": "shell",
      "command": "gh run list --limit 1 --json url --jq '.[0].url' | xargs open || xargs xdg-open",
      "presentation": {
        "reveal": "silent"
      }
    }
  ]
}
```

Also create `.vscode/scripts/remote-build.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

BUILD_TYPE="${1:-full}"
GIT_USER=$(git config user.name | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
TIMESTAMP=$(date +%s)
BRANCH="remote-build/${GIT_USER}/${TIMESTAMP}"

echo "🚀 Triggering remote build..."
echo "   Branch: $BRANCH"
echo "   Type:   $BUILD_TYPE"

git push origin "HEAD:refs/heads/$BRANCH"

echo ""
echo "⏳ Waiting for GitHub Actions to pick up the run..."
sleep 3

RUN_URL=$(gh run list \
  --branch "$BRANCH" \
  --limit 1 \
  --json url \
  --jq '.[0].url' 2>/dev/null || echo "")

if [ -n "$RUN_URL" ]; then
  echo "✅ Run started: $RUN_URL"
  gh run watch --branch "$BRANCH" --exit-status
else
  echo "⚠️  Could not find run. Check: https://github.com/$GITHUB_REPOSITORY/actions"
fi
```

---

### `.vscode/settings.json`

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
  "terminal.integrated.defaultProfile.linux": "bash",
  "editor.formatOnSave": true
}
```

---

### `config/ssh-config.template`

```
# VS Code Remote SSH — remote-dev-runner-poc
# Copy this block to ~/.ssh/config and replace <AZURE_VM_PUBLIC_IP>

Host remote-dev-runner
  HostName <AZURE_VM_PUBLIC_IP>
  User devuser
  IdentityFile ~/.ssh/remote_dev_id_rsa
  ForwardAgent yes
  ServerAliveInterval 60
  ServerAliveCountMax 10

# Generate your SSH key pair with:
#   ssh-keygen -t ed25519 -f ~/.ssh/remote_dev_id_rsa -C "remote-dev-runner-poc"
# Then add the public key to the Azure VM during provisioning.
```

---

### `scripts/create-azure-vm.sh`

```bash
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

echo "🔧 Creating Azure VM: $VM_NAME"
echo "   Resource Group: $RG"
echo "   Location:       $LOCATION"
echo "   Size:           $VM_SIZE"

# Check SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "❌ SSH public key not found at $SSH_KEY_PATH"
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
echo "✅ VM created successfully!"
echo "   Public IP: $PUBLIC_IP"
echo ""
echo "Next steps:"
echo "  1. Run the bootstrap script on the VM:"
echo "     ssh -i ~/.ssh/remote_dev_id_rsa $ADMIN_USER@$PUBLIC_IP 'bash -s' < scripts/setup-dev-vm.sh"
echo ""
echo "  2. Update your SSH config:"
echo "     sed 's/<AZURE_VM_PUBLIC_IP>/$PUBLIC_IP/' config/ssh-config.template >> ~/.ssh/config"
echo ""
echo "  3. Connect in VS Code: Remote-SSH: Connect to Host → remote-dev-runner"
```

---

### `scripts/setup-dev-vm.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Setting up remote dev VM..."

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
echo "✅ Dev VM setup complete!"
echo "   Workspace: $HOME/workspace/remote-dev-runner-poc"
echo "   Node: $(node --version)"
echo "   gh: $(gh --version | head -1)"
echo "   Docker: $(docker --version)"
```

---

### `src/index.js`

```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.npm_package_version || '1.0.0';

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/version', (req, res) => {
  res.json({ version: VERSION, env: process.env.NODE_ENV || 'development' });
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`remote-dev-runner-poc listening on port ${PORT}`);
  });
}

module.exports = app;
```

---

### `src/index.test.js`

```javascript
const request = require('supertest');
const app = require('./index');

describe('GET /health', () => {
  it('returns status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toBeDefined();
  });
});

describe('GET /version', () => {
  it('returns version info', async () => {
    const res = await request(app).get('/version');
    expect(res.statusCode).toBe(200);
    expect(res.body.version).toBeDefined();
    expect(res.body.env).toBeDefined();
  });
});
```

---

### `src/Dockerfile`

```dockerfile
# Stage 1 — deps
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# Stage 2 — runtime
FROM node:18-alpine AS runtime
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY src/ ./src/
COPY package.json ./
EXPOSE 3000
USER node
CMD ["node", "src/index.js"]
```

---

### `package.json`

```json
{
  "name": "remote-dev-runner-poc",
  "version": "1.0.0",
  "description": "POC: VS Code Remote SSH + Self-Hosted GitHub Actions Runner",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "build": "echo 'Build step — add your build command here'",
    "test": "jest --coverage",
    "lint": "eslint src/"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "jest-junit": "^16.0.0",
    "supertest": "^6.3.4"
  },
  "jest": {
    "testEnvironment": "node",
    "coverageDirectory": "coverage",
    "collectCoverageFrom": ["src/**/*.js", "!src/**/*.test.js"]
  }
}
```

---

### `.nvmrc`

```
lts/iron
```

---

### `.env.example`

```
PORT=3000
NODE_ENV=development
```

---

### `README.md` (replace existing)

```markdown
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
```

---

### `docs/DEVELOPER_SETUP.md`

Write a full step-by-step guide (minimum 400 words) covering:

1. Prerequisites
2. Generate SSH key pair
3. Provision Azure VM (`create-azure-vm.sh`)
4. Bootstrap VM (`setup-dev-vm.sh`)
5. Configure VS Code SSH (`ssh-config.template`)
6. Connect via VS Code Remote SSH
7. Daily workflow (edit → commit → remote build)
8. Reading results in GitHub Actions
9. Troubleshooting (SSH timeout, runner offline, VPN not connected)
10. WDC Production Mapping table

---

## Step 2 — Install dependencies

```bash
npm install
```

---

## Step 3 — Commit everything

Use this exact commit sequence:

```bash
git add .github/ .vscode/ config/ scripts/ src/ docs/
git add .nvmrc .env.example package.json package-lock.json README.md
git commit -m "feat: initial implementation — VS Code Remote SSH + self-hosted runner POC

- GitHub Actions workflows: remote-build, cleanup-remote-build-branches
- VS Code tasks for one-click remote build trigger
- Azure VM provisioning scripts (create-azure-vm.sh, setup-dev-vm.sh)
- Sample Node.js app with Express + Jest for end-to-end demo
- SSH config template and VS Code remote settings
- Developer setup guide with WDC production mapping
- Dockerfile (multi-stage, node:18-alpine)

NOTE: POC uses ubuntu-latest runner.
WDC production target: wdc-ubuntu-latest (self-hosted, Azure VNET)
Repo: skywalker2077/remote-dev-runner-poc"

git push origin main
```

---

## Step 4 — Verify

After pushing, confirm:

```bash
# Check all files are in place
git ls-files

# Verify workflows are valid
gh workflow list

# Trigger a test run
gh workflow run remote-build.yml --field build_type=test-only

# Watch the run
gh run watch
```

---

## Done ✅

The repo is live at: `https://github.com/skywalker2077/remote-dev-runner-poc`
