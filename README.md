# Agents Fleet

Personal-project agents, skills, and instructions for GitHub Copilot.
See the [fleet catalog](.github/README.md) for specialist roles and routing.

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
