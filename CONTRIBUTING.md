# Contributing

Thank you for your interest in contributing to the Azure Local AVD project. Contributions are welcome — especially around testing across different Azure Local versions, AVD configurations, and session host scenarios.

## Before You Start

- Read the [README](README.md) for an overview of the project
- This project deploys Azure Virtual Desktop infrastructure on Azure Local — **test all changes in a non-production environment**
- Check open issues and pull requests to avoid duplicate work

## How to Contribute

### Reporting Bugs

Use the [bug report issue template](.github/ISSUE_TEMPLATE/bug_report.md). Include:
- Azure Local version (22H2, 23H2, etc.)
- AVD host pool and session host configuration
- Which script or template failed and at which step
- Full error message and relevant log output

### Suggesting Features

Use the [feature request issue template](.github/ISSUE_TEMPLATE/feature_request.md). Describe the use case, not just the solution.

### Documentation Issues

Use the [documentation issue template](.github/ISSUE_TEMPLATE/docs_issue.md) for missing, incorrect, or unclear docs.

### Submitting Pull Requests

1. Fork the repo and create a branch from `main`
2. Name branches using conventional types: `feat/session-host-scaling`, `fix/host-pool-config`, `docs/deployment-guide`
3. Keep changes focused — one logical change per PR
4. Update the README and relevant `docs/` pages if your change affects usage or prerequisites
5. Add an entry to [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]`
6. Test your changes against at least one real Azure Local environment before submitting
7. Fill out the pull request template completely

## Commit Messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `infra` | CI/CD, workflows, config |
| `chore` | Maintenance |
| `refactor` | Code improvement, no behavior change |
| `test` | Tests |

Examples:
- `feat(bicep): add session host auto-scaling`
- `fix(terraform): correct network security group rules`
- `docs(guides): add AVD deployment walkthrough`

## Development Guidelines

### PowerShell Style

- Use approved PowerShell verbs (`Get-`, `Set-`, `New-`, `Remove-`, etc.)
- Include `[CmdletBinding()]` and `param()` blocks on all scripts
- Use `Write-Verbose` for diagnostic output, `Write-Warning` for non-fatal issues, `Write-Error` for failures
- Guard destructive operations with `-WhatIf` / `-Confirm` where practical

### Infrastructure as Code

- Terraform, Bicep, and ARM templates should follow the conventions in `standards/`
- Use variables for all environment-specific values — no hardcoded IPs, names, or paths

### Testing

- Test against a real Azure Local environment before submitting
- Describe your test environment and results in the PR

## Standards

This project follows the **org-wide AzureLocal standards** documented at [azurelocal.cloud/standards](https://azurelocal.cloud/standards/). Key references:

- [Repository Structure](https://azurelocal.cloud/standards/repo-structure) — Required files, directories, labels, branch naming
- [Scripting Standards](https://azurelocal.cloud/standards/scripting/scripting-standards) — PowerShell conventions
- [Solution Development](https://azurelocal.cloud/standards/solutions/solution-development-standard) — IaC conventions
- [Documentation Standards](https://azurelocal.cloud/standards/documentation/documentation-standards) — Writing and formatting
- [Variable Management](https://azurelocal.cloud/docs/implementation/04-variable-management-standard) — Config file patterns
- [Fictional Company Policy](https://azurelocal.cloud/standards/fictional-company-policy) — Use IIC, never Contoso

## Code of Conduct

Be respectful and constructive. Keep discussions on-topic and collaborative.
