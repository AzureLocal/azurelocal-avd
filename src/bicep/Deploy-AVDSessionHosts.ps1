<#
.SYNOPSIS
    Deploy AVD control plane + session host VMs on Azure Local via Bicep.

.DESCRIPTION
    End-to-end deployment script (Bicep variant):
      Step 0. Deploys AVD control plane (host pool, app group, workspace) — creates RG if needed
      Step 1. Generates a fresh AVD registration token (4-hour lifetime)
      Step 2. Resolves domain join + admin credentials from Key Vault
      Step 3. Deploys N session hosts via Bicep template — creates RG if needed

    Both templates deploy at SUBSCRIPTION scope (targetScope = 'subscription').
    They create their target resource groups automatically if they don't exist,
    then deploy resources into those RGs via Bicep modules.

    All deployment parameters are sourced from config/variables.yml.
    Passwords use keyvault:// URIs — resolved at deploy time via Key Vault.

    Bicep templates (subscription-scope wrappers → resource-group-scope resource files):
      - src/bicep/control-plane.bicep  → control-plane-resources.bicep
      - src/bicep/session-hosts.bicep  → session-host-resources.bicep

.PARAMETER ConfigPath
    Path to the variables YAML file.
    Default: config/variables.yml (relative to repo root).

.PARAMETER SessionHostCount
    Override session host count (default: from config session_hosts.session_host_count).

.PARAMETER VmNamingPrefix
    Override VM naming prefix (default: from config session_hosts.vm_naming_prefix).

.PARAMETER VmStartIndex
    Starting index for VM numbering. Default: from config session_hosts.vm_start_index.

.PARAMETER ControlPlaneOnly
    Deploy only the control plane (host pool, app group, workspace). Skip session hosts.

.PARAMETER SkipControlPlane
    Skip control plane deployment. Deploy only session host VMs.
    Use when the host pool already exists and you just need to add session hosts.

.PARAMETER WhatIf
    Dry-run mode — validates templates without deploying.

.EXAMPLE
    # Full deployment — control plane + session hosts:
    .\Deploy-AVDSessionHosts.ps1

    # Control plane only:
    .\Deploy-AVDSessionHosts.ps1 -ControlPlaneOnly

    # Session hosts only (host pool already exists):
    .\Deploy-AVDSessionHosts.ps1 -SkipControlPlane -SessionHostCount 3

    # Dry run:
    .\Deploy-AVDSessionHosts.ps1 -WhatIf
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]   $ConfigPath = "",
    [int]      $SessionHostCount = 0,     # 0 = use config value
    [string]   $VmNamingPrefix = "",     # empty = use config value
    [int]      $VmStartIndex = 0,     # 0 = use config value
    [switch]   $ControlPlaneOnly,
    [switch]   $SkipControlPlane,
    [switch]   $WhatIf
)

# ---------------------------------------------------------------------------
# Validate mutually exclusive switches
# ---------------------------------------------------------------------------
if ($ControlPlaneOnly -and $SkipControlPlane) {
    Write-Error "-ControlPlaneOnly and -SkipControlPlane are mutually exclusive."
    exit 1
}

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$controlPlaneTemplate = Join-Path $PSScriptRoot "control-plane.bicep"
$sessionHostTemplate = Join-Path $PSScriptRoot "session-hosts.bicep"

if (-not $ControlPlaneOnly -and -not (Test-Path $sessionHostTemplate)) {
    Write-Error "Session host Bicep template not found: $sessionHostTemplate"
    exit 1
}
if (-not $SkipControlPlane -and -not (Test-Path $controlPlaneTemplate)) {
    Write-Error "Control plane Bicep template not found: $controlPlaneTemplate"
    exit 1
}

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------
if ($ConfigPath -eq "") {
    $ConfigPath = Join-Path $repoRoot "config\variables.yml"
}
if (-not (Test-Path $ConfigPath)) {
    $examplePath = Join-Path $repoRoot "config\variables.example.yml"
    if (Test-Path $examplePath) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $ConfigPath) -Force | Out-Null
        Copy-Item -Path $examplePath -Destination $ConfigPath -Force
        Write-Host "[WARN] Config not found. Created from template: $ConfigPath" -ForegroundColor Yellow
    } else {
        Write-Error "Config not found: $ConfigPath`nTemplate also missing: $examplePath"
        exit 1
    }
}

