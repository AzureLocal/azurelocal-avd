# Scripting Standards

> **Canonical reference:** [Scripting Standards (full)](https://azurelocal.cloud/standards/scripting/scripting-standards)  
> **Applies to:** All AzureLocal repositories  
> **Last Updated:** 2026-03-17

---

## Script Naming

| Script Type | Pattern | Example |
|-------------|---------|---------|
| PowerShell Core | `Verb-Noun.ps1` | `Deploy-Solution.ps1` |
| Azure PowerShell | `Verb-AzResource.ps1` | `New-AzKeyVault.ps1` |
| Azure CLI (PowerShell) | `az-verb-resource.ps1` | `az-deploy-resource.ps1` |
| Azure CLI (Bash) | `az-verb-resource.sh` | `az-deploy-resource.sh` |
| Standalone (no config) | `Verb-Noun-Standalone.ps1` | `Deploy-Solution-Standalone.ps1` |
| Remote/orchestration | `Invoke-<Task>.ps1` | `Invoke-Deployment.ps1` |

---

## Config-Driven vs Standalone

| Mode | Config File | Dependencies | Use Case |
|------|-------------|-------------|----------|
| Config-driven (Options 2-4) | `config/variables.yml` | Config loader, helpers, Key Vault | Multi-environment automation, CI/CD |
| Standalone (Option 5) | Inline `#region CONFIGURATION` | None | Demos, single-use, external sharing |

### Config-Driven Rules

- Read all values from `config/variables.yml` — never hardcode
- Accept `-ConfigPath` parameter (auto-discover if not provided)
- Use helper functions: `ConvertFrom-Yaml`, `Resolve-KeyVaultRef`, logging

### Standalone Rules

- All variables in `#region CONFIGURATION` block at top
- Variable names match `variables.yml` paths (e.g., `$subscription_id`)
- Zero external dependencies — copy, paste, run

---

## `Invoke-` Script Requirements

### Required Parameters

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `-ConfigPath` | `[string]` | `""` | Path to `variables.yml` |
| `-Credential` | `[PSCredential]` | `$null` | Override credential resolution |
| `-TargetNode` | `[string[]]` | `@()` (all) | Limit to specific node(s) |
| `-WhatIf` | `[switch]` | `$false` | Dry-run mode |
| `-LogPath` | `[string]` | `""` (auto) | Override log file path |

All `Invoke-` scripts must use `[CmdletBinding()]` to enable `-Verbose` and `-Debug`.

### Credential Resolution Order

1. **`-Credential` parameter** — if passed, use immediately
2. **Key Vault** — read from config; try `Az.KeyVault`, fall back to `az` CLI
3. **Interactive prompt** — `Get-Credential` with username pre-filled

---

## Logging

- Log to `./logs/<task-name>/<timestamp>.log`
- Use `Write-Verbose` for detailed output
- Log format: `[YYYY-MM-DD HH:MM:SS] [LEVEL] Message`

---

## Solution Script Conventions

| Convention | Rule |
|-----------|------|
| IaC tools | Terraform, Bicep, ARM, PowerShell, Ansible |
| Config source | `config/variables.yml` (single source of truth) |
| Parameter derivation | All tool-specific param files derived from central config |
| Idempotency | All scripts must be safe to re-run |

---

## Related Standards

- [PowerShell Organization Standard](https://azurelocal.cloud/standards/scripting/powershell-organization-standard)
- [Scripting Framework](https://azurelocal.cloud/standards/scripting/scripting-framework)
- [Bash Scripting Standards](https://azurelocal.cloud/standards/scripting/bash-scripting-standards)
- [Automation Interoperability](automation.md)