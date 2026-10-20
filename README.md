# agentic-sdd

A Claude Code plugin that runs **Spec-Driven Development with AI agents**.
Agents draft, implement, test, review and open the pull requests. People
approve every decision that matters at defined gates.

```
requirement → plan → architect → build → code-review → ship → release
 (EARS)      (WBS, DoD,  (ADRs,     (builder ⇄   (review,     (PR to PROD,  (rc tag on STAG
             Gherkin)    D-NN)      verifier)    fix, retest)  port to STAG)  → UAT → PROD tag)
```

## Install

    /plugin marketplace add OWNER/agentic-sdd
    /plugin install engineer@agentic-sdd

Update: `/plugin marketplace update agentic-sdd`.

Requirements: Claude Code, git, bash, and the GitHub CLI (`gh`) logged in.
Each product repo uses two environment branches: `main` = staging (STAG) and
`release` = production (PROD).

## Plugin: engineer

```
/engineer:init-docs      once per repo: docs/ knowledge base + CLAUDE.md (or adopt an existing docs tree)
/engineer:requirement    discuss and approve → build/vX.Y.Z.T + requirement.md
/engineer:plan           plan.md (WBS + Definition of Done) + Gherkin feature tests
/engineer:architect      complete design: ADRs, invariants, C4, design decisions (D-NN)
/engineer:build          goals built and verified by subagents → tests → review → 2 PRs
                         (--approved: auto-approve every proposal during the build)
/engineer:code-review    review the whole version, apply fixes, rerun all tests
/engineer:ship           open/update the PRs (--skip-test: user-only)
/engineer:release stag   tag vX-rc.N on main (STAG)
/engineer:release prod   merge to release, tag vX (PROD), GitHub Release (--uat-waived "<reason>")
/engineer:status         where every version stands, what to run next
/engineer:guide          onboarding and help (tutorial on your own sandbox repo)
/engineer:feedback       report plugin problems as issues, drafted from the conversation
```

| Part | What it does |
|---|---|
| `skills/` | One skill per phase, plus helpers (`next-version`, `start-build`, `run-tests`, `sync-docs`) |
| `agents/` | `goal-builder` implements one plan goal; `goal-verifier` checks it read-only and returns PASS/FAIL; `codebase-analyzer` maps an existing codebase |
| `scripts/` | Bash for everything that must be deterministic: versions, branches, commit validation, cherry-pick porting, drift, test-report freshness, review worktrees |
| `references/sdd-conventions.md` | The single set of rules every skill and agent follows |

## Design principles

- **People decide, agents execute.** Each phase ends at a human gate.
  `--approved` lets a trusted run approve its own proposals, but scope changes,
  failing or newly skipped tests, invariant changes, force-push, merges and tags
  always stop for a person.
- **The builder never marks its own work done.** A separate, read-only verifier
  needs evidence for every Definition-of-Done item.
- **Design is decided up front.** Every decision gets an ID, a rationale and an
  approver; the build escalates anything outside them instead of guessing.
- **Scripts for mechanics, LLM for judgment.**
- **Traceability.** Conventional Commits with a `Refs: vX.Y.Z.T/G-NN` trailer
  link every commit to a plan goal.
- **The workflow improves itself.** Every skill ends with a silent retro that
  queues friction. `/engineer:feedback` turns it into issues, and
  `/plugins-resolve-feedback` resolves them.

More:
- Guide (Vietnamese, Diátaxis): [`plugins/engineer/docs/guide/`](plugins/engineer/docs/guide/README.md)
- Design: [`docs/design/agentic-sdd.md`](docs/design/agentic-sdd.md)
- Rules: [`plugins/engineer/references/sdd-conventions.md`](plugins/engineer/references/sdd-conventions.md)
- History: [`plugins/engineer/CHANGELOG.md`](plugins/engineer/CHANGELOG.md)

## Maintaining this repo

- Changes land on `main`; `release` is what users install (make it the default
  branch on GitHub).
- Feedback arrives as issues (`/engineer:feedback` or the issue forms).
  `/triage` groups and prioritises them. `/plugins-resolve-feedback` resolves
  them end to end: fixes, tests, independent review, CHANGELOG, and commits
  with `Closes #n`.
- First-time label setup: `scripts/setup-labels.sh [owner/name]`.
- With every release, bump `version` in
  `plugins/engineer/.claude-plugin/plugin.json` and update the CHANGELOG.

## How this was built

Built with Claude Code over 8 versions in about two weeks. The agents wrote the
code and documents. I designed the process and its gates, made the decisions,
reviewed and tested every change, and turned feedback from real use into
releases.
