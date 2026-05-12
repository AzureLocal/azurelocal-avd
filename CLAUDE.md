# azurelocal-avd — Claude Code Context

## What this repo is

![Azure Virtual Desktop on Azure Local](docs/assets/images/azurelocal-avd-banner.svg)

---

## ADO project details

- **ADO org:** https://dev.azure.com/hybridcloudsolutions
- **ADO project:** Azure Local
- **Area path:** Platform Engineering\Onboarding
- **Work item format:** `AB#<id>` in commit messages and PR descriptions

---

## Standards

This repo follows all HCS platform standards defined in the Platform Engineering repo:

| Standard | Reference |
|---|---|
| Governance | [docs/standards/governance.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/governance.md) |
| Scripting (PowerShell 7) | [docs/standards/scripting.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/scripting.md) |
| Automation | [docs/standards/automation.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/automation.md) |
| Variables and naming | [docs/standards/variables.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/variables.md) |
| Documentation | [docs/standards/documentation.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/documentation.md) |
| Claude Code | [docs/standards/claude-code.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/claude-code.md) |

Key rules:
- All scripts: PowerShell 7+ only. `#Requires -Version 7.0`, `Set-StrictMode -Version Latest`, ` $ErrorActionPreference = 'Stop'`.
- All docs: Markdown only. No Word documents in any repo.
- Commit format: `type(scope): short description` — types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`
- No secrets, tokens, or credentials committed to any file.

---

## Key facts

| Fact | Value |
|---|---|
| Primary language | Markdown / Python (MkDocs) |
| GitHub org | AzureLocal |
| Azure login | kris@hybridsolutions.cloud |
| Key Vault | kv-hcs-vault-01 |

### Environment variables expected

| Variable | Source | Purpose |
|---|---|---|
| `GITHUB_TOKEN` | kv-hcs-vault-01 via Load-HCSEnvironment.ps1 | GitHub CLI and git operations |
| `AZURE_DEVOPS_EXT_PAT` | kv-hcs-vault-01 via Load-HCSEnvironment.ps1 | ADO CLI (`az boards`, `az devops`) |
Load before starting a session:
```powershell
. E:\git\platform\scripts\Load-HCSEnvironment.ps1
```

### Build and test commands

```
mkdocs build
mkdocs serve  # http://127.0.0.1:8000
```

---

## Repo structure

```
azurelocal-avd/
├── .claude/
    └── settings.json
├── .github/
    ├── workflows/
    └── CODEOWNERS
├── config/
    ├── examples/
    ├── variables/
    └── README.md
├── docs/
    ├── architecture/
    ├── assets/
    ├── audit/
    ├── guides/
    └── operations/
├── examples/
    ├── pipelines/
    └── README.md
├── logs/
    └── .gitkeep
├── repo-management/
    ├── scripts/
    ├── automation.md
    ├── canonical-variable-migration.md
    ├── README.md
    └── setup.md
├── scripts/
    ├── deploy-avd-control-plane.sh
    ├── deploy-session-hosts.sh
    ├── parameters.example.env
    ├── README.md
    └── validate-config.py
├── src/
    ├── ansible/
    ├── arm/
    ├── bicep/
    ├── powershell/
    └── terraform/
├── styles/
    └── Microsoft/
├── tests/
    ├── powershell/
    ├── schemas/
    ├── README.md
    ├── Test-AVDDeployment.Tests.ps1
    └── validate-config-schema.py
├── .azurelocal-platform.yml
├── .gitignore
├── .release-please-manifest.json
├── .vale.ini
├── azurelocal-avd.code-workspace
├── CHANGELOG.md
├── CLAUDE.md
└── ...
```

---

## Claude Code actions

**Run autonomously:**
- Read, search, and grep any file in this repo
- Write and edit files in this repo
- `git add`, `git commit`, `git push`
- `gh issue`, `gh pr`, `gh run` CLI commands
- `mkdocs build` and `mkdocs serve`
- `pip install` for MkDocs plugins

**Always confirm before:**
- Creating or deleting Azure resources
- Any `az` CLI write operation that modifies Azure state
- Running destructive operations
- Making API calls to external services


---

## Subagents available in this repo

- `azurelocal-avd-engineer` (model: sonnet) — Expert in `azurelocal-avd`: deep knowledge of this repo's structure, conventions, and development workflow.

User-level agents (available in every repo session): `triage-lookup`, `markdown-prose-editor`, `azurelocal-domain-expert`, `mkdocs-material-doctor`, `turner-module-scaffold-engineer`, `mms-2026-demo-presenter`.

---

## Owner

**Kristopher Turner**
kris@hybridsolutions.cloud
Senior Product Technology Architect, TierPoint | Microsoft MVP (Azure) | MCT
Owner, Hybrid Cloud Solutions LLC — hybridsolutions.cloud
Country Cloud Boy — thisismydemo.cloud