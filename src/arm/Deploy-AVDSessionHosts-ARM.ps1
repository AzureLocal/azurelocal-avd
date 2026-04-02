<#
.SYNOPSIS
    Deploy AVD session host VMs on Azure Local via ARM template (cross-subscription).

.DESCRIPTION
    End-to-end deployment script (ARM template variant):
      1. Loads config/variables.yml
      2. Generates a fresh AVD registration token (4-hour lifetime)
      3. Resolves domain join + admin credentials from Key Vault
      4. Deploys N session hosts via ARM template (single-VM template, looped)

    The ARM template deploys a single VM per iteration. For batch deployments
    with parallel resource creation, use the Bicep variant (Deploy-AVDSessionHosts.ps1).

.PARAMETER ConfigPath
    Path to the variables YAML file.
    Default: config/variables.yml (relative to repo root).

.PARAMETER SessionHostCount
    Override session host count (default: from config session_hosts.session_host_count).

.PARAMETER VmNamingPrefix
    Override VM naming prefix (default: from config session_hosts.vm_naming_prefix).

.PARAMETER VmStartIndex
    Starting index for VM numbering. Default: from config session_hosts.vm_start_index.

.PARAMETER WhatIf
    Dry-run mode — validates template without deploying.

.EXAMPLE
    .\Deploy-AVDSessionHosts-ARM.ps1
    .\Deploy-AVDSessionHosts-ARM.ps1 -SessionHostCount 3 -WhatIf
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]   $ConfigPath       = "",
    [int]      $SessionHostCount = 0,
    [string]   $VmNamingPrefix   = "",
    [int]      $VmStartIndex     = 0,
    [switch]   $WhatIf
)

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
$repoRoot    = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$armTemplate = Join-Path $PSScriptRoot "session-hosts.json"

if (-not (Test-Path $armTemplate)) {
    Write-Error "ARM template not found: $armTemplate"
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
} catch {
    Write-Error "Could not parse config YAML: $_"
    exit 1
}

# ---------------------------------------------------------------------------
# Extract config sections
# ---------------------------------------------------------------------------
$sub  = $cfg.subscription
$cp   = $cfg.control_plane
$sh   = $cfg.session_hosts
$dom  = $cfg.domain

$AvdSubscriptionId = $sub.avd_subscription_id
$location          = $sub.location

if ($SessionHostCount -le 0) { $SessionHostCount = [int]$sh.session_host_count }
if ($VmNamingPrefix -eq "")  { $VmNamingPrefix = $sh.vm_naming_prefix }
if ($VmStartIndex -le 0)     { $VmStartIndex = [int]$sh.vm_start_index; if ($VmStartIndex -le 0) { $VmStartIndex = 1 } }

Write-Host ""
Write-Host "=== Deployment Parameters ===" -ForegroundColor Cyan
Write-Host "  Host Pool:     $($cp.host_pool_name)"
Write-Host "  Target RG:     $($sh.resource_group)"
Write-Host "  Subscription:  $AvdSubscriptionId"
Write-Host "  Session Hosts: $SessionHostCount"
Write-Host "  VM Prefix:     $VmNamingPrefix"
Write-Host ""

# ---------------------------------------------------------------------------
# Key Vault helper
# ---------------------------------------------------------------------------
function Resolve-KeyVaultRef {
    param([string]$KvUri)
    if ($KvUri -notmatch '^keyvault://([^/]+)/(.+)$') { return $null }
    $vaultName  = $Matches[1]
    $secretName = $Matches[2]

    if (Get-Module -Name Az.KeyVault -ListAvailable -ErrorAction SilentlyContinue) {
        try {
            $secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -AsPlainText -ErrorAction Stop
            if ($secret) { Write-Host "  Retrieved '$secretName' from '$vaultName'" -ForegroundColor Green; return $secret }
        } catch { Write-Host "  Az.KeyVault failed: $_" -ForegroundColor Yellow }
    }

    try {
        $azCmd = Get-Command az -ErrorAction SilentlyContinue
        if (-not $azCmd) { return $null }
        $tmpErr = [System.IO.Path]::GetTempFileName()
        $val = (& az keyvault secret show --vault-name $vaultName --name $secretName --query value --output tsv --only-show-errors 2>$tmpErr)
        Remove-Item $tmpErr -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($val)) { return $null }
        Write-Host "  Retrieved '$secretName' from '$vaultName' (az CLI)" -ForegroundColor Green
        return $val
    } catch { return $null }
}

# ---------------------------------------------------------------------------
# Step 1 — Generate fresh AVD registration token
# ---------------------------------------------------------------------------
Write-Host "=== Step 1: Generate AVD Registration Token ===" -ForegroundColor Cyan

$previousContext = Get-AzContext
Set-AzContext -SubscriptionId $AvdSubscriptionId | Out-Null

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

if ($previousContext.Subscription.Id -ne $AvdSubscriptionId) {
    Set-AzContext -SubscriptionId $AvdSubscriptionId | Out-Null
}

