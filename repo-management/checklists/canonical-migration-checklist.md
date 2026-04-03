# Canonical Variable Migration Checklist — azurelocal-avd

## Status: Wave 1

## Prerequisites
- [x] CanonicalVariable.psm1 deployed to `src/powershell/common/`
- [ ] Validate `config/variables.example.yml` against canonical schema
- [ ] Confirm CI pipeline passes with no regressions

## Migration Steps

### Step 1: Integration Wrapper
Update `src/powershell/common/Config-Loader.ps1` to optionally use `CanonicalVariable.psm1`:
- Import `CanonicalVariable.psm1` alongside existing `Get-AVDConfig`
- Add `Get-CanonicalVariable` calls as fallback for path lookups
- Preserve `Resolve-KeyVaultSecrets` behavior (not in canonical module)

### Step 2: Script-by-Script Migration (13 scripts)

| Script | Complexity | Status |
|--------|-----------|--------|
| Configure-AVDIdentity.ps1 | Medium — uses `$config.identity.*`, `$config.avd.*` | [ ] |
| Configure-AVDNetworking.ps1 | Medium — uses `$config.networking.*`, `$config.subscription.*` | [ ] |
| Configure-FSLogix.ps1 | Low — uses `$config.fslogix.*` | [ ] |
| Deploy-AVDMonitoring.ps1 | Low — uses `$config.azure.*` | [ ] |
| Deploy-AVDScaling.ps1 | Low — standard pattern | [ ] |
| Test-AVDDeployment.ps1 | Low — validation only | [ ] |
| Remove-AVDDeployment.ps1 | Low — teardown | [ ] |
| New-FSLogixShare.ps1 | Medium — FSLogix storage config | [ ] |
| New-AVDImage.ps1 | Medium — image management | [ ] |
| Import-AVDConfig.ps1 | Low — direct ConvertFrom-Yaml | [ ] |
| Test-AVDConfig.ps1 | Low — direct ConvertFrom-Yaml | [ ] |
| Deploy-AVDSessionHosts-ARM.ps1 | High — bootstrap + inline loading | [ ] |
| validate-config.py | Low — Python yaml.safe_load | [ ] |

### Step 3: Variable Path Mapping
Key paths used in AVD scripts → canonical equivalents:

| Legacy AVD Path | Canonical Path |
|----------------|---------------|
| `$config.azure.resource_group` | `azure_platform.resource_groups.management` |
| `$config.azure.location` | `azure_platform.location` |
| `$config.azure.subscription_id` | `azure_platform.subscription_id` |
| `$config.identity.*` | `identity.*` (already canonical) |
| `$config.avd.*` | `compute.avd.*` |
| `$config.networking.*` | `networking.*` (already canonical) |
| `$config.fslogix.*` | `storage.fslogix.*` |
| `$config.session_hosts.*` | `compute.avd.session_hosts.*` |
| `$config.control_plane.*` | `compute.avd.control_plane.*` |
| `$config.monitoring.*` | `operations.monitoring.*` |
| `$config.scaling.*` | `compute.avd.scaling.*` |

### Step 4: Validation Gate
- [ ] Run canonical schema validator against `config/variables.example.yml`
- [ ] Confirm zero unknown paths
- [ ] Add CI check to `.github/workflows/`

### Step 5: Regression Testing
- [ ] Test all 13 scripts in dry-run mode
- [ ] Confirm keyvault:// resolution still works
- [ ] Confirm no behavior change in deployment scenarios

## Notes
- The `Resolve-KeyVaultSecrets` function in Config-Loader.ps1 is AVD-specific and must be preserved
- Python script `validate-config.py` can use `canonical_variables.py` from toolkit
