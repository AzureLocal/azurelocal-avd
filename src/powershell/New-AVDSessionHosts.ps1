<#
.SYNOPSIS
    Deploys AVD session-host VMs on an Azure Local cluster and registers them with an AVD host pool.

.DESCRIPTION
    This script:
      1. Retrieves the AVD registration token from Azure Key Vault.
      2. Creates Arc-enabled virtual machines on Azure Local using the Azure Local VM management API.
      3. Domain-joins the VMs (via a custom script extension or DSC).
      4. Installs the AVD Agent and registers the VMs with the host pool.

.PARAMETER ParametersFile
    Path to a parameters.ps1 file containing environment-specific values.

.PARAMETER ResourceGroupName
    Azure resource group that contains (or will contain) the session-host resources.

.PARAMETER CustomLocationId
    Resource ID of the Arc Custom Location for the Azure Local cluster.

.PARAMETER HostPoolName
    Name of the existing AVD host pool.

.PARAMETER HostPoolResourceGroupName
    Resource group of the AVD host pool (defaults to ResourceGroupName if not specified).

.PARAMETER KeyVaultName
    Key Vault that holds the 'avd-registration-token' and 'domain-join-password' secrets.

.PARAMETER VmNamePrefix
    Prefix for session-host VM names. VMs are named '<prefix>-<n>' (e.g. avd-sh-01).

.PARAMETER VmCount
    Number of session-host VMs to deploy. Default: 2.

.PARAMETER VmSize
    Azure Local VM size (e.g. Standard_D4s_v3). Default: Standard_D4s_v3.

.PARAMETER ImageId
    Resource ID of the Azure Local gallery image to use for the VMs.

.PARAMETER VnetId
    Resource ID of the virtual network for the VM NICs.

.PARAMETER SubnetName
    Name of the subnet within the VNet. Default: default.

.PARAMETER DomainFqdn
    Fully-qualified domain name to join (e.g. contoso.local).

.PARAMETER DomainJoinUser
    UPN of the account used to join VMs to the domain (e.g. svc-domainjoin@contoso.local).

.PARAMETER OuPath
    OU path for the computer account (e.g. OU=AVD,OU=Computers,DC=iic,DC=local).

.EXAMPLE
    .\New-AVDSessionHosts.ps1 -ParametersFile .\parameters.ps1

.NOTES
    Requires Az PowerShell module >= 9.0 and the AzStackHCI.VM module.
    Ensure the Key Vault has the secrets 'avd-registration-token' and 'domain-join-password'.
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile,

    [Parameter(Mandatory = $false)]
    [string]$ConfigFile,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$CustomLocationId,

    [Parameter(Mandatory = $false)]
    [string]$HostPoolName,

    [Parameter(Mandatory = $false)]
    [string]$HostPoolResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $false)]
    [string]$VmNamePrefix = 'avd-sh',

    [Parameter(Mandatory = $false)]
    [int]$VmCount = 2,

    [Parameter(Mandatory = $false)]
    [string]$VmSize = 'Standard_D4s_v3',

    [Parameter(Mandatory = $false)]
    [string]$ImageId,

    [Parameter(Mandatory = $false)]
    [string]$VnetId,

    [Parameter(Mandatory = $false)]
    [string]$SubnetName = 'default',

    [Parameter(Mandatory = $false)]
    [string]$DomainFqdn,

    [Parameter(Mandatory = $false)]
    [string]$DomainJoinUser,

    [Parameter(Mandatory = $false)]
    [string]$OuPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$importScript = Join-Path $PSScriptRoot 'Import-AVDConfig.ps1'
if (Test-Path $importScript) {
    . $importScript
}

