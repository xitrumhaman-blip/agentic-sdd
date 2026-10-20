---
name: init-docs
description: >-
  Initialize the ./docs architecture knowledge base and CLAUDE.md for a project,
  so coding agents follow the existing architecture, constraints, and past
  technical decisions instead of reinventing them. Use this whenever the user
  asks to init, scaffold, bootstrap, or set up project docs, an ADR structure,
  architecture docs, a docs folder, or agent/AI guidelines — even if they don't
  say the word "scaffold". Also use it when a repo has no ./docs yet and the user
  wants agents to respect existing decisions. When the repo already has its own
  docs tree, use its adopt mode: map the existing files in .claude/engineer.yml
  and add only what the Agentic SDD skills need, without moving anything.
---

# init-docs

Scaffold a `./docs` knowledge base plus a root `CLAUDE.md` that points agents to
it. The goal is a structure agents can read **selectively**: they find the
invariants they must not break, the decisions already made (ADRs), and the
conventions to follow, without reading everything.

This is the first step of the Agentic SDD process
(`${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md`): the tree also holds the
per-version plans (`docs/plans/`) and the feature tests
(`docs/test-cases/`) that the later `engineer:*` skills write.

This skill only **initializes**. If `./docs` already exists, stop and tell the
user — overwriting would destroy content the team has edited. Updating an
existing tree after code changes is a separate job (`engineer:sync-docs`).

## What gets created

```
CLAUDE.md                      # entry point, auto-loaded by Claude Code (skipped if present)
CHANGELOG.md                   # Keep a Changelog (skipped if present)
docs/
├── README.md                  # index + reading order for agents
├── 00-context/                # product-overview, glossary
├── 01-architecture/           # overview (C4 diagrams), components/, data-model, diagrams/
├── 02-constraints/            # invariants, non-functional, dependencies
├── 03-decisions/              # ADRs (_template.md + seed ADR-0001)
├── 04-conventions/            # coding-style, api-design, testing (commands:), git-workflow (SDD)
├── 06-agent-guide/            # workflow, known-pitfalls
├── plans/                     # one folder per version, written by the SDD skills
└── test-cases/                # feature-tests/ (living spec, Gherkin), unit-tests/ (mapping)
```

The templates live in `templates/` next to this file. The scaffold script copies
them into place and fills placeholders.

## Workflow

Follow these steps in order. Keep questions minimal — detect what you can before
asking.

### Step 1 — Guard against overwriting

Check whether `./docs` exists in the target project.

- **Absent**: proceed. An existing `CLAUDE.md` or `CHANGELOG.md` is fine — the
  script leaves them untouched and Step 4 explains how to merge `CLAUDE.md`.
- **Present**: do not scaffold over it (the script refuses anyway). Offer:
  (a) **adopt** the existing tree — see "Adopt mode" below, the usual choice
  for a repo with hand-written docs; (b) pick a different target directory;
  (c) only refresh descriptive docs with `engineer:sync-docs`.

### Step 2 — Detect the project

Inspect the repo to pre-fill answers instead of asking blindly. Look for:

- **Stack signals**: `package.json`, `pyproject.toml` / `requirements.txt`,
  `go.mod`, `Cargo.toml`, `pom.xml` / `build.gradle`, `composer.json`,
  `Gemfile`, `*.csproj`. Read the key ones to infer language, framework, and
  package manager.
- **Monorepo signals**: `pnpm-workspace.yaml`, `turbo.json`, `nx.json`, a
  `packages/` or `apps/` directory, workspaces field in `package.json`.
- **Brownfield vs greenfield**: is there substantial source code already, or is
  this a fresh repo? If there is real code, the docs should describe what exists,
  not an imagined design.

- **Test commands**: how to install/setup, lint, run unit tests, and run
  feature (e2e/integration) tests — from manifest scripts, Makefile, CI config.
- **Environment branches**: `git ls-remote --heads origin main release`. The
  SDD process needs `main` (STAG) and `release` (PROD) on the remote; if
  `release` is missing, tell the user (they create it, e.g.
  `git push origin main:release`, after committing the docs).

