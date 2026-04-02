<#
.SYNOPSIS
    Canonical Variable Reader for Azure Local Toolkit.

.DESCRIPTION
    Provides a standardized interface for reading variables from the canonical
    variables file (variables.yml) with alias resolution from the master registry.

    Key behaviors:
    - Loads variables.yml (falls back to variables.example.yml via bootstrap)
    - Builds an alias map from master-registry.yaml (alias_for metadata)
    - Resolves dotted paths with alias fallback during migration window
    - Fail-fast on missing required values

.NOTES
    Requires powershell-yaml module: Install-Module powershell-yaml -Scope CurrentUser

.EXAMPLE
    Import-Module .\CanonicalVariable.psm1
    Initialize-CanonicalVariables
    $tenantId = Get-CanonicalVariable -Path "identity.azure_tenant_id"
    Test-RequiredCanonicalVariables -Paths @("identity.azure_tenant_id", "security.keyvault_name") -ScriptName "Deploy.ps1"
#>

#Requires -Version 7.0

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    throw "powershell-yaml module not found. Install with: Install-Module powershell-yaml -Scope CurrentUser"
}

Import-Module powershell-yaml -ErrorAction Stop

# ── Module state ──
$script:Variables = $null
$script:AliasMap = $null   # alias_path → canonical_path
$script:Initialized = $false
$script:VariablesPath = $null
$script:RegistryPath = $null

<#
.SYNOPSIS
    Initializes the canonical variable reader.

.DESCRIPTION
    Loads the variables file and master registry, then builds the alias map.
    Must be called before any other functions in this module.

.PARAMETER VariablesPath
    Path to variables.yml. Defaults to config/variables/variables.yml (or .example.yml fallback).

.PARAMETER RegistryPath
    Path to master-registry.yaml. Defaults to config/variables/schema/master-registry.yaml.

.PARAMETER Force
    Force re-initialization even if already initialized.
#>
function Initialize-CanonicalVariables {
    [CmdletBinding()]
    param(
        [string]$VariablesPath,
        [string]$RegistryPath,
        [switch]$Force
    )

    if ($script:Initialized -and -not $Force) {
        return
    }

    # Resolve repo root from this script's location
    $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
    $configBase = Join-Path $repoRoot "config" "variables"

    # Resolve variables path with bootstrap fallback
    if (-not $VariablesPath) {
        $primary = Join-Path $configBase "variables.yml"
        $fallback = Join-Path $configBase "variables.example.yml"
        if (Test-Path $primary) {
            $VariablesPath = $primary
        } elseif (Test-Path $fallback) {
            $VariablesPath = $fallback
            Write-Warning "Using variables.example.yml (bootstrap fallback). Copy to variables.yml for deployment use."
        } else {
            throw "No variables file found at $primary or $fallback"
        }
    }

    if (-not $RegistryPath) {
        $RegistryPath = Join-Path $configBase "schema" "master-registry.yaml"
    }

    foreach ($p in @($VariablesPath, $RegistryPath)) {
        if (-not (Test-Path $p)) {
            throw "Required file not found: $p"
        }
    }

    $script:Variables = Get-Content -Raw $VariablesPath | ConvertFrom-Yaml -Ordered
    $script:VariablesPath = $VariablesPath
    $script:RegistryPath = $RegistryPath

    # Build alias map by scanning registry YAML lines
    # (text-based to avoid ConvertFrom-Yaml choking on duplicate keys in the registry)
    $script:AliasMap = @{}
    Build-AliasMapFromText -RegistryFile $RegistryPath

    $script:Initialized = $true
    Write-Verbose "Canonical variables initialized: $($script:AliasMap.Count) aliases loaded from registry."
}

# Extract alias_for entries from registry using Python (fast YAML parsing).
# Falls back to text-based scan if Python is unavailable.
function Build-AliasMapFromText {
    param([string]$RegistryFile)

    # Use Python for fast extraction
    $pyScript = @"
import yaml, json, sys
def extract_aliases(node, path=""):
    if not isinstance(node, dict): return {}
    result = {}
    for k, v in node.items():
        if k in ("_meta", "infrastructure_type"): continue
        cp = f"{path}.{k}" if path else k
        if isinstance(v, dict):
            if "alias_for" in v:
                result[cp] = str(v["alias_for"])
            result.update(extract_aliases(v, cp))
    return result
with open(sys.argv[1], encoding="utf-8") as f:
    reg = yaml.safe_load(f)
print(json.dumps(extract_aliases(reg or {})))
"@

    try {
        $result = python -c $pyScript $RegistryFile 2>&1
        if ($LASTEXITCODE -eq 0 -and $result) {
            $map = $result | ConvertFrom-Json -AsHashtable
            foreach ($k in $map.Keys) {
                $script:AliasMap[$k] = $map[$k]
            }
            return
        }
    } catch {
        Write-Verbose "Python alias extraction failed, using text scanner: $_"
    }

    # Fallback: regex-based line scan (slower but no Python dependency)
    $content = Get-Content $RegistryFile -Raw -Encoding utf8
    $aliasLines = [regex]::Matches($content, '(?m)^(\s+)alias_for:\s*(.+)$')

    foreach ($match in $aliasLines) {
        $aliasIndent = $match.Groups[1].Value.Length
        $target = $match.Groups[2].Value.Trim() -replace '^["'']|["'']$', ''
        $lineStart = $match.Index

        # Walk backwards to build path from indent hierarchy
        $pathParts = @()
        $currentIndent = $aliasIndent
        $searchPos = $lineStart

        while ($searchPos -gt 0 -and $currentIndent -gt 0) {
            $searchPos = $content.LastIndexOf("`n", $searchPos - 1)
            if ($searchPos -lt 0) { break }
            $lineEnd = $content.IndexOf("`n", $searchPos + 1)
            if ($lineEnd -lt 0) { $lineEnd = $content.Length }
            $line = $content.Substring($searchPos + 1, $lineEnd - $searchPos - 1)

            if ($line -match '^(\s*)(\S+):\s*') {
                $ind = $Matches[1].Length
                if ($ind -lt $currentIndent) {
                    $pathParts = @($Matches[2]) + $pathParts
                    $currentIndent = $ind
                }
            }
        }

        if ($pathParts.Count -gt 0 -and $target) {
            $aliasPath = $pathParts -join '.'
            $script:AliasMap[$aliasPath] = $target
        }
    }
}

