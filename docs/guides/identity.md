# Identity & RBAC

This guide explains every aspect of identity configuration for AVD on Azure Local — the two supported authentication strategies, exactly what RBAC roles get assigned and where, the VM extensions deployed on each session host (Arc-enabled VMs), and how each IaC tool implements it.

!!! warning "Azure Local Constraint — Entra-only Join NOT Supported"
    On Azure Local, session hosts are Arc-enabled VMs (`Microsoft.HybridCompute/machines`), NOT standard Azure VMs. Arc-enabled VMs **do not support Entra-only join**. Only **AD-Only** and **Hybrid Join** are valid identity strategies. If you need SSO and Conditional Access, use **Hybrid Join** (recommended). Entra-only join is only available for standard Azure VMs in cloud-based AVD deployments.

## Why Identity Configuration Matters

AVD session hosts are Arc-enabled VMs on Azure Local that users log into remotely. Something needs to authenticate those users. There are two supported ways to do it on Azure Local, each with different infrastructure requirements, user experience, and security capabilities. The choice affects:

- Whether users get **single sign-on (SSO)** to their desktop
- Whether you can enforce **Conditional Access** policies (MFA, compliant device, location)
- What **VM extensions** get deployed on each session host
- What **RBAC role assignments** are needed in Azure
- Whether you need an **on-premises AD domain controller**

![Identity Strategies Comparison](../assets/diagrams/avd-identity.png)

> *Open the [draw.io source](../assets/diagrams/avd-identity.drawio) for an editable version.*

---

## What Gets Deployed

Identity deployment creates two types of Azure resources:

### 1. RBAC Role Assignments

| Azure Resource Type | What It Is |
|---|---|
| `Microsoft.Authorization/roleAssignments` | A binding between a security principal (Entra ID group), a role definition, and a scope (resource group or app group). Multiple role assignments are created depending on the identity strategy. |

### 2. VM Extensions (per Arc-enabled session host)

| Extension | ARM Type | Publisher | When Deployed |
|---|---|---|---|
| `JsonADDomainExtension` | `Microsoft.HybridCompute/machines/extensions` | `Microsoft.Compute` | `ad_only` and `hybrid_join` — joins the VM to the AD domain |
| `AADLoginForWindows` | `Microsoft.HybridCompute/machines/extensions` | `Microsoft.Azure.ActiveDirectory` | `hybrid_join` only — enables Entra ID login and SSO alongside AD domain membership |

---

## Identity Strategies — Deep Dive

### AD-Only (`ad_only`)

**What it is:** Traditional Active Directory domain join. Users authenticate with their AD username and password. No Entra ID involvement at all.

**Authentication flow step by step:**

1. User opens AVD client → client contacts the AVD broker at `rdbroker.wvd.microsoft.com` (HTTPS 443)
2. Broker validates the user's Entra ID token (yes, even for AD-only, the AVD **client** authenticates to the broker via Entra ID — but the **session host** login is pure AD)
3. Broker assigns a session host and returns an RDP connection file
4. Client initiates RDP to the session host via the AVD gateway reverse-connect
5. Session host presents a Windows logon screen — user enters AD credentials (`domain\username` or `user@domain.fqdn`)
6. Session host validates credentials against the AD domain controller over LDAP/Kerberos (on-premises network)
7. User is logged in with their AD profile

**What gets deployed on each session host:**

- **`JsonADDomainExtension`** — Joins the VM to the AD domain. The extension runs `netdom join` under the hood using the service account credentials from config (`identity.domain.join_account`). Requires outbound connectivity to the domain controller over LDAP (389/636) and Kerberos (88).

**RBAC role assignments created:**

| Role | Scope | Principal | Purpose |
|---|---|---|---|
| Desktop Virtualization User | Application Group | `avd_users_group_id` | Lets Entra ID users see the desktop/app in the AVD client feed. Without this, the client shows "No resources available." |

Note: No VM Login roles are needed because users authenticate directly to AD, not Entra ID.

**Pros:**

- Simplest AVD setup if you already have AD infrastructure
- No Entra ID premium features needed
- Works with legacy apps that require AD Kerberos tokens

**Cons:**

- No SSO — users must enter credentials at the Windows logon screen after connecting
- No Conditional Access policies on the session
- Requires on-premises AD domain controller accessible from session hosts

---

### Hybrid Join (`hybrid_join`) — Recommended

**What it is:** Session hosts are domain-joined to AD AND registered in Entra ID. Gets the benefits of both worlds — AD Kerberos for legacy apps, Entra SSO for the user experience, and Conditional Access for security.

