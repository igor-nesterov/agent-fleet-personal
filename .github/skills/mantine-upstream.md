# Bundled Mantine skills

## Provenance

- Task: `mantine-skill`; plan: `20261101-mantine-frontend-skill`; researched before download on 2026-11-01.
- Official guide: https://mantine.dev/guides/llms/#skills
- Install commands: https://mantine.dev/llms/guides-llms.md#install-skills
- Upstream: https://github.com/mantinedev/skills
- Pinned commit: `607846dbc328b6ddc85106d8aad3c080f9f57a1d` (2026-10-04, "Update skills for Mantine 9.7").
- Only the three documented `skills/mantine-*` subtrees were copied; no repository clone or unrelated collection.
- Each subtree retains its three upstream Markdown files byte-for-byte, plus the upstream MIT `LICENSE`.
- License evidence: each bundled `LICENSE`, lines 1-21; copyright (c) 2026 Mantine.
- Mantine 9.x scope: `mantine-combobox/SKILL.md:13`, `mantine-form/SKILL.md:14`,
  `mantine-custom-components/SKILL.md:15`.
- Linked assets: combobox `SKILL.md:140-145`, form `SKILL.md:177-182`, custom components `SKILL.md:188-193`.
- Upstream typography is preserved; locally authored documentation uses ASCII.

## Node recommendation

- Recommend **Node.js 26.13.0 (Lithium)** as of 2026-11-01, not an installation request.
- Latest Active LTS; satisfies the researched installer/build engine ranges and has the longest LTS runway.
- Active LTS began 2026-10-28; maintenance begins 2027-10-20; support ends 2029-04-30.
- Node 24.22.2 and 22.23.4 remain supported maintenance alternatives; Node 20 is EOL.
- Lifecycle: https://nodejs.org/en/about/previous-releases
- Schedule fields: https://raw.githubusercontent.com/nodejs/Release/main/schedule.json
- Exact release: https://nodejs.org/en/download/archive/v26.13.0
- `node --version` and `npm --version`: command not found (127); neither executable resolved on PATH.
- **No Node/npm installation, upgrade, global install, or system runtime change occurred.**