#region Load parameters file
if ($ConfigFile) {
    if (-not (Get-Command Import-AVDConfig -ErrorAction SilentlyContinue)) {
        throw 'Import-AVDConfig function is not available. Ensure Import-AVDConfig.ps1 is present.'
    }

    $cfg = Import-AVDConfig -ConfigFile $ConfigFile
    if (-not $ResourceGroupName) { $ResourceGroupName = $cfg.session_hosts.resource_group }
    if (-not $CustomLocationId) { $CustomLocationId = $cfg.session_hosts.custom_location_id }
    if (-not $HostPoolName) { $HostPoolName = $cfg.control_plane.host_pool_name }
    if (-not $HostPoolResourceGroupName) { $HostPoolResourceGroupName = $cfg.control_plane.resource_group }
    if (-not $KeyVaultName) { $KeyVaultName = $cfg.security.key_vault_name }
    if (-not $VmNamePrefix) { $VmNamePrefix = $cfg.session_hosts.vm_naming_prefix }
    if (-not $VmCount -and $cfg.session_hosts.session_host_count) { $VmCount = [int]$cfg.session_hosts.session_host_count }
    if (-not $ImageId) { $ImageId = $cfg.session_hosts.gallery_image_id }
    if (-not $VnetId) { $VnetId = $cfg.session_hosts.logical_network_id }
    if (-not $DomainFqdn) { $DomainFqdn = $cfg.domain.domain_fqdn }
    if (-not $DomainJoinUser) { $DomainJoinUser = "$($cfg.domain.domain_fqdn)\$($cfg.domain.domain_join_username)" }
    if (-not $OuPath) { $OuPath = $cfg.domain.domain_join_ou_path }
}

if ($ParametersFile) {
    if (-not (Test-Path $ParametersFile)) {
        throw "Parameters file not found: $ParametersFile"
    }
    . $ParametersFile
}

if (-not $ResourceGroupName)           { $ResourceGroupName           = $script:ResourceGroupName }
if (-not $CustomLocationId)            { $CustomLocationId            = $script:CustomLocationId }
if (-not $HostPoolName)                { $HostPoolName                = $script:HostPoolName }
if (-not $KeyVaultName)                { $KeyVaultName                = $script:KeyVaultName }
if (-not $ImageId)                     { $ImageId                     = $script:ImageId }
if (-not $VnetId)                      { $VnetId                      = $script:VnetId }
if (-not $DomainFqdn)                  { $DomainFqdn                  = $script:DomainFqdn }
if (-not $DomainJoinUser)              { $DomainJoinUser              = $script:DomainJoinUser }
if (-not $OuPath)                      { $OuPath                      = $script:OuPath }

if (-not $HostPoolResourceGroupName) {
    $HostPoolResourceGroupName = $ResourceGroupName
}
#endregion

#region Validate required parameters
foreach ($param in @('ResourceGroupName', 'CustomLocationId', 'HostPoolName', 'KeyVaultName', 'ImageId', 'VnetId', 'DomainFqdn', 'DomainJoinUser')) {
    if (-not (Get-Variable -Name $param -ValueOnly -ErrorAction SilentlyContinue)) {
        throw "Required parameter '$param' is not set."
    }
}
#endregion

Write-Host "=== AVD Session Host Deployment ===" -ForegroundColor Cyan
Write-Host "  Resource Group    : $ResourceGroupName" -ForegroundColor Gray
Write-Host "  Custom Location   : $CustomLocationId" -ForegroundColor Gray
Write-Host "  Host Pool         : $HostPoolName" -ForegroundColor Gray
Write-Host "  VM Count          : $VmCount" -ForegroundColor Gray

#region Retrieve secrets from Key Vault
Write-Host "`nRetrieving secrets from Key Vault '$KeyVaultName'..." -ForegroundColor Yellow
$registrationToken = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name 'avd-registration-token' -AsPlainText)
$domainJoinPassword = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name 'domain-join-password' -AsPlainText)
Write-Host "  Secrets retrieved." -ForegroundColor Green
#endregion

