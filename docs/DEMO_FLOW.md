# Demo Flow — VS Code Remote SSH + Self-Hosted Runner
## Audience: Karsten Strecke (WDC DevOps Lead) · Chris Norotsky (PM)
## Duration: ~12 minutes

---

## Before the Demo (prep — do not skip)

Run these checks **at least 10 minutes before** the call:

```bash
# 1. VM is running
az vm show -g devbboxdemo -n vscode-ssh-demo-vm \
  --show-details --query powerState -o tsv
# Expected: VM running

# 2. SSH works
ssh -i ~/.ssh/remote_dev_id_rsa devuser@20.122.73.183 'echo "SSH OK && node --version"'
# Expected: SSH OK  v24.18.0

# 3. gh CLI authenticated locally
gh auth status
# Expected: Logged in to github.com as skywalker2077

# 4. Repo is clean
cd ~/workspace/remote-dev-runner-poc   # or C:\VS\remote-dev-runner-poc
git status
# Expected: nothing to commit
```

If VM is deallocated:
```bash
az vm start -g devbboxdemo -n vscode-ssh-demo-vm
# Wait ~60s, then get the new IP:
az vm show -g devbboxdemo -n vscode-ssh-demo-vm \
  --show-details --query publicIps -o tsv
# Update ~/.ssh/config with the new IP
```

Open VS Code **already connected** to `remote-dev-runner` via Remote SSH before the call starts.

---

## Scene 0 — Context (1 min)

> **Say:** "Quick context before we start. WDC lost two cloud dev environment options:
> Codespaces is blocked by the enterprise IP allow-list, and Dev Box was discontinued in November.
> What I'm going to show you today is the replacement architecture we validated this week:
> VS Code Remote SSH into an Azure VM, combined with GitHub Actions for CI.
> The whole thing is running live right now — I'm not going to use slides."

---

## Scene 1 — "I'm already connected" (1 min)

**Window:** VS Code, bottom-left corner shows `SSH: remote-dev-runner`

> **Say:** "I'm already connected to an Azure VM via VS Code Remote SSH.
> This VM is a Standard_B2s running Ubuntu 22.04 in eastus2 — same region as WDC.
> From my perspective it looks exactly like a local project."

Click the **Source Control** sidebar. Show the repo `remote-dev-runner-poc` checked out at `~/workspace/`.