# ---------------------------------------------------------------------------
# Step 2 — Resolve credentials
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Step 2: Resolve Credentials ===" -ForegroundColor Cyan

$domainFqdn       = $dom.domain_fqdn
$domainJoinUser   = "$domainFqdn\$($dom.domain_join_username)"
$domainJoinOUPath = if ($dom.domain_join_ou_path) { $dom.domain_join_ou_path } else { "" }

$adminPassPlain = Resolve-KeyVaultRef -KvUri $sh.vm_admin_password
if (-not $adminPassPlain) {
    $adminPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            (Read-Host -AsSecureString -Prompt "Enter local admin password")))
}

$domainPassPlain = Resolve-KeyVaultRef -KvUri $dom.domain_join_password
if (-not $domainPassPlain) {
    $domainPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            (Read-Host -AsSecureString -Prompt "Enter domain join password for $domainJoinUser")))
}

Write-Host "[PASS] Credentials ready" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Step 3 — Build CSE command
# ---------------------------------------------------------------------------
# ARM template uses a single CSE extension (unlike Bicep which has separate extensions)
$escapedDomainPass = $domainPassPlain -replace "'","''"
$cseCommand = @"
powershell -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `$p = ConvertTo-SecureString '$escapedDomainPass' -AsPlainText -Force; `$c = New-Object PSCredential('$domainJoinUser', `$p); Add-Computer -DomainName '$domainFqdn' -Credential `$c $(if ($domainJoinOUPath) { "-OUPath '$domainJoinOUPath' " })-Force; Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2310011' -OutFile 'C:\AVDAgent.msi'; Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2311028' -OutFile 'C:\AVDBootloader.msi'; `$p1 = Start-Process msiexec -ArgumentList '/i C:\AVDAgent.msi REGISTRATIONTOKEN=$registrationToken /quiet /norestart' -Wait -PassThru; if (`$p1.ExitCode -ne 0) { 'AVDAgent install failed: ' + `$p1.ExitCode | Out-File C:\avd-setup-error.log }; `$p2 = Start-Process msiexec -ArgumentList '/i C:\AVDBootloader.msi /quiet /norestart' -Wait -PassThru; if (`$p2.ExitCode -ne 0) { 'AVDBootloader install failed: ' + `$p2.ExitCode | Out-File C:\avd-setup-error.log -Append }; Restart-Computer -Force"
"@

# ---------------------------------------------------------------------------
# Step 4 — Deploy ARM template (loop per VM)
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Step 4: Deploy ARM Template ===" -ForegroundColor Cyan

$deployedVMs = @()

for ($i = $VmStartIndex; $i -lt ($VmStartIndex + $SessionHostCount); $i++) {
    $vmName  = "$VmNamingPrefix-$('{0:D3}' -f $i)"
    $nicName = "$vmName-nic"
    $deploymentName = "arm-avd-$vmName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    Write-Host "  [$i/$($VmStartIndex + $SessionHostCount - 1)] Deploying: $vmName" -ForegroundColor White

    $templateParams = @{
        vmName           = $vmName
        nicName          = $nicName
        location         = $location
        customLocationId = $sh.custom_location_id
        logicalNetworkId = $sh.logical_network_id
        imageId          = $sh.gallery_image_id
        storagePathId    = $sh.storage_path_id
        adminUsername    = $sh.vm_admin_username
        adminPassword    = $adminPassPlain
        memorymb         = [int]$sh.vm_memory_mb
        processors       = [int]$sh.vm_processors
        commandToExecute = $cseCommand
    }

    if ($WhatIf) {
        $result = Test-AzResourceGroupDeployment `
            -ResourceGroupName $sh.resource_group `
            -TemplateFile $armTemplate `
            -TemplateParameterObject $templateParams
        if ($result) {
            Write-Host "  [FAIL] $vmName validation errors:" -ForegroundColor Red
            $result | Format-List
        } else {
            Write-Host "  [PASS] $vmName validation passed" -ForegroundColor Green
        }
    } else {
        try {
            $deployment = New-AzResourceGroupDeployment `
                -Name $deploymentName `
                -ResourceGroupName $sh.resource_group `
                -TemplateFile $armTemplate `
                -TemplateParameterObject $templateParams `
                -Verbose
            Write-Host "  [PASS] $vmName deployed: $($deployment.ProvisioningState)" -ForegroundColor Green
            $deployedVMs += $vmName
        } catch {
            Write-Error "  [FAIL] $vmName failed: $_"
        }
    }
}

# ---------------------------------------------------------------------------
# Summary & Cleanup
# ---------------------------------------------------------------------------
Write-Host ""
if (-not $WhatIf -and $deployedVMs.Count -gt 0) {
    Write-Host "[PASS] Deployed $($deployedVMs.Count) session hosts:" -ForegroundColor Green
    $deployedVMs | ForEach-Object { Write-Host "  - $_" }
}

$adminPassPlain  = $null
$domainPassPlain = $null
$cseCommand      = $null
[System.GC]::Collect()

Write-Host ""
Write-Host "Done." -ForegroundColor Green
