# MCP servers

<!--
  Human-readable inventory of the MCP servers this repo uses and what each is for.
  Never contains connection secrets — per-tool config files hold the wiring.
-->

## HCS Governance MCP

- **Purpose:** source of truth for standards, hard rules, scope resolution, orchestration guidance, and the auth broker.
- **Endpoint:** `https://mcp.hybridsolutions.cloud/mcp`
- **Transport:** Streamable HTTP (remote)
- **Auth:** OAuth 2.1 brokered to Microsoft Entra; members of `sg-hcs-mcp-users` only. Clients prompt for Entra sign-in on first connect.
- **Bootstrap:** call `bootstrap(repo="azurelocal-avd", client="<your client>")` at session start.
- **Per-tool config:** `.mcp.json` (Claude Code), `.codex/config.toml` (Codex), `.gemini/settings.json` (Gemini), `.cursor/mcp.json` (Cursor), `.vscode/mcp.json` (VS Code Copilot).

<!-- Add any additional MCP servers this repo uses below. -->