#region Deploy VMs
for ($i = 1; $i -le $VmCount; $i++) {
    $vmName = '{0}-{1:D2}' -f $VmNamePrefix, $i

    Write-Host "`nDeploying VM '$vmName' ($i of $VmCount)..." -ForegroundColor Yellow

    $existingVm = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $vmName -ErrorAction SilentlyContinue
    if ($existingVm) {
        Write-Host "  VM '$vmName' already exists – skipping creation." -ForegroundColor DarkYellow
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($vmName, 'Create Azure Local VM')) {
        continue
    }

    # Build the VM configuration for Azure Local (Arc-enabled VM via AzureLocal resource provider)
    $vmConfig = @{
        ResourceGroupName  = $ResourceGroupName
        Name               = $vmName
        ExtendedLocation   = @{
            name = $CustomLocationId
            type = 'CustomLocation'
        }
        # Hardware profile
        HardwareProfileVmSize = $VmSize
        # OS profile
        OsProfileComputerName       = $vmName
        OsProfileAdminUsername      = 'azureuser'
        OsProfileAdminPassword      = (ConvertTo-SecureString -String ([System.Web.HttpUtility]::UrlEncode([System.Guid]::NewGuid().ToString())) -AsPlainText -Force)
        # Storage profile
        StorageProfileImageReference = $ImageId
        # Network profile
        NetworkProfileNetworkInterface = @(@{
            id = $VnetId
            properties = @{ subnet = @{ id = "$VnetId/subnets/$SubnetName" } }
        })
    }

    # Use AzStackHCI VM cmdlets if available, otherwise use generic REST via Invoke-AzRestMethod
    if (Get-Command New-AzStackHCIVMVirtualMachine -ErrorAction SilentlyContinue) {
        New-AzStackHCIVMVirtualMachine @vmConfig | Out-Null
    }
    else {
        Write-Warning "AzStackHCI.VM module not found. Deploying via ARM REST API. Install 'AzStackHCI.VM' module for full support."
        # Minimal ARM body for HCI VM
        $body = $vmConfig | ConvertTo-Json -Depth 10
        Invoke-AzRestMethod -Method PUT `
            -Path "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.HybridCompute/machines/{2}?api-version=2023-10-03-preview" -f `
                (Get-AzContext).Subscription.Id, $ResourceGroupName, $vmName `
            -Payload $body | Out-Null
    }

    Write-Host "  VM '$vmName' created." -ForegroundColor Green

    #region Domain Join Extension
    Write-Host "  Configuring domain-join extension for '$vmName'..." -ForegroundColor Yellow
    $djSettings = @{
        domainToJoin = $DomainFqdn
        ouPath       = $OuPath
        user         = $DomainJoinUser
        restart      = 'true'
        options      = '3'
    }
    $djProtectedSettings = @{ password = $domainJoinPassword }

    Set-AzVMExtension `
        -ResourceGroupName $ResourceGroupName `
        -VMName $vmName `
        -Name 'JsonADDomainExtension' `
        -Publisher 'Microsoft.Compute' `
        -ExtensionType 'JsonADDomainExtension' `
        -TypeHandlerVersion '1.3' `
        -Settings $djSettings `
        -ProtectedSettings $djProtectedSettings | Out-Null
    Write-Host "  Domain join extension configured." -ForegroundColor Green
    #endregion

    #region AVD Agent Extension
    Write-Host "  Installing AVD Agent on '$vmName'..." -ForegroundColor Yellow
    $avdSettings = @{ registrationInfoToken = $registrationToken }

    Set-AzVMExtension `
        -ResourceGroupName $ResourceGroupName `
        -VMName $vmName `
        -Name 'AVDAgent' `
        -Publisher 'Microsoft.Compute' `
        -ExtensionType 'CustomScriptExtension' `
        -TypeHandlerVersion '1.10' `
        -Settings @{
            fileUris         = @('https://raw.githubusercontent.com/Azure/RDS-Templates/master/ARM-wvd-templates/DSC/Configuration.zip')
            commandToExecute = "powershell -ExecutionPolicy Unrestricted -File Deploy-Agent.ps1 -RegistrationInfoToken $($registrationToken)"
        } | Out-Null
    Write-Host "  AVD Agent extension triggered." -ForegroundColor Green
    #endregion
}
#endregion

Write-Host "`n=== Session Host Deployment Complete ===" -ForegroundColor Green
Write-Host "Verify hosts in the Azure portal: Host Pools > $HostPoolName > Session Hosts" -ForegroundColor Cyan