| Layer | Verified requirement | Evidence |
| --- | --- | --- |
| Bundled Markdown skills | No Node execution needed to read/copy | Pinned tree has only `SKILL.md` and `references/*.md` |
| Documented installer, `skills@1.7.4` | Node `>=22.20.0` | [Published `engines.node`](https://registry.npmjs.org/skills/1.7.4) |
| Mantine React library, `@mantine/core@9.7.4` | No direct Node engine; React/React DOM `^19.2.0`, hooks `9.7.4` | [Published manifest](https://registry.npmjs.org/@mantine/core/9.7.4), `peerDependencies` |
| Core dependency, `type-fest@5.10.0` | Node `>=20` for installation/tooling; not a browser runtime requirement | [Published `engines.node`](https://registry.npmjs.org/type-fest/5.10.0) |
| Optional build tool, `vite@8.3.5` | Node `^20.19.0 || >=22.12.0` | [Published `engines.node`](https://registry.npmjs.org/vite/8.3.5) |

- Core source: [package.json, lines 45-56](https://github.com/mantinedev/mantine/blob/1d8c524fac27bc6ede5441cdff79abceb9e95b5c/packages/%40mantine/core/package.json#L45-L56).
- No app manifest was added; these are upstream constraints, not a new project stack or tested runtime compatibility.
- Older Mantine majors can have different peers; inspect each project's pinned versions before using v9 examples.

## Installation and refresh

- The official guide documents these commands; they were **not executed**:

```sh
npx skills add https://github.com/mantinedev/skills --skill mantine-combobox
npx skills add https://github.com/mantinedev/skills --skill mantine-form
npx skills add https://github.com/mantinedev/skills --skill mantine-custom-components
```

- With Node prohibited, direct HTTPS copies of those exact subtrees provide the same Markdown/reference payload.
- Discovery location: `.github/skills/<upstream-name>/SKILL.md`; each YAML `name` matches its directory.
- Refresh from the repository root only after reviewing local changes, upstream licensing, and target Mantine major.
  1. Resolve a reviewed upstream commit; inspect its tree without cloning the collection.
  2. Fetch only each selected subtree's files and root `LICENSE` from `raw.githubusercontent.com`.
  3. Keep relative paths; duplicate the unchanged root license into each skill directory.
  4. Compare each file's `git hash-object` with its blob SHA from the pinned GitHub tree.
  5. Validate YAML names/descriptions, links, references, agent tool parity, and the scoped whitespace policy below.
  6. Update this pin/date and changed-file/check evidence; never silently run `npx` or install Node.
- Download command pattern actually used (`asset` was `SKILL.md`, `references/api.md`, or `references/patterns.md`):

```sh
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
  "$base/skills/$skill/$asset" --output ".github/skills/$skill/$asset"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
  "$base/LICENSE" --output ".github/skills/$skill/LICENSE"
```

- `base` was `https://raw.githubusercontent.com/mantinedev/skills/607846dbc328b6ddc85106d8aad3c080f9f57a1d`.
- `skill` was each documented name above; each download command group exited 0.

## Changed files

- `.github/agents/frontend-engineer.agent.md`
- `README.md`
- `.github/skills/mantine-upstream.md`
- `.github/skills/mantine-combobox/SKILL.md`
- `.github/skills/mantine-combobox/references/api.md`
- `.github/skills/mantine-combobox/references/patterns.md`
- `.github/skills/mantine-combobox/LICENSE`
- `.github/skills/mantine-form/SKILL.md`
- `.github/skills/mantine-form/references/api.md`
- `.github/skills/mantine-form/references/patterns.md`
- `.github/skills/mantine-form/LICENSE`
- `.github/skills/mantine-custom-components/SKILL.md`
- `.github/skills/mantine-custom-components/references/api.md`
- `.github/skills/mantine-custom-components/references/patterns.md`
- `.github/skills/mantine-custom-components/LICENSE`

## Validation evidence

- Coverage matrix for this docs-only change; checked from the repository root:

| Requirement | Check actually executed | Result |
| --- | --- | --- |
| Official source and licensing | Official guide, pinned tree, root license reviewed before copying | Passed |
| Runtime research before download | `command -v node`; `node --version`; `command -v npm`; `npm --version` | No executables on PATH; version probes 127 |
| Complete upstream payload | Temporary read-only Python audit against GitHub tree blob SHA-1 values | 12/12 byte-identical, including 3 license copies; exit 0 |
| Skill discovery/frontmatter | Standard-library Ruby `YAML.safe_load` on three skills and frontend agent | Names match directories; meaningful descriptions; exit 0 |
| Bundled references and links | Python audit of relative file paths and heading anchors, excluding example code fences | 100 links passed before adding this evidence section |
| Agent capabilities and minimal delta | Python audit compares baseline after removing each inserted section | Tools and all previous agent/README content unchanged; exit 0 |
| Whitespace and Markdown structure | Initial `git diff --check`; Python balanced-fence/unfinished-marker checks | Exit 0 excluded untracked files; scoped whitespace failures documented below |
| Secrets and character hygiene | Scoped Python secret-pattern scan; ASCII check on authored docs | Passed; upstream typography untouched |
| Exact scope and dirty-work preservation | `git status --short`; Python modified/untracked inventory comparison | Initially clean; exactly 13 created and 2 updated files |
| LSP syntax/type diagnostics | Tool discovery for `problems`/`get_errors` returned no tool | Unavailable; not claimed as passing |
| Diagrams and application checks | No diagram added; no application build/test or Node command beyond probes | Not applicable; no runtime compatibility test claimed |

### Whitespace follow-up

- Task: `diagnose-upstream-whitespace`; plan: `20261101-mantine-pr`; checked on 2026-11-01.
- Both local files equal public raw bytes and GitHub tree blobs at the pin above; both end in `0a0a`.
- Paths below are upstream paths relative to `base`; local paths replace `skills/` with `.github/skills/`.

| Upstream source | Local EOF blank line | Local, raw, and pinned-tree Git blob SHA-1 |
| --- | --- | --- |
| `skills/mantine-combobox/SKILL.md` | 153 | `2c11674421611e06f225ffbeb27e03a779e4900a` |
| `skills/mantine-custom-components/SKILL.md` | 201 | `5f523ba4c356f1dbb04d1c3add6b8a2e8ed00e92` |

- Public root `LICENSE` is MIT; raw and pinned-tree blob: `3c5e6b153240cced58bda9326fc0766c797be122`.
- Originals preserved; only this provenance document changed.
- Ordinary scoped working-tree and cached `git diff --check` returned 0; all three files were untracked.
- The checks below include untracked contents by comparing each complete file against `/dev/null`.
- Strict checks report only EOF blank lines: combobox:153 and custom-components:201; each exits 3.
- Strict provenance and EOF-only-exempt originals produce no diagnostics; each exits 1 (no-index differences).
- These no-index exits are evidence, not a claim that standard whitespace validation passes.
- Release policy: verify pinned blobs first; exempt only `blank-at-eof` for exact verified vendored paths.
- Keep authored files strict, including this document; never apply the exemption repository-wide.

```sh
for path in .github/skills/mantine-combobox/SKILL.md \
  .github/skills/mantine-custom-components/SKILL.md .github/skills/mantine-upstream.md; do
  git -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab \
    --no-pager diff --no-index --check -- /dev/null "$path"
done
for path in .github/skills/mantine-combobox/SKILL.md .github/skills/mantine-custom-components/SKILL.md; do
  git -c core.whitespace=blank-at-eol,space-before-tab,-blank-at-eof \
    --no-pager diff --no-index --check -- /dev/null "$path"
done
```

- Audit command actually executed (temporary local validator, not bundled executable code):

```sh
python3 /tmp/mantine-docs-audit.py \
  --repo /Users/igornesterov/Sources/agent-fleet-personal \
  --commit 607846dbc328b6ddc85106d8aad3c080f9f57a1d
ruby -ryaml /tmp/mantine-frontmatter-audit.rb \
  .github/skills/mantine-combobox/SKILL.md \
  .github/skills/mantine-form/SKILL.md \
  .github/skills/mantine-custom-components/SKILL.md \
  .github/agents/frontend-engineer.agent.md
git diff --check
```

- Both temporary validators are read-only local audit helpers; neither is part of the bundled skills.
- Existing repository tests cover unrelated PowerShell repository-copy helpers; none were run for Markdown-only work.
- Loaded `common-sense-boundaries`; requested `agent-customization` was not found in repo or searched skill roots.
- Used the supplied `.github/skills/<name>/SKILL.md` convention; missing customization skill is a validation limit.
- No task `plan.yaml` or persisted context envelope was present; acceptance checked against the supplied inline task.
- No commits, push, Node/npm installs, dependency manifests, app scaffolding, MCP setup, or runtime changes.
- Blockers: no vendoring/integration blocker; optional LSP and customization-skill validation unavailable.
- Next owner: `TeamLead`; review these scoped docs and the reported validation limits.