<#
.SYNOPSIS
    Resolves a dotted path to a value from the canonical variables file.

.DESCRIPTION
    Navigates the variables hashtable using dot notation. Supports array
    indexing with [n]. If the path is not found directly, checks the alias
    map and retries with the canonical path.

.PARAMETER Path
    Dot-notation path (e.g., "identity.azure_tenant_id" or "compute.cluster_nodes[0].hostname").

.PARAMETER Default
    Value to return if the path does not exist. Defaults to $null.

.EXAMPLE
    $tenantId = Get-CanonicalVariable -Path "identity.azure_tenant_id"
    $node0 = Get-CanonicalVariable -Path "compute.cluster_nodes[0].hostname" -Default "unknown"
#>
function Get-CanonicalVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        $Default = $null
    )

    Assert-Initialized

    # Try direct path first
    $value = Resolve-DottedPath -Object $script:Variables -Path $Path
    if ($null -ne $value) {
        return $value
    }

    # Try alias resolution
    if ($script:AliasMap.ContainsKey($Path)) {
        $canonicalPath = $script:AliasMap[$Path]
        Write-Verbose "Alias resolved: $Path → $canonicalPath"
        $value = Resolve-DottedPath -Object $script:Variables -Path $canonicalPath
        if ($null -ne $value) {
            return $value
        }
    }

    return $Default
}

<#
.SYNOPSIS
    Tests whether a dotted path exists in the canonical variables.

.PARAMETER Path
    Dot-notation path to test.
#>
function Test-CanonicalVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $value = Get-CanonicalVariable -Path $Path
    return ($null -ne $value)
}

<#
.SYNOPSIS
    Validates that all required paths exist. Throws on any missing path.

.DESCRIPTION
    Checks each path in the list and collects missing ones. If any are
    missing, throws a terminating error with the full list. This is the
    fail-fast contract for consumer scripts.

.PARAMETER Paths
    Array of required dotted paths.

.PARAMETER ScriptName
    Name of the calling script (for error messages).

.EXAMPLE
    Test-RequiredCanonicalVariables -Paths @(
        "identity.azure_tenant_id",
        "security.keyvault_name"
    ) -ScriptName "Deploy-AVD.ps1"
#>
function Test-RequiredCanonicalVariables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Paths,

        [Parameter(Mandatory)]
        [string]$ScriptName
    )

    Assert-Initialized

    $missing = @()
    foreach ($p in $Paths) {
        if (-not (Test-CanonicalVariable -Path $p)) {
            $missing += $p
        }
    }

    if ($missing.Count -gt 0) {
        $list = $missing -join "`n  - "
        throw "[$ScriptName] Missing required canonical variables:`n  - $list`nVariables file: $($script:VariablesPath)"
    }
}

<#
.SYNOPSIS
    Returns the alias map built from the master registry.

.DESCRIPTION
    Returns a hashtable mapping alias paths to their canonical target paths.
    Useful for debugging and migration tooling.
#>
function Get-CanonicalAliasMap {
    [CmdletBinding()]
    param()

    Assert-Initialized
    return $script:AliasMap.Clone()
}

# ── Internal helpers ──

function Assert-Initialized {
    if (-not $script:Initialized) {
        throw "Canonical variables not initialized. Call Initialize-CanonicalVariables first."
    }
}

function Resolve-DottedPath {
    param(
        $Object,
        [string]$Path
    )

    $current = $Object
    $segments = Parse-PathSegments -Path $Path

    foreach ($seg in $segments) {
        if ($null -eq $current) { return $null }

        if ($current -is [hashtable] -or $current -is [System.Collections.Specialized.OrderedDictionary]) {
            if ($current.Contains($seg.Key)) {
                $current = $current[$seg.Key]
            } else {
                return $null
            }
        } else {
            return $null
        }

        if ($null -ne $seg.Index) {
            if ($current -is [System.Collections.IEnumerable] -and $current -isnot [string]) {
                $arr = @($current)
                if ($seg.Index -lt $arr.Count) {
                    $current = $arr[$seg.Index]
                } else {
                    return $null
                }
            } else {
                return $null
            }
        }
    }

    return $current
}

function Parse-PathSegments {
    param([string]$Path)

    $segments = @()
    $remaining = $Path

    while ($remaining) {
        if ($remaining -match '^([^\.\[]+)(?:\[(\d+)\])?(?:\.(.*))?$') {
            $segments += [PSCustomObject]@{
                Key   = $Matches[1]
                Index = if ($Matches[2]) { [int]$Matches[2] } else { $null }
            }
            $remaining = $Matches[3]
        } else {
            break
        }
    }

    return $segments
}

Export-ModuleMember -Function @(
    'Initialize-CanonicalVariables',
    'Get-CanonicalVariable',
    'Test-CanonicalVariable',
    'Test-RequiredCanonicalVariables',
    'Get-CanonicalAliasMap'
)
