---
name: create-pr
description: 'End-to-end pull request workflow: create a properly named branch, commit staged work with a conventional commit message, push, and generate the PR title and description. Use when the user says "create a PR", "ship this", "make a pull request", or wants the full branch-to-PR flow in one go.'
---

# Create a PR

Orchestrates the full change-to-PR flow by delegating to the existing skills. Do not duplicate their rules — invoke each skill and follow it.

## Workflow

### Step 1: Branch

Use the `conventional-branch` skill.

- If already on a compliant non-trunk branch, keep it.
- If on a trunk branch (`main`, `master`, `develop`) or a non-compliant name, create a new branch per the spec.

### Step 2: Format C# files

Review the added, modified, or new `.cs` files and format them with CSharpier.

```bash
dotnet csharpier format <file1.cs> <file2.cs>
```

- Determine the files from `git status` / `git diff --name-only`.
- If CSharpier is unavailable, run `dotnet tool restore` from the repository root and retry.
- Skip if the change touches no `.cs` files.

### Step 3: Commit

Always ask the user for explicit confirmation before committing, and wait for their approval. Show what will be staged and the proposed commit message first. Never auto-commit.

Use the `conventional-commit` skill.

- Review `git status` and `git diff`, stage the relevant changes, and commit with a conventional commit message.
- Skip if there is nothing to commit.

### Step 4: Push

```bash
git push -u origin <branch>
```

### Step 5: PR description

Use the `pr-description-generator` skill to produce the PR title and description from the branch diff. The description must be 4000 characters or fewer.

### Step 6: Create or update the PR via Azure DevOps REST API

Do not use Azure DevOps MCP tools to create PRs or update PR titles and
descriptions. Large descriptions can fail without being applied. Use `curl`
with the Azure DevOps Git REST API instead of PowerShell REST clients, and send
the complete title and description in the JSON request body.

Use API version `7.1` with these endpoints:

- Find active PRs for the source branch:
  `GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/pullrequests?searchCriteria.status=active&searchCriteria.sourceRefName=refs/heads/{branch}&api-version=7.1`
- Create a PR:
  `POST https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/pullrequests?api-version=7.1`
- Update a PR:
  `PATCH https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/pullrequests/{pullRequestId}?api-version=7.1`

Authenticate with the user's existing supported Azure DevOps credentials.
Never print, log, or place credentials in the request body.

Treat the generated Markdown as one complete multiline string. Assign that
string to the request object's `description` property, then serialize the
entire request object once and send it as UTF-8 `application/json`.

To prevent malformed or first-line-only descriptions:

- Never concatenate JSON manually or interpolate raw Markdown into JSON.
- Never pass the description as a command-line argument or line-oriented
  input where the shell can split it at a newline.
- Preserve blank lines, Markdown characters, quotes, backslashes, and all
  newline characters through JSON serialization.
- Before sending, deserialize the generated JSON and confirm its
  `description` equals the complete source Markdown after normalizing CRLF
  and LF line endings.

First, query active PRs where `sourceRefName` is the current branch:

- If a PR exists: ask the user whether to update its title and description.
- If no PR exists: ask the user whether to create it.

After a create or update request succeeds, fetch the PR again with the REST
API. Normalize CRLF and LF line endings, then verify that the returned title,
complete description, and description length match the generated content.
Explicitly reject a response containing only the first line. Do not treat only
a successful HTTP status as sufficient, and do not report success when any
content differs. Rebuild the payload with proper JSON serialization before
retrying an incomplete update.

Always wait for user confirmation before creating or updating anything. Never auto-create or auto-update a PR without explicit approval.

### Step 7: Hand off

Output the branch name, commit message, PR title, PR description, and the URL of the created or updated PR.

## Rules

- Never force-push or rewrite published history.
- Stop and ask if the base branch, scope of changes, or branch type is ambiguous.
