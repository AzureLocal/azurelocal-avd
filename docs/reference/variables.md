# Variable Reference

All deployment tools read from a single central configuration file: `config/variables.yml`. This file is the **single source of truth** — your architecture decisions, sizing, identity settings, and infrastructure IDs are declared here and consumed by every automation tool.

!!! tip "Getting started"
    Copy the example and fill in your values:
    ```powershell
    cp config/variables.example.yml config/variables.yml
    ```
    **Never commit** `variables.yml` — it is excluded by `.gitignore` because it contains environment-specific values and Key Vault references.

---

## Naming Rules

| Scope | Convention | Example |
|-------|-----------|---------|
| Top-level sections | `snake_case` | `control_plane`, `session_hosts` |
| Keys within sections | `snake_case` | `subscription_id`, `vm_memory_mb` |
| Booleans | Descriptive name | `enable_entra_id_auth: true` |
| Secrets | `keyvault://` URI | `keyvault://kv-name/secret-name` |
| Example values | IIC fictional identity | `contoso.local`, `rg-iic-avd-hp-eus-01`, `kv-iic-platform` |

---

## Subscription & Global

```yaml
subscription:
  avd_subscription_id: "00000000-0000-0000-0000-000000000000"
  azure_local_subscription_id: "00000000-0000-0000-0000-000000000000"
  tenant_id: "00000000-0000-0000-0000-000000000000"
  location: "eastus"
```

| Variable | Type | Required | Description | Default |
|----------|------|:--------:|-------------|---------|
| `subscription.avd_subscription_id` | string | **Yes** | Azure subscription for AVD control plane and session hosts | — |
| `subscription.azure_local_subscription_id` | string | **Yes** | Azure subscription where the Azure Local cluster is registered | — |
| `subscription.tenant_id` | string | **Yes** | Entra ID tenant | — |
| `subscription.location` | string | **Yes** | Azure region | `eastus` |

---

## Security — Key Vault

```yaml
security:
  key_vault_name: "kv-iic-platform"
  key_vault_resource_group: "rg-iic-mgmt-eus-01"
```

| Variable | Type | Required | Description | Default |
|----------|------|:--------:|-------------|---------|
| `security.key_vault_name` | string | **Yes** | Platform Key Vault for all `keyvault://` URI resolution | — |
| `security.key_vault_resource_group` | string | **Yes** | Resource group containing the Key Vault | — |

---

## Control Plane

```yaml
control_plane:
  resource_group: "rg-iic-avd-hp-eus-01"
  host_pool_name: "hp-iic-avd-pool01"
  host_pool_type: "Pooled"
  load_balancer_type: "BreadthFirst"
  max_session_limit: 16
  preferred_app_group_type: "Desktop"
  personal_assignment_type: "Automatic"
  start_vm_on_connect: false
  validation_environment: false
  custom_rdp_properties: ""
  app_group_name: "vdag-iic-avd-eus-01"
  app_group_type: "Desktop"
  workspace_name: "vdws-iic-avd-eus-01"
```

| Variable | Type | Required | Description | Default |
|----------|------|:--------:|-------------|---------|
| `control_plane.resource_group` | string | **Yes** | Resource group for host pool, app group, workspace | — |
| `control_plane.host_pool_name` | string | **Yes** | Host pool name | — |
| `control_plane.host_pool_type` | string | **Yes** | `Pooled` or `Personal` | `Pooled` |
| `control_plane.load_balancer_type` | string | Pooled | `BreadthFirst` or `DepthFirst` | `BreadthFirst` |
| `control_plane.max_session_limit` | integer | Pooled | Max concurrent sessions per host | `16` |
| `control_plane.preferred_app_group_type` | string | **Yes** | `Desktop`, `RailApplications`, or `None` | `Desktop` |
| `control_plane.personal_assignment_type` | string | Personal | `Automatic` or `Direct` | `Automatic` |
| `control_plane.start_vm_on_connect` | boolean | No | Requires Desktop Virtualization Power On Contributor RBAC | `false` |
| `control_plane.validation_environment` | boolean | No | Receives service updates before production | `false` |
| `control_plane.custom_rdp_properties` | string | No | Semicolon-delimited RDP properties | `""` |
| `control_plane.app_group_name` | string | **Yes** | Application group name | — |
| `control_plane.app_group_type` | string | **Yes** | `Desktop` or `RemoteApp` | `Desktop` |
| `control_plane.workspace_name` | string | **Yes** | AVD workspace name | — |

---

## Session Hosts

```yaml
session_hosts:
  resource_group: "rg-iic-avd-sh-eus-01"
  session_host_count: 2
  vm_naming_prefix: "vm-iicavd"
  vm_start_index: 1
  vm_processors: 4
  vm_memory_mb: 16384
  vm_admin_username: "avd_admin"
  vm_admin_password: "keyvault://kv-iic-platform/avd-local-admin-password"
  session_host_os: "Windows-11-Enterprise-Multi-Session"
  custom_location_id: "<resource ID>"
  logical_network_id: "<resource ID>"
  gallery_image_id: "<resource ID>"
  storage_path_id: "<resource ID>"
```

