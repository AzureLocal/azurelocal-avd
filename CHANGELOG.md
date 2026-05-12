# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 1.0.0 (2026-05-12)


### Features

* add correctly named icon SVG, banner SVG, and update docs home page ([ebbbc5a](https://github.com/AzureLocal/azurelocal-avd/commit/ebbbc5a6d5bde4e0425f6b6c1e7f19777e4f1290)), closes [#45](https://github.com/AzureLocal/azurelocal-avd/issues/45)
* add unique project ID field automation (AVD-N prefix) ([d86400c](https://github.com/AzureLocal/azurelocal-avd/commit/d86400c7625aa97c7ba553fe237e04092b7167ea))
* **epic-8:** complete AVD full automation build-out ([b64cdb8](https://github.com/AzureLocal/azurelocal-avd/commit/b64cdb882cd2730567039b7375022fd1b8b12db4))
* **epic-8:** complete AVD full automation build-out ([8b24c59](https://github.com/AzureLocal/azurelocal-avd/commit/8b24c59665a3172e1b0857254f1e8252a1e89955))
* GitHub Project & Repo Standardization (Plan 1) ([b19d67e](https://github.com/AzureLocal/azurelocal-avd/commit/b19d67ec53c8e697e012e8715eef1f68bf323a01))
* implement Epic [#8](https://github.com/AzureLocal/azurelocal-avd/issues/8) — AVD full automation (Sub-Tasks 1-12) ([cb9c7f3](https://github.com/AzureLocal/azurelocal-avd/commit/cb9c7f359517f550e121b2622bf1dada91c78c85))
* integrate AVD deployment code and restructure repository ([335000c](https://github.com/AzureLocal/azurelocal-avd/commit/335000c676927427155a7e1cc48496fe379ee10f))


### Bug Fixes

* add missing diagram PNG exports ([3b82868](https://github.com/AzureLocal/azurelocal-avd/commit/3b828688c0674f255585e0ce0ae33770c951369a))
* add reopened trigger to add-to-project workflow ([c3821d4](https://github.com/AzureLocal/azurelocal-avd/commit/c3821d4f39e0a02a3a4218b39923ebea7d475d8f))
* address plan verification gaps ([32d0d8a](https://github.com/AzureLocal/azurelocal-avd/commit/32d0d8a2ba1814a8c3575167f18ac8d36e537c31))
* correct AVD Private Endpoints for Azure Local hybrid architecture ([4806d21](https://github.com/AzureLocal/azurelocal-avd/commit/4806d21bd190fa7ada2258d250e3fdd911620bb4))
* correct Azure Local identity constraints and FSLogix topology accuracy ([6b71389](https://github.com/AzureLocal/azurelocal-avd/commit/6b713895ecadd923d23755d7103712aa206715ba))
* make set-fields resilient to add-to-project failures ([cc2cda1](https://github.com/AzureLocal/azurelocal-avd/commit/cc2cda1f79129715a95dea1bab6d35dbb5105686))
* pin actions/add-to-project to v1.0.2 ([1bc6e98](https://github.com/AzureLocal/azurelocal-avd/commit/1bc6e98e470984c21baa820646c3e67cff0e03fc))
* remove invalid sitemap plugin, move gtag to preset options ([a9c9225](https://github.com/AzureLocal/azurelocal-avd/commit/a9c9225a2c5a111f3b1912342ab333315a419911))
* remove unsupported hashFiles condition from powershell workflow ([e75e3f2](https://github.com/AzureLocal/azurelocal-avd/commit/e75e3f209cddbd10568f5c602159ad3338a291a7))
* repair docs and validation workflows ([5f2253f](https://github.com/AzureLocal/azurelocal-avd/commit/5f2253f08702d53bdf3ab34fefba4f17872b49bf))
* repair remaining config validation workflow paths ([250c543](https://github.com/AzureLocal/azurelocal-avd/commit/250c543d61df19fbe5d813826ede3b34bc926f7f))
* repair stale config paths in CI workflows and Pester tests ([9530fd8](https://github.com/AzureLocal/azurelocal-avd/commit/9530fd829fb6958c9c5472f340337f8ebba9acd7))
* **standards:** update canonical path to docs/standards/ in platform ([839a59f](https://github.com/AzureLocal/azurelocal-avd/commit/839a59f3a812b8daa478b1d38df6bb141aa193f4))
* update Solution field option IDs after Toolkit option added to Project [#3](https://github.com/AzureLocal/azurelocal-avd/issues/3) ([ae3acfe](https://github.com/AzureLocal/azurelocal-avd/commit/ae3acfe8ac8aa7decae66b49c549703841fce7a2))
* use action output for item ID, fix stale solution field option IDs ([b642409](https://github.com/AzureLocal/azurelocal-avd/commit/b6424098391b40686adeda8ef7cc926e1bf14918))

## [Unreleased]

### Features

- Initial Azure Virtual Desktop on Azure Local solution structure
- Terraform, Bicep, ARM, and PowerShell deployment options
- MkDocs documentation site

### Infrastructure

- Add GitHub Actions deploy-docs workflow
- Add issue and PR templates
- Add CONTRIBUTING.md and LICENSE
