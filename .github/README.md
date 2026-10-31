# Agents Fleet

```text
        ___     _____ _         _
       /   |   / ___/| |       / /___  ___  ___  ___
      / /| |  / /_   | |      / / __ \/ _ \/ _ \/ __/
     / ___ | / __/   | |     / / /_/ /  __/  __/ /_
    /_/  |_|/_/      |_|____/ /\____/\___/\___/\__/
                       /_____/

         A G E N T S   F L E E T
```

**Your AI team. Assembled.**

A curated set of GitHub Copilot agents, skills, and instructions —
designed to feel like they were always part of your repo.

---

## Beautifully organized

| | |
| --- | --- |
| `agents/` | Custom agent definitions. One Markdown file per agent. |
| `skills/` | Agent skills. One folder per skill, each with a `SKILL.md`. |
| `copilot-instructions.md` | Repository-wide Copilot guidance. |

---

## Meet the fleet

Each agent is a single Markdown file with a YAML front matter header —
a name, a description, and the instructions that shape how it thinks.

| Agent | What it does |
| --- | --- |
| **TeamLead** | Orchestrates planning and specialist verification; nontrivial .NET implementation always uses two independent candidates. |
| **analyst** | Turns an objective into a DAG execution plan: task decomposition, wave scheduling, agent assignment, risk analysis. |
| **codebase-researcher** | Explores codebase patterns, dependencies, and architecture using cost-controlled research modes. |
| **devils-advocate** | The challenge function. Attacks assumptions, hunts edge cases, calls out over-engineering and logic gaps. |
| **senior-csharp-developer** | Implements .NET features, fixes, and refactors with TDD. The hands of the fleet. |
| **senior-csharp-developer-alt** | Independent alternate .NET/TDD candidate; risk, duplication, mutation and source-grounded design checks. Uses user-configurable models. |
| **frontend-engineer** | React and TypeScript UI implementation, accessibility, responsive design, and frontend tests. |
| **code-quality-engineer** | Removes dead code, reduces complexity and duplication, and improves naming without changing behavior. |
| **independent-reviewer** | Brutally honest independent review of C# code and new NuGet dependencies. Only wakes up for C#/NuGet changes. |
| **application-security-engineer** | Reviews application trust boundaries, sensitive data, authorization, and security coverage. |
| **diagnostics-engineer** | Root-cause analysis for .NET and Azure — stack traces, regression bisection, repro. Diagnoses only; never patches. |
| **technical-writer** | Produces technical documentation, README files, API docs, diagrams, and walkthroughs. |
| **devops-engineer** | Infrastructure and deployment: Bicep, rollouts, environments, pipelines. |
| **release-engineer** | Takes a merged commit to a safely deployed release. Repeatable, auditable, low-risk. |
| **test-engineer** | Independent behavioral verification. Runs targeted tests and edits tests or fixtures only. |
| **performance-engineer** | Reproducible benchmarks and measurement-backed analysis. No production edits or unauthorized prod load. |

**How they work together.** `TeamLead` receives the objective and asks
`analyst` for a plan. `codebase-researcher` gathers context and
`devils-advocate` pressure-tests assumptions. Specialists then execute their
slice — implementation, quality, security, diagnosis, documentation,
infrastructure, frontend, or release. React UI work routes to
`frontend-engineer`; backend contracts stay with the backend specialist,
and independent behavioral checks stay with `test-engineer`.
Before .NET implementation planning
or dispatch, TeamLead loads the on-demand
[`csharp-divergence`](skills/csharp-divergence/SKILL.md) skill; participating
agents load their role when applicable. It owns mode selection and the
complete coordination workflow, not the always-loaded agent definitions.

## On-demand skills

| Skill | When it loads |
| --- | --- |
| [`csharp-divergence`](skills/csharp-divergence/SKILL.md) | TeamLead before any .NET implementation planning/routing/dispatch; analyst before its DAG; developers before implementation/operations; specialists on divergence input only. |

**Make your own.** Drop a new `<name>.agent.md` into `agents/` with a
`name` and `description` in the front matter. It shows up automatically.

---

## Ready in seconds

Copy this folder into any repository. That's it.
Core agents use built-in tools. Optional MCP tools require separate
installation, trust, and authentication; see [setup](../README.md).

```text
your-repo/
└── .github/
    ├── agents/
    ├── skills/
    └── copilot-instructions.md
```

---

## Designed to be shared

Every agent is plain Markdown — readable, reviewable, and versioned
alongside your code. Fork it, extend it, make it yours.

*Crafted for GitHub Copilot.*