Open the integrated terminal (`Ctrl+` `` ` ``):

```bash
# Show where we are
pwd
# /home/devuser/workspace/remote-dev-runner-poc

# Show the tools available
node --version && docker --version && gh --version | head -1
# v24.18.0
# Docker version 29.6.1
# gh version 2.95.0
```

> **Say:** "Node, Docker, GitHub CLI — all installed. This is what a developer gets on day one,
> provisioned by a single script in under 5 minutes."

---

## Scene 2 — Make a real code change (2 min)

Open `src/index.js` in the editor (VS Code file explorer → `src/index.js`).

Add a new endpoint **live** — type it, don't paste:

```javascript
app.get('/demo', (req, res) => {
  res.json({ message: 'WDC Remote Dev Runner POC', date: new Date().toISOString() });
});
```

> **Say:** "I just added an endpoint directly on the VM. Copilot would be suggesting completions here
> in a real session — it works transparently over the SSH tunnel."

Save the file. Show the Git diff in the Source Control sidebar.

In the terminal:

```bash
git add src/index.js
git commit -m "demo: add /demo endpoint for live walkthrough"
```

---

## Scene 3 — Trigger the remote build (1 min)

> **Say:** "Now watch what happens when I push. Instead of pushing to main,
> I push to a special branch pattern that triggers GitHub Actions automatically."

```bash
BRANCH="remote-build/walker/$(date +%Y%m%d-%H%M%S)"
git push origin HEAD:"$BRANCH"
```

Expected output:
```
To https://github.com/skywalker2077/remote-dev-runner-poc.git
 * [new branch]      HEAD -> remote-build/walker/20260626-143201
```

```bash
sleep 3
gh run list --workflow=remote-build.yml --branch="$BRANCH" --limit=1
```

> **Say:** "GitHub Actions picked it up immediately. Let's watch it live."

---

## Scene 4 — Watch the build (3 min)

```bash
gh run watch --exit-status
```

Leave this running. While it streams, narrate each job:

| Job | Say |
|-----|-----|
| **Setup** ✓ | "Runner is a GitHub-hosted ubuntu-latest for the POC. In WDC production this becomes `wdc-ubuntu-latest` — a self-hosted runner inside your Azure VNET. One line change in the workflow." |
| **Build** ✓ | "npm install, build step. No pipeline YAML expertise needed — the developer just pushes a branch." |
| **Test** ✓ | "Jest runs, JUnit results uploaded as artifact. Same results you'd get running `npm test` locally." |
| **Package** ✓ | "tar.gz artifact created and published. Retention: 7 days. Downloadable from GitHub Actions." |
| **Summary** ✓ | "Job summary posted — build/test/package status in one table." |

When complete:

```
✓ main Remote Build · completed in ~1 minute
```

> **Say:** "One minute from push to packaged artifact. That's the developer loop."

---

## Scene 5 — Show the artifacts (1 min)

Open the Actions run in browser:

```bash
gh run view --web
```

Point out in the browser:
1. **Summary tab** — the markdown table posted by the Summary job
2. **Artifacts section** — `app-package-<sha>` and `test-results` available for download
3. **Job logs** — Build, Test, Package — each expandable step

> **Say:** "Karsten — this is what your team would see in `WDC-TEST-PLAYORG`.
> The artifact is the deployable package. The JUnit XML can feed into whatever test dashboard you use."

---

## Scene 6 — Branch auto-cleanup (30 sec)

> **Say:** "One thing that matters at scale: we don't want hundreds of `remote-build/` branches piling up.
> There's a scheduled workflow — runs every night at 2 AM UTC — that deletes any of these branches older than 7 days."

```bash
gh workflow list
# Shows: cleanup-remote-build-branches  active  scheduled
```

---

## Scene 7 — WDC Production delta (2 min)

> **Say:** "Let me show you exactly what changes between this POC and WDC production."

Share screen on the README or show this table live:

| POC (today) | WDC Production | Effort |
|---|---|---|
| `ubuntu-latest` | `wdc-ubuntu-latest` | 2-line change in workflow YAML |
| Azure VM public IP + port 22 | Private IP + WDC VPN / Bastion | VM provisioning flag |
| Personal GitHub repo | `WDC-TEST-PLAYORG` org | Repo transfer |
| Personal Azure sub | WDC subscription (Moin/Srini) | RG name change in `create-azure-vm.sh` |
| SSH key in `~/.ssh` | SSH key in Azure Key Vault | Key Vault integration |

> **Say to Karsten:** "Every `# NOTE:` comment in the workflow files marks exactly where `ubuntu-latest`
> becomes `wdc-ubuntu-latest`. That's the only runner change. Everything else is infrastructure config."

> **Say to Chris:** "From the developer's perspective, nothing changes. They open VS Code,
> connect to the remote host, edit, commit, run the task. That's it."

---

## Scene 8 — Close (30 sec)

> **Say:** "So what we validated this week:
> VM provisioned in 5 minutes. SSH connected in under 2. Build + test + package in 1 minute.
> The architecture works end-to-end. The WDC delta is two lines of YAML and a VPN config.
> Questions?"

**Repo link to share in chat:**
```
https://github.com/skywalker2077/remote-dev-runner-poc
```

---

## Fallback: if something breaks live

| Problem | Recovery |
|---|---|
| SSH disconnects | Reconnect: VS Code → `Remote-SSH: Connect to Host` → `remote-dev-runner` (< 30s) |
| VM unreachable | `az vm start -g devbboxdemo -n vscode-ssh-demo-vm` (60s), get new IP, update config |
| Workflow doesn't trigger | Trigger manually: `gh workflow run remote-build.yml --field build_type=full` |
| `gh run watch` hangs | Open browser: `gh run view --web`, narrate from the UI |
| Test fails due to syntax error | `git stash`, re-push, explain "this is what CI catching a bug looks like" |

---

## Key Numbers to Have Ready

| Metric | Value |
|---|---|
| VM provision time | ~4 min (first time) |
| SSH connect time | < 30s |
| Full build time | ~1 min |
| VM cost (Standard_B2s) | ~$30/month, ~$0.04/hour |
| Branch cleanup lag | Max 7 days |
| Artifact retention | 7 days |
