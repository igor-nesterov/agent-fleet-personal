---
name: repo-without-agents
description: 'Clone a Git repository without agent, skill, and prompt configuration folders or root AGENTS.md using the bundled scripts/repo-without-agents.ps1. Ignore configuration locally, then optionally copy it in as a separate, permission-gated step. Activated only when the user says the keyword HAMBURG.'
disable-model-invocation: true
---

# Repo Without Agents

Clones a repository into a "light" working copy that excludes agent/AI configuration paths (`.claude`, `.cursor`, `.github/agents`, `.github/skills`, `.github/prompts`, `.github/chatmodes`, `.github/instructions`, `.github/copilot-instructions.md`, `agents`, `skills`, `prompts`) using a sparse checkout.

Root `AGENTS.md` is excluded by clone and deleted by the ignore and copy scripts, whether tracked, untracked, or already missing. It is never copied from the fleet source. Nested `AGENTS.md` files are not targeted; existing `.github` replacement and `.claude` sanitation behavior is unchanged.

**Activation keyword:** `HAMBURG`. Run this skill only when the user's message contains `HAMBURG` (case-insensitive) or they explicitly name the skill. Never trigger it automatically otherwise.

## Usage

Run from the repository root in `pwsh`, using the script bundled with this skill:

```powershell
.\.github\skills\repo-without-agents\scripts\repo-without-agents.ps1 -RepoUrl <repo-url> -TargetDir <target-directory>
```

Both parameters are required; supply the repository URL and a new target directory.

### Copying agent configuration (AI related) into cloned repos

To copy agent configuration into the root of one or more cloned repos:

```powershell
.\.github\skills\repo-without-agents\scripts\copy-agent-config.ps1 -TargetDir <target-dir-1>,<target-dir-2> [-SourceDir <source-repo-root>] [-Force]
```

- `-TargetDir` is required and accepts one or more cloned repository roots.
- `-SourceDir` defaults to this fleet repository root.
- Replaces `.github` and copies `.mcp.json` byte-for-byte to each target repository root. Existing destinations require `-Force`.
- Missing source `.github` or `.mcp.json` is reported and skipped; existing target counterparts stay untouched. `.mcp.json` must be a file, not a directory.
- Sanitizes target `.claude` in place (empties `SKILL.md`, deletes other files). Existing target `.claude` requires `-Force`.
- Deletes target root `AGENTS.md` after successful preflight, without requiring `-Force` for that file. Directories/reparse points at that path are rejected, not recursively removed. Run the separate ignore step to hide tracked deletions, just as for copied configuration.

### Ignoring agent configuration (AI related) in cloned repos

To keep copied config out of source control, append `.github/`, `.claude/`, `.mcp.json`, and root-only `/AGENTS.md` to `.git/info/exclude`:

```powershell
.\.github\skills\repo-without-agents\scripts\ignore-agent-config.ps1 -TargetDir <target-dir-1>,<target-dir-2>
```

- `-TargetDir` is required and accepts one or more cloned repository roots.
- Existing entries are untouched; targets without `.git/info/exclude` are skipped.
- Marks tracked paths under `.github/` and `.claude/`, plus tracked root `.mcp.json` and `AGENTS.md`, `assume-unchanged` so overwrites/deletion do not add working-tree changes:

```powershell
git ls-files -- .github/ .claude/ .mcp.json AGENTS.md | ForEach-Object { git update-index --assume-unchanged -- $_ }
```

- Deletes root `AGENTS.md` after marking the index, including when a tracked file was already missing. The script never stages a deletion or rewrites staged content/history.
- Ignore rules never apply to tracked files; `assume-unchanged` hides local overwrites and the tracked root deletion. Preexisting staged changes remain visible: the script warns for staged `AGENTS.md`, so a completely hidden root path cannot be promised in that case. Resolve staged work explicitly; never reset or unstage it automatically.
- Do not use `--skip-worktree`: sparse checkout resets it for existing files. Script is idempotent.

To undo:

```powershell
git ls-files -v | Where-Object { $_ -cmatch '^h ' } | ForEach-Object { git update-index --no-assume-unchanged -- ($_ -replace '^h ', '') }
```

This unmasks local changes; it does not restore deleted files. Index flags and local excludes are local conveniences, not a permanent guarantee across Git operations; rerun ignore when needed.

## Workflow

Strict **three-step** workflow. Never combine steps into a single run.

### Step 1 — Clone

1. Ask user for repo URL and target dir if not provided.
2. Target dir must not exist — script throws if it does.
3. Run `repo-without-agents.ps1`; report resolved path and excluded paths, including root `AGENTS.md`.
4. Surface any `git clone` or sparse-checkout failure verbatim without retry.

### Step 2 — Ignore agent configuration (AI related) locally

5. Run `ignore-agent-config.ps1` with cloned roots as `-TargetDir` to exclude configuration locally and delete root `AGENTS.md` before copy.
6. Report added, present, skipped, or removed entries and any staged-change warnings.

### Step 3 — Copy agent configuration (AI related) (requires explicit permission)

7. **Always ask user permission** before copy. State targets, `.github` replacement, root `.mcp.json` copy/overwrite, in-place `.claude` sanitation (empty `SKILL.md`, delete other files), and root `AGENTS.md` deletion.
8. If user approves, run `copy-agent-config.ps1` with cloned roots as `-TargetDir` (and `-Force` if destinations exist); report results.
9. If user declines or does not answer, stop after Step 2. Never copy implicitly.
10. Re-run `ignore-agent-config.ps1` with same `-TargetDir` values after copy to mark any collisions `assume-unchanged`.
11. Confirm root `AGENTS.md` is physically absent and run `git status --short` in each target. Configuration paths and the root deletion must add no working-tree changes. Report exact paths for any preexisting staged changes; do not hide or discard them.

## Validation

Run the existing regression harness from this repository root:

```powershell
pwsh -NoLogo -NoProfile -File .\.github\skills\repo-without-agents\tests\Test-CopyAgentConfig.ps1
```

Tests use isolated temporary fixtures and clean them afterward. They cover copy, local ignore, and a local-only clone of existing fleet history using Git's `sparse-checkout check-rules` (a Git version supporting that command is required). No network, new commits, or real destination repositories are involved. Staged fixtures verify that deletion adds no status changes without concealing staged work.