try {
    $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Yaml
    Write-Host "[INFO] Loaded config: $ConfigPath" -ForegroundColor Cyan
}
catch {
    Write-Error "Could not parse config YAML: $_"
    exit 1
}

# ---------------------------------------------------------------------------
# Extract config sections
# ---------------------------------------------------------------------------
$sub = $cfg.subscription
$cp = $cfg.control_plane
$sh = $cfg.session_hosts
$dom = $cfg.domain
$sec = $cfg.security
$eid = $cfg.entra_id
$tags = $cfg.tags

$AvdSubscriptionId = $sub.avd_subscription_id
$location = $sub.location

# CLI overrides take precedence
if ($SessionHostCount -le 0) { $SessionHostCount = [int]$sh.session_host_count }
if ($VmNamingPrefix -eq "") { $VmNamingPrefix = $sh.vm_naming_prefix }
if ($VmStartIndex -le 0) { $VmStartIndex = [int]$sh.vm_start_index; if ($VmStartIndex -le 0) { $VmStartIndex = 1 } }

# Validate required values
$requiredValues = @{
    "avd_subscription_id"          = $AvdSubscriptionId
    "host_pool_name"               = $cp.host_pool_name
    "control_plane.resource_group" = $cp.resource_group
    "session_hosts.resource_group" = $sh.resource_group
    "session_host_count"           = $SessionHostCount
    "vm_naming_prefix"             = $VmNamingPrefix
}
$missing = $requiredValues.GetEnumerator() | Where-Object { [string]::IsNullOrWhiteSpace($_.Value) -or $_.Value -eq 0 }
if ($missing) {
    Write-Error "Missing required values in config: $($missing.Key -join ', ')"
    exit 1
}

Write-Host ""
Write-Host "=== Deployment Parameters ===" -ForegroundColor Cyan
Write-Host "  Host Pool:         $($cp.host_pool_name)"
Write-Host "  HP Resource Group: $($cp.resource_group)"
Write-Host "  SH Resource Group: $($sh.resource_group)"
Write-Host "  AVD Subscription:  $AvdSubscriptionId"
Write-Host "  Session Hosts:     $SessionHostCount"
Write-Host "  VM Prefix:         $VmNamingPrefix"
Write-Host "  Start Index:       $VmStartIndex"
Write-Host "  Mode:              $(if ($ControlPlaneOnly) {'Control Plane Only'} elseif ($SkipControlPlane) {'Session Hosts Only'} else {'Full (Control Plane + Session Hosts)'})"
Write-Host ""

