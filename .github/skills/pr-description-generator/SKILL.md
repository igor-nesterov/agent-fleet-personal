---
name: pr-description-generator
description: Generate a Pull Request title and description by analyzing the current branch's diff against the base branch. Use this skill whenever the user wants to create a PR description, fill out a PR template, write PR details, generate a pull request, open a PR, update a PR description, or asks anything related to pull request descriptions, titles, or templates — even if they just say "write a PR" or "describe my changes" or "open a pull request" or "update the PR".
---

# PR Description Generator

Generate a well-crafted PR title (conventional commit format) and a filled-out PR description template by analyzing the git diff of the current branch.

## Workflow

### Step 1: Identify the base branch

Determine the base branch that the current branch will be merged into.

Run these git commands to gather context:

```bash
git branch --show-current
git remote show origin | grep "HEAD branch"
git log --oneline -5
```

Use `git remote show origin` to find the default branch (usually `main` or `master`). If the repo has a common base like `develop` or `staging`, infer from the branch naming convention or recent merge targets.

If the base branch cannot be confidently determined (e.g., ambiguous remote setup, multiple candidates), ask the user which branch they intend to merge into. Don't guess — getting the base branch wrong means the diff will be wrong, which means the entire PR description will be wrong.

### Step 2: Get the latest commit and full diff

Fetch the diff between the current branch and the base branch, along with the latest commit info:

```bash
git log -1 --format="%H %s"
git diff <base-branch>...HEAD --stat
git diff <base-branch>...HEAD
```

Use the three-dot diff (`...`) because it shows only the changes introduced on the current branch since it diverged from the base — this is what a PR reviewer will actually see.

If the diff is extremely large (thousands of lines), use `--stat` first to understand the scope, then read the most important changed files selectively. For very large diffs, focus on:

- New files (they tell the story of what was added)
- Modified core files (business logic, not config/lock files)
- Deleted files (what was removed and why)

Skip noisy files like lock files, auto-generated code, or minified assets — they add nothing to the description.

### Step 3: Analyze the diff thoroughly

Before writing anything, take time to actually understand what the changes do. This is the most important step — a PR description is only as good as the understanding behind it.

Think through:

- **What** changed? (files, functions, components, APIs)
- **Why** might it have changed? (bug fix, new feature, refactor, performance)
- **How** do the changes work together? (trace the logic across files)
- **What's the scope?** (is this a small targeted fix or a broad refactor?)
- **Are there any breaking changes?** (API changes, schema migrations, removed exports)
- **Are there side effects?** (dependency updates, config changes)

Group related changes into logical chunks. A PR that touches 15 files might really be doing 2-3 things — identify those themes so the description tells a coherent story rather than listing every file.

### Step 4: Find the PR template

Use the default template bundled with this skill at `assets/default-template.md` (relative to this skill's directory).

### Step 5: Generate the PR title

Create a PR title using conventional commit format:

```
<type>(<scope>): <short summary>
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

**Guidelines:**

- The type should reflect the primary purpose of the PR (if there are mixed changes, use the dominant one)
- The scope is optional but helpful — use the module, component, or area of the codebase affected
- The summary should be imperative mood ("add" not "added"), lowercase, no period at the end
- Prefix the title with a risk rating (`[Low]`, `[Medium]`, or `[High]`) — see **Risk Rating** below
- Keep it under 72 characters total
- It should make immediate sense to someone scanning a list of PRs

**Examples:**

- `[Low] docs(readme): clarify setup steps`
- `[Medium] feat(auth): add JWT refresh token rotation`
- `[Medium] fix(api): handle null response in user endpoint`
- `[Low] refactor(dashboard): extract chart components into shared module`
- `[High] feat(auth): rotate signing keys on login`

### Risk Rating

Prefix every PR title with `[Low]`, `[Medium]`, or `[High]` to signal how dangerous the change is (blast radius, reversibility, and impact on users/data). Base the rating on your diff analysis from Step 3, and call out the reasoning in the PR description.

- `[Low]` — docs, comments, tests, isolated non-breaking tweaks.
- `[Medium]` — behavior or logic changes with limited blast radius.
- `[High]` — breaking changes, migrations, security/auth, infra, or data-loss risk.

Example: `[High] feat(auth): rotate signing keys on login`

### Step 6: Fill the template

Fill in the PR template based on your analysis from Step 3. Be specific and useful:

- **What does this PR do?** — Describe the changes in plain language. Lead with the "why" (the problem or goal), then explain the "what" (what was done). Use bullet points for multiple changes. Don't just restate the diff — add context that isn't obvious from the code.
- **Testing steps** — Write concrete steps a reviewer can follow to verify the changes. Include specific URLs, commands, inputs, or scenarios to test. If there are edge cases, mention them.
- **Checklists** — Check off items that are true based on what you can observe from the code. Leave items unchecked if you can't verify them or if they don't apply. If an item is clearly not applicable, you can note `N/A` with a brief reason.

Don't fabricate information. If you can't determine something from the diff (like whether manual testing was done), leave it for the author to fill in. It's better to leave a checkbox unchecked than to check it incorrectly.

### Step 7: Present the output

Output exactly two markdown code blocks in the chat:

First block — the PR title:

````
```markdown
<generated-title>
```
````

Second block — the filled template:

````
```markdown
<filled-template>
```
````

This format makes it easy for the user to copy-paste into their PR.

This skill only generates the title and description. It never creates or
updates a pull request — that is handled by the `create-pr` skill.

## Constraints

- The description must not exceed 4000 characters. If the filled template is
  longer, tighten the wording and trim low-value detail until it fits, while
  keeping every template section present.
