# Agents Fleet

Personal-project agents, skills, and instructions for GitHub Copilot.
See the [fleet catalog](.github/README.md) for specialist roles and routing.

## Mantine frontend skills

- [frontend-engineer](.github/agents/frontend-engineer.agent.md) loads matching bundled Mantine skills on demand.
- [Combobox](.github/skills/mantine-combobox/SKILL.md): custom select-like components.
- [Forms](.github/skills/mantine-form/SKILL.md): validation, nested fields, and form context.
- [Custom components](.github/skills/mantine-custom-components/SKILL.md): theming and Styles API.
- Skills target Mantine 9.x; existing projects keep their UI library and dependency versions.
- [Sources, Node recommendation, refresh, and checks](.github/skills/mantine-upstream.md).

## Optional Azure tooling

[.mcp.json](.mcp.json) configures the public Azure MCP server.
[Workspace settings](.vscode/settings.json) enable workspace-root MCP
configuration discovery. Requires Node.js and `npx`.

Review server trust prompts and authenticate to your own Azure account
only when a task requires it. Existing user-profile MCP configuration
is unchanged. Agent tool allowlists do not install servers.

## Publishing

Review repository contents and Git history before sharing. Removing
files on a branch does not remove their contents from earlier commits,
other branches, or local stashes. Publish from a clean-history export
if prior history contains material that must remain private.
