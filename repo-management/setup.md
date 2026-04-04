# Repository Setup

Documents how this repository is configured. Use this as the reference when setting up a new repo or auditing existing settings.

---

## Branch Protection

**Protected branch:** `main`

| Setting | Value |
|---------|-------|
| Require pull request before merging | Yes |
| Required approvals | 1 |
| Dismiss stale reviews on new commits | Yes |
| Require status checks to pass | Yes |
| Required checks | `check-structure` (validate-repo-structure) |
| Require branches to be up to date | Yes |
| Restrict force pushes | Yes |
| Allow admins to bypass | Yes |

---

## Labels

Labels are defined in `azurelocal.github.io/.github/labels.yml` — that is the source of truth for all repos. Labels are applied to this repo when they change in the source repo or manually via `workflow_dispatch` on the `sync-labels.yml` workflow in `azurelocal.github.io`.

---

## Secrets

| Secret | Used By | Description |
|--------|---------|-------------|
| `ADD_TO_PROJECT_PAT` | `add-to-project.yml` | Classic PAT with `project` scope. Required for org-level project board access. |
| `GITHUB_TOKEN` | All other workflows | Built-in GitHub token. |

---

## CODEOWNERS

Defined in `.github/CODEOWNERS`. Review and update if team membership changes.

---

## GitHub Pages

| Setting | Value |
|---------|-------|
| Source | GitHub Actions (uses `actions/deploy-pages`) |
| Build tool | MkDocs Material |
| Deploy trigger | Push to `main` touching `docs/` or `mkdocs.yml` |

---

## Replication Checklist

- [ ] Add `ADD_TO_PROJECT_PAT` secret (org PAT, `project` scope)
- [ ] Enable branch protection on `main` per settings above
- [ ] Add `.github/CODEOWNERS`
- [ ] Add `.github/PULL_REQUEST_TEMPLATE.md`
- [ ] Copy `add-to-project.yml` — update the ID prefix (`AVD-$NUMBER`) to match new repo
- [ ] Copy `release-please.yml` and `release-please-config.json`
- [ ] Copy `validate-repo-structure.yml` — adjust required dirs
- [ ] Copy `deploy-docs.yml` if repo has docs
- [ ] Copy CI workflows that match the languages used
- [ ] Enable GitHub Pages (Settings → Pages → Source: GitHub Actions)