**Authentication flow step by step:**

1. User opens AVD client → authenticates to the AVD broker via Entra ID (PRT)
2. Broker assigns a session host
3. Client initiates RDP to the session host via the AVD gateway
4. The `AADLoginForWindows` extension validates the token against Entra ID (SSO)
5. Session host also has an AD computer account → it can request Kerberos tickets on behalf of the user
6. User is logged in with SSO, and has access to both Entra ID and AD resources

**What gets deployed on each session host:**

- **`JsonADDomainExtension`** — Domain joins the VM to AD (same as `ad_only`)
- **`AADLoginForWindows`** — Enables Entra ID login with one additional setting: `{ "mdmId": "" }`. The empty `mdmId` tells the extension this is a hybrid join (not Intune-managed) so it registers the device in Entra ID as hybrid-joined rather than Entra-joined.

**Prerequisites:**

- **Azure AD Connect** (or Cloud Sync) must be running and syncing AD computer objects to Entra ID. Without this, the hybrid join registration fails — the session host appears as "Pending" in Entra ID > Devices.
- AD domain controller must be accessible from session hosts

**RBAC role assignments created:**

| Role | Scope | Principal | Purpose |
|---|---|---|---|
| Desktop Virtualization User | Application Group | `avd_users_group_id` | Feed visibility. |
| Virtual Machine User Login | Resource Group | `avd_users_group_id` | Entra ID-based sign-in permission. |
| Virtual Machine Administrator Login | Resource Group | `avd_admins_group_id` | Optional admin access via Entra ID. |

**Pros:**

- SSO via Entra ID — best user experience
- Full Conditional Access support
- Kerberos tickets available — legacy apps work
- Access to both cloud and on-premises resources

**Cons:**

- Most complex infrastructure — requires AD DC, Azure AD Connect, and Entra ID
- Two identity sources to maintain and troubleshoot
- Azure AD Connect sync latency can delay hybrid join registration (up to 30 min)

---

## RBAC Roles — Complete Reference

| Role Definition Name | Built-in Role ID | Scope | Assigned When | What It Grants |
|---|---|---|---|---|
| Desktop Virtualization User | `1d18fff3-a72a-46b5-b4a9-0b37a71c5b63` | Application Group | Always (all strategies) | Permission to access the published desktop or app. Without this, the AVD client shows "No resources found." |
| Virtual Machine User Login | `fb879df8-f326-4884-b1cf-06f3ad86be52` | Resource Group | `hybrid_join` | Permission to sign into VMs as a standard user via Entra ID. Required for the `AADLoginForWindows` extension to work. |
| Virtual Machine Administrator Login | `1c0163c0-47e6-4577-8991-ea5c82e286e4` | Resource Group | `hybrid_join` (optional) | Permission to sign into VMs as an administrator via Entra ID. For IT staff troubleshooting. |
| Desktop Virtualization Power On Contributor | `489581de-a3bd-480d-9518-53dea7416b33` | Host Pool / Resource Group | When scaling is enabled | Allows the AVD scaling plan service (first-party app `9cdead84-a844-4324-93f2-b2e6bb768d07`) to start and stop session host VMs. |

---

## Configuration — Every Field Explained

```yaml
identity:
  strategy: hybrid_join               # ad_only | hybrid_join
  entra_id:
    tenant_id: "00000000-..."         # Your Entra ID tenant ID. Used by the AADLoginForWindows extension.
    avd_users_group_id: "00000000-..."  # Object ID of the Entra ID security group containing AVD users.
                                       # Gets Desktop Virtualization User + VM User Login roles.
    avd_admins_group_id: "00000000-..." # Object ID of the admin group. Gets VM Administrator Login role. Optional.
  domain:
    fqdn: "contoso.local"                 # AD domain FQDN for domain join. Used by ad_only and hybrid_join.
    ou_path: "OU=AVD,OU=Computers,DC=iic,DC=local"  # OU where session host computer accounts are created.
    join_account: "svc-domainjoin@contoso.local"          # Service account with permission to join computers to domain.
                                                       # Password pulled from Key Vault at deploy time.
  rbac:
    assign_roles: true                # Whether to create RBAC role assignments. Set to false if managing roles externally.
```

---

## What Each IaC Tool Deploys — Resource by Resource

### Terraform (`src/terraform/identity.tf`)

