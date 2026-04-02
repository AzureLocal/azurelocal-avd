# AVD parameters (TRANSITIONAL) – copy to parameters.ps1 and fill in your values.
# DO NOT commit parameters.ps1 (it is .gitignore'd).
# Preferred contract: config/variables.yml consumed through -ConfigFile.
# This file remains for backward compatibility while migration to canonical YAML completes.

# ── Subscription & Global ────────────────────────────────────────────
$ResourceGroupName = 'rg-avd-prod'
$Location = 'eastus'

# ── Control Plane ────────────────────────────────────────────────────
$HostPoolName = 'hp-azurelocal-pool01'
$HostPoolType = 'Pooled'           # Pooled | Personal
$LoadBalancerType = 'BreadthFirst'     # BreadthFirst | DepthFirst
$MaxSessionLimit = 10
$WorkspaceName = 'ws-avd-prod'
$AppGroupName = 'ag-avd-desktops'
$KeyVaultName = 'kv-avd-prod-001'  # Must be globally unique
$LogAnalyticsWorkspaceName = 'law-avd-prod'

# ── Session Hosts ────────────────────────────────────────────────────
# Azure Local custom location resource ID
# Found in: Azure Portal > Azure Local cluster > Overview > Custom location
$CustomLocationId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-azurelocal/providers/Microsoft.ExtendedLocation/customLocations/cl-azurelocal-01'

# Existing AVD host pool (created by New-AVDControlPlane.ps1)
# $HostPoolName already defined above

# Key Vault containing 'avd-registration-token' and 'domain-join-password'
# $KeyVaultName already defined above

# Session host VM settings
$VmNamePrefix = 'avd-sh'
$VmCount = 2
$VmSize = 'Standard_D4s_v3'

# Azure Local gallery image resource ID
$ImageId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-azurelocal/providers/Microsoft.AzureStackHCI/galleryImages/win11-multisession-23h2'

# Virtual network resource ID
$VnetId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-azurelocal/providers/Microsoft.AzureStackHCI/virtualNetworks/vnet-azurelocal-01'
$SubnetName = 'default'

# ── Domain Join ──────────────────────────────────────────────────────
$DomainFqdn = 'contoso.local'
$DomainJoinUser = 'svc-domainjoin@contoso.local'
$OuPath = 'OU=AVD,OU=Computers,DC=iic,DC=local'

# ── Tags ─────────────────────────────────────────────────────────────
$EnvironmentTag = 'production'
$OwnerTag = 'platform-team'