| Variable | Type | Required | Description | Default |
|----------|------|:--------:|-------------|---------|
| `session_hosts.resource_group` | string | **Yes** | Resource group for session host VMs | — |
| `session_hosts.session_host_count` | integer | **Yes** | Number of session host VMs | `2` |
| `session_hosts.vm_naming_prefix` | string | **Yes** | VMs named `{prefix}-001`, `{prefix}-002`, etc. | `vm-iicavd` |
| `session_hosts.vm_start_index` | integer | No | Starting index for VM numbering | `1` |
| `session_hosts.vm_processors` | integer | **Yes** | vCPUs per session host | `4` |
| `session_hosts.vm_memory_mb` | integer | **Yes** | RAM per VM in MB | `16384` |
| `session_hosts.vm_admin_username` | string | **Yes** | Local admin username | `avd_admin` |
| `session_hosts.vm_admin_password` | string | **Yes** | Key Vault URI — resolved at runtime | — |
| `session_hosts.session_host_os` | string | **Yes** | OS image name | `Windows-11-Enterprise-Multi-Session` |
| `session_hosts.custom_location_id` | string | **Yes** | Azure Local custom location resource ID | — |
| `session_hosts.logical_network_id` | string | **Yes** | Compute logical network resource ID | — |
| `session_hosts.gallery_image_id` | string | **Yes** | Gallery image resource ID | — |
| `session_hosts.storage_path_id` | string | **Yes** | Storage path resource ID | — |

---

## Domain Join

```yaml
domain:
  domain_fqdn: "contoso.local"
  domain_join_username: "svc.domainjoin"
  domain_join_password: "keyvault://kv-iic-platform/domain-join-password"
  domain_join_ou_path: ""
```

| Variable | Type | Required | Description | Default |
|----------|------|:--------:|-------------|---------|
| `domain.domain_fqdn` | string | **Yes** | Active Directory domain FQDN | `contoso.local` |
| `domain.domain_join_username` | string | **Yes** | Service account for domain join | — |
| `domain.domain_join_password` | string | **Yes** | Key Vault URI for domain join password | — |
| `domain.domain_join_ou_path` | string | No | Target OU — empty uses default Computers container | `""` |

---

## Entra ID Authentication

```yaml
entra_id:
  enable_entra_id_auth: false
  enroll_in_intune: false
  entra_user_login_group_id: ""
  entra_admin_login_group_id: ""
```

| Variable | Type | Required | Description | Default |
|----------|------|:--------:|-------------|---------|
| `entra_id.enable_entra_id_auth` | boolean | No | Installs AADLoginForWindows extension + RDP SSO | `false` |
| `entra_id.enroll_in_intune` | boolean | No | Register session hosts in Intune MDM | `false` |
| `entra_id.entra_user_login_group_id` | string | No | Entra group object ID for VM User Login RBAC | `""` |
| `entra_id.entra_admin_login_group_id` | string | No | Entra group object ID for VM Administrator Login RBAC | `""` |

---

## Tags

```yaml
tags:
  Environment: "Production"
  Project: "AVD on Azure Local"
  ManagedBy: "Infrastructure as Code"
  Owner: "Platform Team"
  CostCenter: "IT-Infrastructure"
```

| Variable | Type | Required | Description | Default |
|----------|------|:--------:|-------------|---------|
| `tags.Environment` | string | No | Environment tag | `Production` |
| `tags.Project` | string | No | Project tag | `AVD on Azure Local` |
| `tags.ManagedBy` | string | No | Managed-by tag | `Infrastructure as Code` |
| `tags.Owner` | string | No | Owner tag | `Platform Team` |
| `tags.CostCenter` | string | No | Cost center tag | `IT-Infrastructure` |

---

## Ansible

```yaml
ansible:
  ansible_connection: "local"
```

| Variable | Type | Required | Description | Default |
|----------|------|:--------:|-------------|---------|
| `ansible.ansible_connection` | string | No | Ansible connection type | `local` |

---

## Key Vault Secret Resolution

Secrets are never stored in plaintext. The `keyvault://` URI format tells deployment tools to resolve the value at runtime:

```yaml
vm_admin_password: "keyvault://kv-iic-platform/avd-local-admin-password"
```

**Resolution flow:**

1. Tool parses the URI → vault name: `kv-iic-platform`, secret name: `avd-local-admin-password`
2. Tool calls `az keyvault secret show --vault-name kv-iic-platform --name avd-local-admin-password`
3. Secret value is passed directly to the deployment — never written to disk

**Required secrets:**

| Secret Name | Used By |
|------------|---------|
| `avd-local-admin-password` | Local admin password for session host VMs |
| `domain-join-password` | Service account password for domain join |

---

## Tool-Specific Parameter Mapping

Each automation tool reads from `config/variables.yml` and maps values to its own parameter format:

| Tool | Parameter File | Location |
|------|---------------|----------|
| **PowerShell** | Reads `config/variables.yml` directly | `config/` |
| **Bicep** | `*.bicepparam` | `avd/bicep/` |
| **Terraform** | `terraform.tfvars` | `avd/terraform/` |
| **ARM** | `*.parameters.json` | `avd/arm/` |
| **Ansible** | `hosts.yml` | `src/ansible/inventory/` |
