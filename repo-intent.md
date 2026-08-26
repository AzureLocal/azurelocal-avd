# Repo intent — azurelocal-avd

**IaC templates and automation for deploying Azure Virtual Desktop (AVD) on Azure Local.**

## What this repo is

Infrastructure-as-code and automation for deploying AVD on Azure Local (formerly
Azure Stack HCI).

## Shape

- `config/` — central variable reference (`variables.example.yml`)
- `src/bicep/` (recommended), `src/arm/`, `src/terraform/`, `src/powershell/`,
  `src/ansible/` — one IaC tool per folder, all targeting the same deployment
- `examples/pipelines/azure-devops/`, `examples/pipelines/github-actions/`
- `tests/` — validation scripts

## How it relates to other repos

- **`azurelocal-sofs-fslogix`** — the sister repo for the SOFS/FSLogix storage
  side of an AVD-on-Azure-Local deployment

## Status

Active, early — part of the broader AzureLocal toolkit family.
