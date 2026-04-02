<#
.SYNOPSIS
    Common configuration loader for azurelocal-avd PowerShell scripts.

.DESCRIPTION
    Reads config/variables.yml (YAML) and returns a hashtable. Resolves
    keyvault:// URIs by fetching secrets from Azure Key Vault at load time.

    Also integrates with CanonicalVariable.psm1 for canonical path lookups
    and alias resolution from the master registry (when available).

    All deployment scripts dot-source this module:
      . .\common\Config-Loader.ps1
      $config = Get-AVDConfig -ConfigPath '..\..\config\variables.yml'

.PARAMETER ConfigPath
    Path to the YAML configuration file.

.PARAMETER ResolveSecrets
    When $true (default), resolves keyvault:// URIs to plaintext values.
    Set to $false for dry-run / validation scenarios.
#>

# Try to load canonical variable module (optional — graceful fallback if not present)
$script:CanonicalModulePath = Join-Path $PSScriptRoot 'CanonicalVariable.psm1'
$script:CanonicalAvailable = $false
if (Test-Path $script:CanonicalModulePath) {
    try {
        Import-Module $script:CanonicalModulePath -ErrorAction Stop
        $script:CanonicalAvailable = $true
    } catch {
        Write-Verbose "CanonicalVariable module not loaded: $_"
    }
}

function Get-AVDConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [Parameter()]
        [bool]$ResolveSecrets = $true
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    # Require powershell-yaml module
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        throw "Module 'powershell-yaml' is required. Install with: Install-Module powershell-yaml -Scope CurrentUser"
    }
    Import-Module powershell-yaml -ErrorAction Stop

    $yamlContent = Get-Content -Path $ConfigPath -Raw
    $config = ConvertFrom-Yaml $yamlContent

    if ($ResolveSecrets) {
        $config = Resolve-KeyVaultSecrets -Config $config
    }

    return $config
}

function Resolve-KeyVaultSecrets {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Config
    )

    function Resolve-Recursive {
        param ([object]$Obj)

        if ($Obj -is [string] -and $Obj -match '^keyvault://([^/]+)/(.+)$') {
            $vaultName = $Matches[1]
            $secretName = $Matches[2]
            try {
                $secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -AsPlainText
                return $secret
            }
            catch {
                Write-Warning "Failed to resolve keyvault://$vaultName/$secretName — $_"
                return $Obj
            }
        }
        elseif ($Obj -is [System.Collections.IDictionary]) {
            $resolved = @{}
            foreach ($key in $Obj.Keys) {
                $resolved[$key] = Resolve-Recursive -Obj $Obj[$key]
            }
            return $resolved
        }
        elseif ($Obj -is [System.Collections.IList]) {
            $resolved = @()
            foreach ($item in $Obj) {
                $resolved += Resolve-Recursive -Obj $item
            }
            return $resolved
        }
        return $Obj
    }

    return Resolve-Recursive -Obj $Config
}

function Test-AVDConfigSchema {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [Parameter()]
        [string]$SchemaPath
    )

    if (-not $SchemaPath) {
        $SchemaPath = Join-Path (Split-Path (Split-Path $ConfigPath -Parent) -Parent) 'config\schema\variables.schema.json'
    }

    if (-not (Test-Path $SchemaPath)) {
        Write-Warning "Schema file not found: $SchemaPath — skipping validation."
        return $true
    }

    $config = Get-AVDConfig -ConfigPath $ConfigPath -ResolveSecrets $false
    $configJson = $config | ConvertTo-Json -Depth 20
    $schema = Get-Content -Path $SchemaPath -Raw

    # Basic structural validation (full JSON Schema validation requires additional tooling)
    $schemaObj = $schema | ConvertFrom-Json
    $requiredSections = $schemaObj.required

    foreach ($section in $requiredSections) {
        if (-not $config.ContainsKey($section)) {
            Write-Error "Missing required section: '$section'"
            return $false
        }
    }

    Write-Host "Configuration passes structural validation." -ForegroundColor Green
    return $true
}

<#
.SYNOPSIS
    Resolves a canonical variable path with alias fallback.

.DESCRIPTION
    Wraps Get-CanonicalVariable from the canonical module. Falls back to
    direct hashtable lookup if the canonical module is not available.

.PARAMETER Path
    Dot-notation path to resolve.

.PARAMETER Config
    Config hashtable to search (used as fallback when canonical module is unavailable).

.PARAMETER Default
    Default value if path not found.

.EXAMPLE
    $rg = Get-AVDCanonicalVariable -Path 'azure_platform.resource_groups.management' -Config $config
#>
function Get-AVDCanonicalVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [object]$Config,

        $Default = $null
    )

    if ($script:CanonicalAvailable) {
        $value = Get-CanonicalVariable -Path $Path -Default $null
        if ($null -ne $value) { return $value }
    }

    # Fallback: direct hashtable traversal
    if ($null -ne $Config) {
        $current = $Config
        foreach ($segment in $Path -split '\.') {
            if ($null -eq $current) { return $Default }
            if ($current -is [System.Collections.IDictionary] -and $current.Contains($segment)) {
                $current = $current[$segment]
            } else {
                return $Default
            }
        }
        return $current
    }

    return $Default
}
