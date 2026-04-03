# Variable Standards

> **Canonical reference:** [Variable Management Standard](https://azurelocal.cloud/standards/variable-management/)  
> **Full variable catalog:** [Variable Reference](../reference/variables.md)  
> **Last Updated:** 2026-03-17

---

## Overview

This repository uses a **single central configuration file** — `config/variables.yml` — as the source of truth for all deployment automation. Copy from `config/variables.example.yml` to get started.

---

## Naming Rules

| Rule | Standard | Example |
|------|----------|--------|
| Top-level sections | `snake_case` | `azure_local`, `networking` |
| Keys within sections | `snake_case` | `subscription_id`, `resource_name` |
| Pattern | `^[a-z][a-z0-9_]*$` | — |
| Max length | 50 characters | — |
| Booleans | Descriptive names | `monitoring_enabled: true` |
| Secrets | `keyvault://` URI format | `keyvault://kv-iic-platform/admin-password` |

---

## Config File Structure

```
config/
├── variables.example.yml        # Template with IIC examples (committed)
├── variables.yml                # Your actual config (gitignored)
└── schema/
    └── variables.schema.json    # JSON Schema for CI validation
```

---

## Key Vault Resolution

Secrets are never stored in plaintext:

```yaml
security:
  admin_password: "keyvault://kv-iic-platform/admin-password"
  domain_join_password: "keyvault://kv-iic-platform/domain-join"
```

---

## CI Validation

Every PR validates `config/variables.example.yml` against `config/schema/variables.schema.json` using the `validate-config.yml` workflow.

---

## Detailed Reference

For the complete variable catalog see:

- **[Variable Reference](../reference/variables.md)** — per-variable documentation
- **[Variable Management Standard](https://azurelocal.cloud/docs/implementation/04-variable-management-standard)** — org-wide governance
- **[Variable Management Suite](https://azurelocal.cloud/standards/variable-management/)** — registry, schema validation, workflows
- Tool-specific parameter mapping