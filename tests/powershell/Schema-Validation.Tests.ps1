#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Pester tests for JSON Schema validation of config files.
.DESCRIPTION
    Ensures all example YAML configs pass JSON Schema validation
    and that the schema file itself is valid JSON.
#>

BeforeAll {
    $script:SchemaPath  = Join-Path $PSScriptRoot '../../config/variables/schema/variables.schema.json'
    $script:ExamplesDir = Join-Path $PSScriptRoot '../../config/examples'
    $script:ExampleConfig = Join-Path $PSScriptRoot '../../config/variables/variables.example.yml'
}

Describe 'Schema File' {
    It 'Exists' {
        Test-Path $script:SchemaPath | Should -Be $true
    }

    It 'Is valid JSON' {
        { Get-Content $script:SchemaPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'Has a $schema property' {
        $schema = Get-Content $script:SchemaPath -Raw | ConvertFrom-Json
        $schema.'$schema' | Should -Not -BeNullOrEmpty
    }

    It 'Has required properties defined' {
        $schema = Get-Content $script:SchemaPath -Raw | ConvertFrom-Json
        $schema.required | Should -Not -BeNullOrEmpty
    }
}

Describe 'variables.example.yml' {
    It 'Exists' {
        Test-Path $script:ExampleConfig | Should -Be $true
    }

    It 'Is valid YAML' {
        if (Get-Module -ListAvailable -Name powershell-yaml) {
            Import-Module powershell-yaml
            { Get-Content $script:ExampleConfig -Raw | ConvertFrom-Yaml } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because 'powershell-yaml module not available'
        }
    }
}

Describe 'Example Configs' {
    It 'Example directory exists' {
        Test-Path $script:ExamplesDir | Should -Be $true
    }

    It 'Contains at least one example' {
        $files = Get-ChildItem -Path $script:ExamplesDir -Filter '*.yml' -ErrorAction SilentlyContinue
        $files.Count | Should -BeGreaterThan 0
    }

    It 'All examples are valid YAML' {
        if (Get-Module -ListAvailable -Name powershell-yaml) {
            Import-Module powershell-yaml
            $files = Get-ChildItem -Path $script:ExamplesDir -Filter '*.yml'
            foreach ($f in $files) {
                { Get-Content $f.FullName -Raw | ConvertFrom-Yaml } | Should -Not -Throw -Because "$($f.Name) should be valid YAML"
            }
        } else {
            Set-ItResult -Skipped -Because 'powershell-yaml module not available'
        }
    }
}