# ---------------------------------------------------------------------------
# Step 0 — Deploy AVD Control Plane
# ---------------------------------------------------------------------------
if (-not $SkipControlPlane) {
    Write-Host ""
    Write-Host "=== Step 0: Deploy AVD Control Plane ===" -ForegroundColor Cyan
    Write-Host "  Template:  $controlPlaneTemplate"
    Write-Host "  Target RG: $($cp.resource_group)"
    Write-Host "  Location:  $location"

    $cpEnableEntra = if ($null -ne $eid -and $null -ne $eid.enable_entra_id_auth) { [bool]$eid.enable_entra_id_auth } else { $false }

    $cpDeploymentName = "avd-controlplane-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    $previousContext = Get-AzContext
    Set-AzContext -SubscriptionId $AvdSubscriptionId | Out-Null

    $cpDeployParams = @{
        Name                    = $cpDeploymentName
        Location                = $location
        TemplateFile            = $controlPlaneTemplate
        TemplateParameterObject = @{
            resourceGroupName             = $cp.resource_group
            hostPoolName                  = $cp.host_pool_name
            location                      = $location
            hostPoolType                  = if ($cp.host_pool_type) { $cp.host_pool_type } else { "Pooled" }
            loadBalancerType              = if ($cp.load_balancer_type) { $cp.load_balancer_type } else { "BreadthFirst" }
            maxSessionLimit               = if ($cp.max_session_limit) { [int]$cp.max_session_limit } else { 16 }
            preferredAppGroupType         = if ($cp.preferred_app_group_type) { $cp.preferred_app_group_type } else { "Desktop" }
            personalDesktopAssignmentType = if ($cp.personal_assignment_type) { $cp.personal_assignment_type } else { "Automatic" }
            startVMOnConnect              = if ($null -ne $cp.start_vm_on_connect) { [bool]$cp.start_vm_on_connect } else { $false }
            validationEnvironment         = if ($null -ne $cp.validation_environment) { [bool]$cp.validation_environment } else { $false }
            customRdpProperty             = if ($cp.custom_rdp_properties) { $cp.custom_rdp_properties } else { "" }
            hostPoolFriendlyName          = if ($cp.host_pool_friendly_name) { $cp.host_pool_friendly_name } else { "" }
            hostPoolDescription           = if ($cp.host_pool_description) { $cp.host_pool_description } else { "" }
            appGroupName                  = $cp.app_group_name
            appGroupType                  = if ($cp.app_group_type) { $cp.app_group_type } else { "Desktop" }
            appGroupFriendlyName          = if ($cp.app_group_friendly_name) { $cp.app_group_friendly_name } else { "" }
            workspaceName                 = $cp.workspace_name
            workspaceFriendlyName         = if ($cp.workspace_friendly_name) { $cp.workspace_friendly_name } else { "" }
            tags                          = if ($tags) { $tags } else { @{} }
            enableEntraIdAuth             = $cpEnableEntra
            logAnalyticsWorkspaceName     = if ($cfg.monitoring.log_analytics_workspace_name) { $cfg.monitoring.log_analytics_workspace_name } else { "" }
            desktopVirtualizationUserGroupId = if ($cfg.rbac.desktop_virtualization_user_group_id) { $cfg.rbac.desktop_virtualization_user_group_id } else { "" }
            startVmOnConnectPrincipalId   = if ($cfg.rbac.start_vm_on_connect_principal_id) { $cfg.rbac.start_vm_on_connect_principal_id } else { "" }
        }
    }

    if ($WhatIf) {
        Write-Host "[DRY RUN] Validating control plane template..." -ForegroundColor Yellow
        $cpValidateParams = $cpDeployParams.Clone()
        $cpValidateParams.Remove('Name')
        $result = Test-AzDeployment @cpValidateParams
        if ($result) {
            Write-Host "[FAIL] Control plane validation errors:" -ForegroundColor Red
            $result | Format-List
            exit 1
        }
        else {
            Write-Host "[PASS] Control plane template validation passed" -ForegroundColor Green
        }
    }
    else {
        Write-Host "Deploying $cpDeploymentName ..." -ForegroundColor White
        try {
            $cpDeployment = New-AzSubscriptionDeployment @cpDeployParams -Verbose
            Write-Host ""
            Write-Host "[PASS] Control plane deployed: $($cpDeployment.ProvisioningState)" -ForegroundColor Green
            Write-Host "  Host Pool: $($cpDeployment.Outputs.hostPoolName.Value)"
            Write-Host "  App Group: $($cpDeployment.Outputs.appGroupName.Value)"
            Write-Host "  Workspace: $($cpDeployment.Outputs.workspaceName.Value)"
        }
        catch {
            Write-Error "Control plane deployment failed: $_"
            Write-Host "  az deployment sub list --subscription $AvdSubscriptionId -o table" -ForegroundColor Yellow
            exit 1
        }
    }

    if ($previousContext.Subscription.Id -ne $AvdSubscriptionId) {
        Set-AzContext -SubscriptionId $previousContext.Subscription.Id | Out-Null
    }
}

if ($ControlPlaneOnly) {
    Write-Host ""
    if ($WhatIf) {
        Write-Host "Control plane validation complete (WhatIf)." -ForegroundColor Green
    }
    else {
        Write-Host "Control plane deployment complete. Use -SkipControlPlane to add session hosts." -ForegroundColor Green
    }
    exit 0
}

