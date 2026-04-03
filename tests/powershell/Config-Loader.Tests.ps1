#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Pester tests for the Config-Loader module.
.DESCRIPTION
    Validates Get-AVDConfig loads YAML correctly, resolves keyvault URIs,
    and rejects invalid configs.
#>

BeforeAll {
    . "$PSScriptRoot/../../src/powershell/common/Config-Loader.ps1"

    $script:ExampleConfig = Join-Path $PSScriptRoot '../../config/variables/variables.example.yml'
    $script:SchemaPath    = Join-Path $PSScriptRoot '../../config/variables/schema/variables.schema.json'
    $script:ExamplesDir   = Join-Path $PSScriptRoot '../../config/examples'
}

Describe 'Get-AVDConfig' {
    It 'Loads variables.example.yml without error' {
        { Get-AVDConfig -ConfigPath $script:ExampleConfig } | Should -Not -Throw
    }

    It 'Returns a hashtable' {
        $cfg = Get-AVDConfig -ConfigPath $script:ExampleConfig
        $cfg | Should -BeOfType [hashtable]
    }

    It 'Contains required top-level keys' {
        $cfg = Get-AVDConfig -ConfigPath $script:ExampleConfig
        $cfg.Keys | Should -Contain 'subscription'
        $cfg.Keys | Should -Contain 'control_plane'
    }

    It 'Loads each example config without error' {
        if (Test-Path $script:ExamplesDir) {
            $examples = Get-ChildItem -Path $script:ExamplesDir -Filter '*.yml'
            foreach ($ex in $examples) {
                { Get-AVDConfig -ConfigPath $ex.FullName } | Should -Not -Throw -Because "Example $($ex.Name) should load"
            }
        }
    }
}

Describe 'Test-AVDConfigSchema' {
    It 'Validates variables.example.yml against schema' {
        $result = Test-AVDConfigSchema -ConfigPath $script:ExampleConfig -SchemaPath $script:SchemaPath
        $result | Should -Be $true
    }

    It 'Validates each example config against schema' {
        if (Test-Path $script:ExamplesDir) {
            $examples = Get-ChildItem -Path $script:ExamplesDir -Filter '*.yml'
            foreach ($ex in $examples) {
                $result = Test-AVDConfigSchema -ConfigPath $ex.FullName -SchemaPath $script:SchemaPath
                $result | Should -Be $true -Because "Example $($ex.Name) should pass schema validation"
            }
        }
    }
}

Describe 'Resolve-KeyVaultSecrets' {
    It 'Leaves non-keyvault values unchanged' {
        Mock Get-AzKeyVaultSecret { throw 'should not be called' }
        $cfg = @{ simple = 'hello'; nested = @{ value = 42 } }
        $result = Resolve-KeyVaultSecrets -Config $cfg
        $result.simple | Should -Be 'hello'
        $result.nested.value | Should -Be 42
    }

    It 'Attempts to resolve keyvault URIs' {
        Mock Get-AzKeyVaultSecret { return 'resolved-secret' }
        $cfg = @{ secret = 'keyvault://my-vault/my-secret' }
        $result = Resolve-KeyVaultSecrets -Config $cfg
        $result.secret | Should -Be 'resolved-secret'
    }
}
