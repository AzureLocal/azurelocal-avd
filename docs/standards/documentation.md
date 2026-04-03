# Documentation Standards

> **Canonical reference:** [Documentation Standards (full)](https://azurelocal.cloud/standards/documentation/documentation-standards)  
> **Applies to:** All AzureLocal repositories  
> **Last Updated:** 2026-03-17

---

## Principles

| Principle | Rule |
|-----------|------|
| Documentation-First | Document **before** implementing. Keep docs current with code. |
| Single Source of Truth | One authoritative document per topic. Cross-reference, don't duplicate. |
| Audience-Aware | Write for operators, developers, or executives — with appropriate depth. |
| Actionable | Step-by-step procedures, examples, prerequisites, and outcomes. |

---

## File Naming

| Type | Convention | Pattern | Example |
|------|-----------|---------|---------|
| Directories | lowercase-with-hyphens | `^[a-z][a-z0-9-]*$` | `guides/`, `reference/` |
| Markdown (docs/) | lowercase with hyphens | `*.md` | `deployment-guide.md` |
| Root files | UPPERCASE | — | `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md` |
| PowerShell scripts | PascalCase | `Verb-Noun.ps1` | `Deploy-Solution.ps1` |
| Config files | lowercase-with-hyphens | — | `variables.example.yml` |

---

## MkDocs Material Conventions

This repo uses **MkDocs Material** with the following conventions:

- **Admonitions**: Use `!!! note`, `!!! warning`, `!!! danger`, `!!! info`, `!!! tip`
- **Code blocks**: Always include a language identifier (e.g., ` ```powershell `, ` ```yaml `)
- **Code copy**: Enabled via `content.code.copy`
- **Mermaid diagrams**: Supported via `pymdownx.superfences` custom fence
- **Tables**: Use standard Markdown tables
- **Tabs**: Use `=== "Tab Name"` via `pymdownx.tabbed`

---

## Frontmatter & Metadata

Every documentation page should include:

```markdown
# Page Title

> Brief one-line description of the page's purpose.

---
```

---

## Fictional Company — Contoso (IIC)

All examples must use IIC. See the [Examples & IIC Policy](examples.md) page for the full reference card.

| Never Use | Use Instead |
|-----------|-------------|
| `contoso`, `fabrikam`, `northwind` | Contoso |
| `example.com`, `test.com` | `contoso.cloud` |
| Real customer names | IIC naming patterns |

---

## Related Standards

- [Naming Conventions (full reference)](https://azurelocal.cloud/standards/documentation/naming-conventions)
- [Badge Library](https://azurelocal.cloud/standards/documentation/badge-library)
- [Scripting Standards](scripting.md)