# Solution Development Standards

> **Canonical reference:** [Solution Development Standard (full)](https://azurelocal.cloud/standards/solutions/solution-development-standard)  
> **Applies to:** All AzureLocal solution repositories  
> **Last Updated:** 2026-03-17

---

## IaC Tool Support

Each tool must declare which deployment phases it supports:

| Tool | Azure Resources | Configuration | Networking | Monitoring |
|------|:---:|:---:|:---:|:---:|
| **Terraform** | ✅ | Delegates | ✅ | ✅ |
| **Bicep** | ✅ | Delegates | ✅ | ✅ |
| **ARM** | ✅ | Delegates | ✅ | ✅ |
| **PowerShell** | ✅ | ✅ | ✅ | ✅ |
| **Ansible** | ✅ | ✅ | ✅ | ✅ |

!!! warning "Delegates"
    "Delegates" means the tool provisions Azure resources but does not configure the guest OS. A separate tool (PowerShell or Ansible) handles guest configuration.

---

## Parameter File Derivation

All tool-specific parameter files MUST be derivable from `config/variables.yml`:

| Tool | Parameter File | Derivation |
|------|---------------|------------|
| Terraform | `src/terraform/terraform.tfvars` | Map YAML sections to HCL variables |
| Bicep | `src/bicep/main.bicepparam` | Map YAML sections to Bicep parameters |
| ARM | `src/arm/azuredeploy.parameters.json` | Map YAML sections to ARM parameter schema |
| PowerShell | *(reads config directly)* | `ConvertFrom-Yaml` from config file |
| Ansible | `src/ansible/inventory/hosts.yml` | Map YAML sections to `group_vars` |

The central config is the **single source of truth**. Tool-specific files are convenience copies that should be regenerable.

---

## Conditional Resource Support

| Tool | Mechanism | Example |
|------|-----------|--------|
| **Terraform** | `count` / `for_each` | `count = var.enable_feature ? 1 : 0` |
| **Bicep** | `if` condition | `resource res '...' = if (enableFeature) { ... }` |
| **ARM** | `condition` property | `"condition": "[equals(parameters('enableFeature'), 'true')]"` |
| **PowerShell** | `switch` / `if` | `if ($config.feature_enabled) { ... }` |
| **Ansible** | `when:` clause | `when: enable_feature == true` |

All tools must produce **identical infrastructure** when given the same configuration values.

---

## Multi-Tool Parity

- Every supported tool must cover the same set of resources
- Tool-specific parameter files are derived from `config/variables.yml`
- CI tests validate that each tool's output matches the expected state
- New resources added to one tool must be added to all supported tools

---

## Related Standards

- [Infrastructure Standards](https://azurelocal.cloud/standards/infrastructure/)
- [Variable Reference](../reference/variables.md)
- [Scripting Standards](scripting.md)