# ---------------------------------------------------------------------------
# Key Vault helper — resolves keyvault://<vault>/<secret> URIs
# ---------------------------------------------------------------------------
function Resolve-KeyVaultRef {
    param([string]$KvUri)
    if ($KvUri -notmatch '^keyvault://([^/]+)/(.+)$') { return $null }
    $vaultName = $Matches[1]
    $secretName = $Matches[2]

    if (Get-Module -Name Az.KeyVault -ListAvailable -ErrorAction SilentlyContinue) {
        try {
            $secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -AsPlainText -ErrorAction Stop
            if ($secret) { Write-Host "  Retrieved '$secretName' from '$vaultName'" -ForegroundColor Green; return $secret }
        }
        catch { Write-Host "  Az.KeyVault failed: $_" -ForegroundColor Yellow }
    }

    try {
        $azCmd = Get-Command az -ErrorAction SilentlyContinue
        if (-not $azCmd) { return $null }
        $tmpErr = [System.IO.Path]::GetTempFileName()
        $val = (& az keyvault secret show --vault-name $vaultName --name $secretName --query value --output tsv --only-show-errors 2>$tmpErr)
        $azErr = (Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue).Trim()
        Remove-Item $tmpErr -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($val)) { return $null }
        Write-Host "  Retrieved '$secretName' from '$vaultName' (az CLI)" -ForegroundColor Green
        return $val
    }
    catch { return $null }
}

# ---------------------------------------------------------------------------
# Step 1 — Generate fresh AVD registration token
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Step 1: Generate AVD Registration Token ===" -ForegroundColor Cyan

$previousContext = Get-AzContext
Set-AzContext -SubscriptionId $AvdSubscriptionId | Out-Null

