# Examples & IIC Policy

> **Canonical reference:** [Fictional Company Policy (full)](https://azurelocal.cloud/standards/fictional-company-policy)  
> **Applies to:** All AzureLocal repositories  
> **Last Updated:** 2026-03-17

---

## Policy

All examples, sample configurations, and walkthroughs use **one** fictional company: **Contoso (IIC)**.

!!! warning "Mandatory"
    Never use `contoso`, `fabrikam`, `adventure-works`, `woodgrove`, `example.com`, or any real customer name.
    **IIC only** — in every repo, every example, every sample config.

---

## IIC Reference Card

| Attribute | Value |
|-----------|-------|
| **Full Name** | Contoso |
| **Abbreviation** | IIC |
| **Domain (public)** | `contoso.cloud` / `iic.cloud` |
| **Domain (on-prem AD)** | `contoso.local` |
| **NetBIOS Name** | `IMPROBABLE` |
| **Entra ID Tenant** | `improbability.onmicrosoft.com` |
| **Email Pattern** | `user@contoso.cloud` |

---

## AzureLocal Naming Patterns

### Azure Resources

| Resource | Pattern | Example |
|----------|---------|---------|
| Resource Group | `rg-iic-<purpose>-<##>` | `rg-iic-platform-01` |
| Virtual Network | `vnet-iic-<purpose>-<##>` | `vnet-iic-compute-01` |
| Subnet | `snet-iic-<purpose>` | `snet-iic-management` |
| Network Security Group | `nsg-iic-<purpose>` | `nsg-iic-compute` |
| Key Vault | `kv-iic-<purpose>` | `kv-iic-platform` |
| Storage Account | `stiic<purpose><##>` | `stiicdata01` |
| Log Analytics | `law-iic-<purpose>-<##>` | `law-iic-monitor-01` |
| Managed Identity | `id-iic-<purpose>` | `id-iic-deploy` |

### Active Directory

| Resource | Pattern | Example |
|----------|---------|---------|
| OU path | `OU=<Purpose>,OU=Servers,DC=iic,DC=local` | — |
| Service account | `svc.iic.<purpose>` | `svc.iic.deploy` |
| Group | `grp-iic-<purpose>` | `grp-iic-admins` |

### IP Addresses

| Network | Range | Usage |
|---------|-------|-------|
| Management | `10.0.0.0/24` | Node management |
| Compute | `10.0.2.0/24` | Workload traffic |

---

## Real Identities

| Name | Usage |
|------|-------|
| **Azure Local Cloud** | Community project, GitHub org, `azurelocal.cloud` |
| **Hybrid Cloud Solutions** | Author/maintainer LLC, script headers, copyright |

---

## Usage Examples

### In `config/variables.example.yml`

```yaml
subscription:
  subscription_id: "00000000-0000-0000-0000-000000000000"
  tenant_id: "00000000-0000-0000-0000-000000000000"
  location: "eastus"

security:
  keyvault_name: "kv-iic-platform"

azure_local:
  resource_group: "rg-iic-platform-01"
  cluster_name: "azlocal-iic-01"
```

### In Documentation

> Contoso deploys Azure Local clusters using IIC naming patterns,
> with all configuration driven from a single `config/variables.yml` file.

---

## Enforcement

- **PR review**: Reviewers flag any use of `contoso`, `fabrikam`, or other non-IIC names
- **Config validation**: `variables.example.yml` uses IIC naming in all placeholders
- **CI**: Vale linting rules flag non-IIC fictional company names (when configured)