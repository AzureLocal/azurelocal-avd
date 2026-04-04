# Automation

Documents every GitHub Actions workflow in this repository.

---

## Workflow Summary

| File | Name | Trigger | Purpose |
|------|------|---------|---------|
| `add-to-project.yml` | Add to Project | Issues/PRs opened or labeled | Adds items to org project board and sets custom fields |
| `ci-ansible.yml` | CI — Ansible Lint | Push/PR touching `src/ansible/**` | Lints and syntax-checks Ansible playbooks |
| `ci-bicep.yml` | CI — Bicep Build | Push/PR touching `src/bicep/**` | Builds and lints Bicep templates |
| `ci-config-schema.yml` | CI — Config Schema Validation | Push/PR touching `config/**` | Validates example config files against JSON Schema |
| `ci-powershell.yml` | CI — PowerShell Lint | Push/PR touching `src/powershell/**` | PSScriptAnalyzer + Pester tests |
| `ci-terraform.yml` | CI — Terraform Validate | Push/PR touching `src/terraform/**` | Terraform fmt + validate + TFLint |
| `deploy-docs.yml` | Deploy Documentation | Push to `main` touching `docs/**` or `mkdocs.yml` | Builds MkDocs site and deploys to GitHub Pages |
| `release-please.yml` | Release Please | Push to `main` | Automates CHANGELOG and releases |
| `validate-automation.yml` | Validate Automation Contracts | Push/PR touching `config/**`, `src/**`, `tests/**` | Validates config and runs contract Pester tests |
| `validate-config.yml` | Validate Configuration | Push/PR touching `config/**` | Validates YAML syntax and JSON Schema compliance |
| `validate-repo-structure.yml` | Validate Repo Structure | PR to `main` | Checks required files and directories are present |

---

## add-to-project.yml

**Trigger:** `issues` (opened, labeled) and `pull_request` (opened, labeled)  
**Secrets:** `ADD_TO_PROJECT_PAT`

Two-job pipeline:

1. **add-to-project** — Uses `actions/add-to-project@v1.0.2` to add the item to org project board (`AzureLocal/projects/3`). Outputs the item ID.
2. **set-fields** (issues only) — Uses `gh project item-edit` to set:
   - **ID field** — text value `AVD-{issue_number}`
   - **Solution field** — maps `solution/*` label to a project board single-select option
   - **Priority field** — maps `priority/*` label (`critical`/`high`/`medium`/`low`)
   - **Category field** — maps `type/*` label (`feature`/`bug`/`docs`/`infra`/`refactor`/`security`)

---

## ci-ansible.yml

**Trigger:** Push to `main` or PR touching `src/ansible/**`  
**Runner:** `ubuntu-latest`

1. Sets up Python 3.11
2. Installs `ansible-core`, `ansible-lint`, `yamllint`
3. Runs `yamllint -d relaxed src/ansible/`
4. Runs `ansible-playbook src/ansible/playbooks/site.yml --syntax-check`
5. Runs `ansible-lint src/ansible/`

**Notes:** Fails on any Ansible lint error or YAML syntax issue. Does not deploy — validation only.

---

## ci-bicep.yml

**Trigger:** Push to `main` or PR touching `src/bicep/**`  
**Runner:** `ubuntu-latest`

1. Uses `azure/CLI@v2` to build every `*.bicep` file in `src/bicep/` with `az bicep build --stdout`
2. Uses `azure/CLI@v2` to lint every `*.bicep` file with `az bicep lint`

**Notes:** No Azure credentials required — build/lint is local only, no ARM deployment.

---

## ci-config-schema.yml

**Trigger:** Push to `main` or PR touching `config/**`  
**Runner:** `ubuntu-latest`

1. Sets up Python 3.11
2. Installs `jsonschema`, `pyyaml`
3. Loads `config/variables/schema/variables.schema.json`
4. Validates every `*.yml` in `config/examples/` against the schema

**Notes:** If `config/examples/` is empty, the check passes with a skip message.

---

## ci-powershell.yml

**Trigger:** Push to `main` or PR touching `src/powershell/**` or `.github/workflows/ci-powershell.yml`; manual via `workflow_dispatch`  
**Runner:** `ubuntu-latest`

Two parallel jobs:

**psscriptanalyzer:**
1. Installs PSScriptAnalyzer
2. Runs `Invoke-ScriptAnalyzer -Path src/powershell -Recurse -Settings PSGallery -Severity Warning,Error`
3. Fails if any `Error`-severity rule violations are found

**pester:**
1. Installs Pester 5 and `powershell-yaml`
2. Runs all tests in `tests/powershell/` with JUnit XML output

---

## ci-terraform.yml

**Trigger:** Push to `main` or PR touching `src/terraform/**`  
**Runner:** `ubuntu-latest`

Two parallel jobs:

**terraform-validate:**
1. Sets up Terraform 1.5.0
2. `terraform fmt -check -recursive` — fails if formatting is off
3. `terraform init -backend=false`
4. `terraform validate`

**tflint:**
1. Sets up TFLint with `terraform-linters/setup-tflint@v4`
2. `tflint --init`
3. `tflint --format compact`

---

## deploy-docs.yml

**Trigger:** Push to `main` touching `docs/**` or `mkdocs.yml`  
**Permissions:** `contents: read`, `pages: write`, `id-token: write`  
**Concurrency group:** `pages` (cancel-in-progress: false)

Two-job pipeline:

**build:**
1. Sets up Python 3.12
2. Installs `mkdocs-material` and `mkdocs-drawio`
3. `mkdocs build --strict` — fails on any warning
4. Uploads `site/` as a pages artifact

**deploy:**
1. Uses `actions/deploy-pages@v4` to publish to GitHub Pages

---

## release-please.yml

**Trigger:** Push to `main`  
**Permissions:** `contents: write`, `pull-requests: write`

Uses `googleapis/release-please-action@v4`. When conventional commits land on `main`, it creates/updates a release PR with updated `CHANGELOG.md` and version bump. When that PR is merged, it creates the GitHub release and tag.

Configuration is in `release-please-config.json` at repo root.

---

## validate-automation.yml

**Trigger:** Push to `main` or PR touching `config/**`, `src/**`, or `tests/**`; manual via `workflow_dispatch`

Two parallel jobs:

**contract-validation** (Ubuntu):
1. Sets up Python 3.12
2. Installs `pyyaml`, `jsonschema`
3. Runs `python3 scripts/validate-config.py` (canonical config validation)

**pester-validation** (Windows):
1. Installs Pester
2. Runs `tests/Test-AVDDeployment.Tests.ps1` with `-CI` flag (fails on any test failure)

> **Note:** This workflow has pre-existing failures due to `scripts/validate-config.py` — do not treat as a regression if it fails on main.

---

## validate-config.yml

**Trigger:** Push to `main` or PR touching `config/**`; manual via `workflow_dispatch`

1. Sets up Python 3.12
2. Installs `pyyaml`, `jsonschema`
3. Runs `python3 scripts/validate-config.py`
4. Runs negative schema fixture test — validates that files matching `tests/schemas/invalid-*.yml` correctly **fail** schema validation (if any exist)

---

## validate-repo-structure.yml

**Trigger:** PR to `main`

Checks that required files and directories are present.

| Check | Required Items |
|-------|---------------|
| Root files | `README.md`, `CONTRIBUTING.md`, `LICENSE`, `CHANGELOG.md`, `.gitignore` |
| Directories | `docs/`, `.github/` |
| PR template | `.github/PULL_REQUEST_TEMPLATE.md` |
| Config structure (if `config/` exists) | `config/variables.example.yml`, `config/schema/variables.schema.json` |