if ($WhatIf) {
    Write-Host "[DRY RUN] Using placeholder registration token" -ForegroundColor Yellow
    $registrationToken = "WHATIF-PLACEHOLDER-TOKEN"
}
else {
    $tokenInfo = New-AzWvdRegistrationInfo `
        -ResourceGroupName $cp.resource_group `
        -HostPoolName $cp.host_pool_name `
        -ExpirationTime ((Get-Date).ToUniversalTime().AddHours(4))

    $registrationToken = $tokenInfo.Token
    if ([string]::IsNullOrWhiteSpace($registrationToken)) {
        Write-Error "Failed to generate AVD registration token."
        exit 1
    }
    Write-Host "[PASS] Token generated (expires in 4 hours)" -ForegroundColor Green
}

if ($previousContext.Subscription.Id -ne $AvdSubscriptionId) {
    Set-AzContext -SubscriptionId $AvdSubscriptionId | Out-Null
}

# ---------------------------------------------------------------------------
# Step 2 — Resolve credentials from Key Vault
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Step 2: Resolve Credentials ===" -ForegroundColor Cyan

$domainFqdn = $dom.domain_fqdn
$domainJoinUser = "$domainFqdn\$($dom.domain_join_username)"
$domainJoinOUPath = if ($dom.domain_join_ou_path) { $dom.domain_join_ou_path } else { "" }

Write-Host "  Domain: $domainFqdn"
Write-Host "  Service Account: $domainJoinUser"

if ($WhatIf) {
    Write-Host "[DRY RUN] Using placeholder credentials" -ForegroundColor Yellow
    $adminPassPlain = "WHATIF-PLACEHOLDER"
    $domainPassPlain = "WHATIF-PLACEHOLDER"
}
else {
    Write-Host "  Resolving admin password..."
    $adminPassPlain = Resolve-KeyVaultRef -KvUri $sh.vm_admin_password
    if (-not $adminPassPlain) {
        $adminPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(
                (Read-Host -AsSecureString -Prompt "Enter local admin password")))
    }

    Write-Host "  Resolving domain join password..."
    $domainPassPlain = Resolve-KeyVaultRef -KvUri $dom.domain_join_password
    if (-not $domainPassPlain) {
        $domainPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(
                (Read-Host -AsSecureString -Prompt "Enter domain join password for $domainJoinUser")))
    }
}

Write-Host "[PASS] Credentials ready" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Step 3 — Deploy session hosts via Bicep
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Step 3: Deploy Session Hosts ===" -ForegroundColor Cyan
Write-Host "  Template: $sessionHostTemplate"
Write-Host "  VMs: $SessionHostCount x $VmNamingPrefix-$('{0:D3}' -f $VmStartIndex)..$('{0:D3}' -f ($VmStartIndex + $SessionHostCount - 1))"

$enableEntra = if ($null -ne $eid -and $null -ne $eid.enable_entra_id_auth) { [bool]$eid.enable_entra_id_auth } else { $false }

$deploymentName = "avd-sessionhost-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$deployParams = @{
    Name                    = $deploymentName
    Location                = $location
    TemplateFile            = $sessionHostTemplate
    TemplateParameterObject = @{
        resourceGroupName      = $sh.resource_group
        sessionHostCount       = $SessionHostCount
        vmNamingPrefix         = $VmNamingPrefix
        vmStartIndex           = $VmStartIndex
        location               = $location
        vmProcessors           = [int]$sh.vm_processors
        vmMemoryMB             = [int]$sh.vm_memory_mb
        customLocationId       = $sh.custom_location_id
        logicalNetworkId       = $sh.logical_network_id
        galleryImageId         = $sh.gallery_image_id
        storagePathId          = $sh.storage_path_id
        adminUsername          = $sh.vm_admin_username
        adminPassword          = $adminPassPlain
        domainFqdn             = $domainFqdn
        domainJoinUser         = $domainJoinUser
        domainJoinPassword     = $domainPassPlain
        domainJoinOUPath       = $domainJoinOUPath
        avdRegistrationToken   = $registrationToken
        enableEntraIdAuth      = $enableEntra
        enrollInIntune         = if ($null -ne $eid -and $null -ne $eid.enroll_in_intune) { [bool]$eid.enroll_in_intune } else { $false }
        entraUserLoginGroupId  = if ($eid.entra_user_login_group_id) { $eid.entra_user_login_group_id } else { "" }
        entraAdminLoginGroupId = if ($eid.entra_admin_login_group_id) { $eid.entra_admin_login_group_id } else { "" }
        enableFslogix          = if ($null -ne $cfg.fslogix -and $null -ne $cfg.fslogix.enabled) { [bool]$cfg.fslogix.enabled } else { $false }
        fslogixProfileSharePath = if ($cfg.fslogix.profile_share_path) { $cfg.fslogix.profile_share_path } else { "" }
        fslogixSizeInMBs       = if ($cfg.fslogix.vhd_size_gb) { [int]$cfg.fslogix.vhd_size_gb * 1024 } else { 30720 }
    }
}

if ($WhatIf) {
    Write-Host "[DRY RUN] Validating template..." -ForegroundColor Yellow
    $validateParams = $deployParams.Clone()
    $validateParams.Remove('Name')
    $result = Test-AzDeployment @validateParams
    if ($result) {
        Write-Host "[FAIL] Validation errors:" -ForegroundColor Red
        $result | Format-List
    }
    else {
        Write-Host "[PASS] Template validation passed" -ForegroundColor Green
    }
}
else {
    Write-Host "Deploying $deploymentName ..." -ForegroundColor White
    try {
        $deployment = New-AzSubscriptionDeployment @deployParams -Verbose
        Write-Host ""
        Write-Host "[PASS] Deployment completed: $($deployment.ProvisioningState)" -ForegroundColor Green
        $deployment.Outputs.deployedVMs.Value | ForEach-Object {
            Write-Host "  - $($_.vmName) (Arc: $($_.arcMachineId))"
        }
    }
    catch {
        Write-Error "Deployment failed: $_"
        Write-Host "  az deployment sub list --subscription $AvdSubscriptionId -o table" -ForegroundColor Yellow
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
$adminPassPlain = $null
$domainPassPlain = $null
[System.GC]::Collect()

Write-Host ""
Write-Host "Done." -ForegroundColor Green