> **Brownfield note:** when the repo already has meaningful code, the
> architecture/constraints docs should reflect reality. Run the
> `codebase-analyzer` agent first to extract the real architecture, data flow,
> dependencies, conventions, test commands and candidate invariants, then feed
> that into the templates. Mark anything it flags as uncertain as
> `TODO: confirm`.

### Step 3 — Gather the few things you can't detect

Ask only for what you genuinely can't infer. Prefer one short batch of questions
over a back-and-forth. Typical gaps:

- **Project name** and a **one-line description** (what it does, for whom).
- **Confirm the detected stack** (show what you found, let them correct it).
- **Confirm the test commands** you detected (setup, lint, unit, feature);
  leave a command empty when the project has none yet.
- Anything stack-specific the conventions need (e.g. REST vs GraphQL, test
  framework) — only if not obvious from the repo.

If the user already gave this information earlier in the conversation, use it;
don't re-ask.

### Step 4 — Run the scaffold

Run the script with the gathered values. It creates the tree, copies templates,
and substitutes placeholders. From the target project root:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/init-docs/scripts/scaffold.sh" \
  --target "." \
  --name "<project name>" \
  --one-liner "<one-line description>" \
  --stack "<e.g. TypeScript / Node / Fastify, pnpm monorepo>" \
  --repo "<git remote url or owner/repo, optional>" \
  --cmd-setup "<e.g. pnpm install>" --cmd-lint "<…>" \
  --cmd-unit "<e.g. pnpm test>" --cmd-feature "<e.g. pnpm exec playwright test>"
```

`${CLAUDE_PLUGIN_ROOT}` resolves to the installed plugin directory — use it so
paths work after the plugin is copied into the Claude Code cache. If the variable
is not set (e.g. running the skill outside a plugin context), use the real path
to this skill folder.

The script refuses to run if `docs/` already exists, as a second safety net,
and never overwrites an existing `CLAUDE.md` or `CHANGELOG.md` (it reports
them as skipped — if `CLAUDE.md` was skipped, add the "Before you implement
anything" and "How work is delivered" sections from
`templates/CLAUDE.md.tmpl` to it by hand, with the user's agreement).

### Step 5 — Fill what a template can't

Placeholder substitution handles names and dates, but two files need judgment.
After scaffolding, open and improve them with the project context you have:

- `docs/01-architecture/overview.md` — sketch the actual high-level architecture
  (layers/modules, main data flow) with the two C4 diagrams (System context,
  Containers) in Mermaid. For brownfield, base it on the real code; for
  greenfield, capture the intended design and mark it as provisional.
- `docs/02-constraints/invariants.md` — seed 2–5 real invariants for THIS project
  (e.g. "all money stored as integer minor units", "no direct ORM calls from
  controllers"). Generic placeholders are near-useless; concrete rules are the
  point of the whole structure. If you don't have enough signal, ask the user for
  the hard rules they already know they want.

Leave other files as good starting templates; the team fills them over time.

### Step 5b — Commit types (commitlint)

The SDD uses the Conventional Commits type `improve`. Run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/commitlint-check.sh"`:
- `accepted` (or no commitlint) → nothing to do;
- `rejected` → show the matching snippet from
  `${CLAUDE_PLUGIN_ROOT}/references/commitlint.md` and offer to merge it into
  the repo's config (keep its other rules); commit it separately as
  `build: allow the improve commit type` — it is promoted together with the
  docs commit ("Committing and promoting the docs");
- `unknown` → tell the user which file to check by hand.
Otherwise the first improvement version fails in the commit-msg hook or CI.

### Step 6 — Stamp and report

The templates already carry frontmatter (`scaffold`, `scaffold_version`,
`generated`, and `covers`/`last_synced` where relevant) — verify the script
filled them. Then give the user a short summary:

- the tree that was created,
- which files you filled with real content vs left as templates,
- any `TODO: confirm` sections for brownfield,
- next step: review the docs, then commit and promote them as in
  "Committing and promoting the docs" below.

Do not commit for the user unless they ask.

