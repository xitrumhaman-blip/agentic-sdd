---
name: sync-docs
description: >-
  Bring the descriptive parts of ./docs (architecture overview, components, data
  model, API notes, testing commands, known pitfalls) back in line with the code
  after a build, and record any deviation from the plan as an ADR. Called by
  engineer:build before shipping; also usable directly when the user says the
  docs are out of date with the code. Never rewrites invariants or accepted ADRs.
argument-hint: "[vX.Y.Z.T or a git range, optional]"
---

# engineer:sync-docs

Read `${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md` first. Direction of
truth: **descriptive docs follow the code; invariants and ADRs lead the code.**

Resolve the docs layout first ("Docs layout" in the conventions); every
`docs/…` path below means the resolved location.

## Step 1 — What changed

Range: `origin/release..HEAD` on `build/vX` (or the range the user gives).

```bash
git diff --name-only <range>
```

Match changed paths against the `covers:` globs in the frontmatter of
`docs/01-architecture/**` docs. A changed path matched by no doc in a
significant area means a component doc is missing.

## Step 2 — Update descriptive docs

For each matched doc, read the relevant diff and update only what is now wrong
or missing:

- `01-architecture/overview.md` — modules and the C4 diagrams.
- `01-architecture/components/*.md` — responsibility, entry points, key types;
  create new files for new modules (with `covers:`).
- `01-architecture/data-model.md` — entities, fields, migrations.
- `04-conventions/testing.md` — `commands:` and layout if they changed.
- `06-agent-guide/known-pitfalls.md` — traps hit during the build.

Set `last_synced: <short sha of HEAD>` and `updated: <today>` on every doc you
touch. Do not rewrite prose that is still correct.

## Step 3 — Deviations

Compare the result with `docs/plans/vX/architecture.md` and the goals' Notes.
- An architectural deviation (different pattern, dependency, boundary) gets a
  new ADR (`status: Proposed`) describing what was actually done and why. Ask
  the user to accept it; mark it `Accepted` only after they do.
- If code contradicts an invariant or an accepted ADR, do **not** change the
  docs to match: report it as a defect to fix before shipping.

## Step 4 — Commit

Commit `docs(vX.Y.Z.T): sync docs with implementation` and report the files
updated, the ADRs proposed, and any contradictions found.