| Terraform Resource | Azure Resource Created | Condition | What It Does |
|---|---|---|---|
| `azurerm_role_assignment.avd_user` | Role assignment: DVU on App Group | `var.avd_user_group_id != ""` | Assigns "Desktop Virtualization User" to the users group on the application group scope. |
| `azurerm_role_assignment.vm_user_login` | Role assignment: VM User Login on RG | `strategy == "hybrid_join" && avd_user_group_id != ""` | Assigns "Virtual Machine User Login" to the users group on the resource group. Only for Hybrid Join. |
| `azurerm_role_assignment.vm_admin_login` | Role assignment: VM Admin Login on RG | `strategy == "hybrid_join" && avd_admin_group_id != ""` | Assigns "Virtual Machine Administrator Login" to the admin group. |
| `azurerm_role_assignment.custom` | Additional role assignments | `length(var.rbac_assignments) > 0` | Iterates over `var.rbac_assignments` list for any custom role bindings. |
| `azapi_resource.aad_login_ext` | AADLoginForWindows VM extension | `strategy == "hybrid_join"` | Deploys the `AADLoginForWindows` extension to each session host using `for_each = toset(local.vm_names)`. Settings include `{ "mdmId": "" }`. |

**Terraform variables:**

```hcl
identity_strategy  = "hybrid_join"
avd_user_group_id  = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
avd_admin_group_id = "ffffffff-gggg-hhhh-iiii-jjjjjjjjjjjj"
rbac_assignments   = []  # Optional additional role assignments
```

### Bicep / ARM

The session host Bicep module (`session-hosts.bicep`) deploys the `JsonADDomainExtension` and `AADLoginForWindows` extensions as child resources of each VM. The identity module handles RBAC role assignments via `Microsoft.Authorization/roleAssignments` resources.

### PowerShell (`src/powershell/Configure-AVDIdentity.ps1`)

The PowerShell script does the following in order:

1. Loads config and determines the identity strategy
2. Checks for existing role assignments (idempotent — won't create duplicates)
3. Creates `Desktop Virtualization User` role assignment on the app group
4. If `hybrid_join`: creates `Virtual Machine User Login` role assignment on the RG
5. If admin group is configured: creates `Virtual Machine Administrator Login` role assignment
6. If `hybrid_join`: loops over all session hosts and deploys the `AADLoginForWindows` extension via `Invoke-AzRestMethod PUT` to the Arc extensions API

```powershell
.\src\powershell\Configure-AVDIdentity.ps1 -ConfigPath config/variables.yml
```

### Ansible (`src/ansible/roles/avd-identity/tasks/main.yml`)

Uses `azure_rm_roleassignment` for RBAC and `azure_rm_resource` for the VM extension deployment. Tagged as `identity` in the site.yml playbook.

```bash
ansible-playbook src/ansible/playbooks/site.yml -i inventory.yml --tags identity
```

---

## Conditional Access — Recommended Policies

For `hybrid_join`, configure these Conditional Access policies in the Entra ID portal:

| Policy | Target App | Grant Control | Why |
|---|---|---|---|
| Require MFA for AVD | Windows Virtual Desktop (app ID: `9cdead84-a844-4324-93f2-b2e6bb768d07`) | Require multifactor authentication | Prevents credential-stuffed accounts from connecting. |
| Require compliant device | Windows Virtual Desktop | Require device to be marked as compliant | Ensures only managed/healthy client devices can initiate sessions. |
| Block legacy auth | Windows Virtual Desktop | Block access — with condition: Client apps = "Other clients" | Prevents old RDP clients that don't support modern auth. |
| Session controls | Windows Virtual Desktop | Sign-in frequency: 8 hours; Persistent browser: No | Forces re-authentication after 8 hours. Prevents stale sessions. |

---

## Troubleshooting

| Symptom | Strategy | Root Cause | Resolution |
|---|---|---|---|
| User sees "No resources found" | Any | Missing `Desktop Virtualization User` role on the app group | Run identity deployment or manually assign the role |
| "Access denied" after connecting | `hybrid_join` | Missing `Virtual Machine User Login` role on the RG | Assign the role to the users group |
| Domain join failed | `ad_only` / `hybrid_join` | Service account can't join to domain, OU path wrong, or DC unreachable | Check OU path, service account permissions, and network connectivity to DC on port 389/636/88 |
| Hybrid join "Pending" in Entra | `hybrid_join` | Azure AD Connect hasn't synced the computer object yet | Wait for sync (up to 30 min) or force sync: `Start-ADSyncSyncCycle -PolicyType Delta` |
| SSO not working — user gets password prompt | `hybrid_join` | `AADLoginForWindows` extension not installed, or PRT expired | Verify extension is installed: `az connectedmachine extension show --machine-name <vm> --name AADLoginForWindows`. Check that the RDP client supports SSO (must be Windows client v1.2.3317+). |