### Committing and promoting the docs (scaffold and adopt)

"The docs commits" below means the docs commit (`docs: initialize
architecture knowledge base`, or `docs: adopt Agentic SDD layout`) plus the
commitlint fix of Step 5b if there is one (`build: allow the improve commit
type`) — they travel together. Make them on `main` and push `main` (ask
first). Build branches start from `release`, so the same change must reach
`release` too — **only these commits**, `release` is PROD.

Find the versions in flight with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh" --no-gh`:
every listed version whose status is neither `released` nor `abandoned`
(branches of released versions may still exist — ignore them).

- **Versions in flight:** do **not** push to `release` directly. Cherry-pick
  (`git cherry-pick -x`) the docs commits onto **every** in-flight `build/vX` —
  whatever its phase, even one in UAT — and push each (ask first). Each
  version's skills then find the layout and the commit-type fix, and the change
  reaches `release` through the first PR #1 merged (the identical change in
  the others merges cleanly). `port.sh` skips these commits (already on
  `main`); `drift.sh` lists them until a PR #1 is merged — expected. A version
  started later from `release` gets them per `requirement` (drift case 3 /
  `hint layout-on-main`).
- **No version in flight:** if `git rev-list origin/release..origin/main` lists
  nothing but the docs commits, `git push origin main:release` is safe (ask
  first); otherwise `main` holds unreleased STAG work: create `chore/init-docs`
  from `origin/release`, `git cherry-pick -x` the docs commits, push it and
  open a PR to `release` (ask first).

**Bước tiếp theo:** `/engineer:requirement` for the first version.

Then run the silent retro (`${CLAUDE_PLUGIN_ROOT}/references/retro.md`).

## Adopt mode (existing docs tree)

Goal: make the SDD skills work with the docs the team already has, **without
moving, renaming or renumbering anything**.

1. Map. List the docs tree (and ask `codebase-analyzer` if it is large). For
   each key in "Docs layout" (`${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md`)
   find the existing file or folder that plays that role: architecture
   overview, invariants / hard rules, ADR folder and its template, conventions,
   testing conventions, pitfalls, … Keys with no counterpart keep their default
   path. Detect how invariants are numbered (`INV-007`, `#7`, `R7`, …).
2. Show the user the proposed map (key → path, "existing" or "will be
   created") and the invariant citation format. Adjust until confirmed.
3. Write `.claude/engineer.yml` from `templates-adopt/engineer.yml` (next to
   this file) with only the keys that differ from the defaults, plus
   `invariant_id`.
4. Add only what is missing for the SDD skills, at the resolved paths:
   - `commands:` frontmatter (`preflight`, `setup`, `lint`, `unit`, `feature`) in the
     `testing` document — add a frontmatter block to the existing file, or
     create the file from `templates/docs/04-conventions/testing.md.tmpl`;
   - the `plans`, `feature_tests` and `unit_tests` folders with the READMEs
     from `templates/docs/plans/` and `templates/docs/test-cases/`;
   - an ADR template at `adr_template` if the repo has none
     (`templates/docs/03-decisions/_template.md`);
   - the "How work is delivered" section of `templates/CLAUDE.md.tmpl` in
     `CLAUDE.md`, and the SDD branch/tag/commit rules of
     `templates/docs/04-conventions/git-workflow.md.tmpl` in the repo's git
     conventions (ask before editing existing prose).
5. Verify: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/docs-layout.sh"` shows `ok`
   for `invariants`, `decisions`, `testing`, `plans`. Run Step 5b (commit
   types). Report, then commit and promote as in "Committing and promoting the
   docs".

## Notes

- Keep `CLAUDE.md` short. Claude Code auto-loads it every session; `./docs` is
  not auto-loaded, so `CLAUDE.md` must point agents into `docs/README.md`.
- Everything is Markdown + YAML frontmatter + Mermaid so agents can read and grep
  it; avoid binary diagrams.
- To pin a fixed default stack for the whole team instead of detecting it, edit
  the default value of `--stack` in `scripts/scaffold.sh` and relax Step 2/3
  accordingly.
