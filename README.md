# azurelocal-avd

![Azure Virtual Desktop on Azure Local](docs/assets/images/azurelocal-avd-banner.svg)

[![Azure Local](https://img.shields.io/badge/Azure%20Local-azurelocal.cloud-0078D4?logo=microsoft-azure)](https://azurelocal.cloud)

Documentation: [azurelocal.cloud](https://azurelocal.cloud) | Solutions: [Azure Local Solutions](https://azurelocal.cloud)

Infrastructure-as-code and automation for deploying **Azure Virtual Desktop (AVD)** on **Azure Local** (formerly Azure Stack HCI).

---

## Repository Structure

```
azurelocal-avd/
├── config/                  # Central variable reference (variables.example.yml)
├── src/                     # IaC templates — one folder per tool
│   ├── bicep/               #   Bicep (recommended)
│   ├── arm/                 #   ARM JSON
│   ├── terraform/           #   Terraform
│   ├── powershell/          #   PowerShell scripts
│   └── ansible/             #   Ansible playbooks and roles
├── scripts/                 # Azure CLI / Bash utility scripts
├── examples/                # Pipeline examples and walkthroughs
│   └── pipelines/
│       ├── azure-devops/
│       └── github-actions/
├── tests/                   # Validation scripts
├── docs/                    # Documentation (MkDocs source)
└── .github/workflows/       # GitHub Actions workflows
```

---

## Quick Start

```bash
git clone https://github.com/AzureLocal/aurelocal-avd.git
cd aurelocal-avd
cp config/variables.example.yml config/variables.yml
# Edit config/variables.yml, then deploy with your preferred tool
```

See [Getting Started](./docs/getting-started.md) for full instructions.

---

## Tool Options

| Tool | Location | Best For |
|------|----------|----------|
| Bicep | [`src/bicep/`](./src/bicep/) | Recommended — native ARM, type-safe |
| ARM | [`src/arm/`](./src/arm/) | Direct ARM JSON templates |
| Terraform | [`src/terraform/`](./src/terraform/) | Multi-cloud / existing TF estate |
| PowerShell | [`src/powershell/`](./src/powershell/) | Interactive / ad-hoc |
| Azure CLI | [`scripts/`](./scripts/) | Bash-based scripting |
| Ansible | [`src/ansible/`](./src/ansible/) | Post-deploy OS/app config |

---

## Documentation

- [Architecture Overview](./docs/architecture.md)
- [Deployment Scenarios](./docs/scenarios.md)
- [Getting Started](./docs/getting-started.md)
- [Variable Reference](./docs/reference/variables.md)
- [Contributing](./docs/contributing.md)

Companion repo: [azurelocal-sofs-fslogix](https://github.com/AzureLocal/azurelocal-sofs-fslogix)

---

## Prerequisites

- **Azure Local** cluster (23H2+) registered with Azure Arc
- Azure subscription with Contributor (or custom AVD) RBAC
- Microsoft Entra ID tenant
- See tool-specific version requirements in [Getting Started](./docs/getting-started.md)

---

## Contributing

See [Contributing Guide](./docs/contributing.md) for coding standards, branch strategy, and PR guidelines.

---

## License

See [LICENSE](./LICENSE) for details.
