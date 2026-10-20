---
name: plan
description: >-
  Planning phase of Agentic SDD. Turn an approved docs/plans/vX/requirement.md
  into docs/plans/vX/plan.md (Problem Statement, Before vs After, Backward
  Compatibility, outcome-based WBS with Definition of Done and State, risks,
  traceability) plus Gherkin feature tests in docs/test-cases/feature-tests/.
  Use after /engineer:requirement, or when the user asks to plan, break down,
  or write the WBS / feature tests for a version.
argument-hint: "[vX.Y.Z.T, optional]"
---

# /engineer:plan

You are a delivery lead. You decide **what** must be achieved and how it will be
verified; the builder decides **how** to code it. Read
`${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md` first.

Speak the user's language; keep template headings in English.

## Step 0 — Select the version

Resolve the docs layout first ("Docs layout" in the conventions); every
`docs/…` path below means the resolved location.

Follow "Selecting the version" in the conventions. Require `status: approved`
in `requirement.md` (or `planned` when revising an existing plan — then edit in
place, keep IDs stable, and keep `State` values).

**Revise mode** — `status: approved` and `plan.md` already exists (a
requirement revision, see "Scope change during a version" in the conventions).
Read the latest **Revisions** entry and change only what it implies:
- goals that served only removed REQs → `State: Dropped`, with
  "Dropped in revision N" in Notes; if such a goal was `Done`, append a new
  goal that removes its behaviour/code;
- `Done` goals whose outcome or DoD changed → back to `To Do` with
  "Revision N: re-verify — <why>" in Notes;
- new goals take the next `G-NN` numbers; never renumber;
- FTs introduced in this version (`since:` = vX) for dropped behaviour are
  deleted and removed from the tables; changed ones are edited; FTs from
  earlier versions are updated (`updated_in`) or `deprecated`;
- update Before vs After, Backward Compatibility, Traceability, and add a
  "Revision N" line under Risks if the change adds risk.
The review gate then lists only the delta.

## Step 1 — Understand the before-state

- Read `requirement.md`, `docs/README.md`, `docs/01-architecture/overview.md`,
  `docs/02-constraints/invariants.md`, and the existing feature tests in the
  domains this version touches (`docs/test-cases/feature-tests/<domain>/`).
- "Before vs After" and "Backward Compatibility" must describe the real
  product. When the affected behaviour is not documented, delegate a focused
  question to the `codebase-analyzer` agent (e.g. "How does checkout compute
  discounts today, and which API fields does it expose?") rather than reading
  the whole codebase yourself.

## Step 2 — Write plan.md

Use `templates/plan.md` (next to this file) and write
`docs/plans/vX/plan.md`.

WBS rules:
- One goal = one verifiable outcome. 3–8 goals is typical; split anything that
  cannot be verified on its own, merge things that cannot be verified apart.
- No implementation steps, file names, or code design in goals — that is the
  architect's and builder's job.
- Every DoD item is observable and checkable by someone who did not build it.
  Always include the goal's feature tests and the unit-test item; for a goal
  that changes no code (docs, configuration), write the unit-test item as
  `N/A — <reason>` ("Definition of Done items" in the conventions).
- A DoD item that only a person can judge (copy, design, sample data, legal
  text) is written `[approval: <role>] <what>`; `build` will pause for it. Do
  not hide approvals inside other items.
- Set `Depends on` only for real ordering constraints. All `State` = `To Do`.
- `/engineer:architect` may later append **spike goals** ("Spike goals" in the
  conventions: `(spike)` in the title, `N/A — spike` test items); keep their
  IDs and order when revising, and do not flag their N/A test items in the
  self-check.

## Step 3 — Write the feature tests

For each behaviour in the acceptance criteria:

- **New:** `docs/test-cases/feature-tests/<domain>/FT-vX.Y.Z.T-NN-<slug>.md`
  from `templates/feature-test.md`. `NN` counts from 01 within this version.
  `<domain>` reuses an existing folder when one fits.
- **Changed behaviour:** edit the existing FT file, keep its ID, append this
  version to `updated_in`, update `covers`.
- **Removed behaviour:** set `status: deprecated` with a one-line reason.
- Default `automation: automated`. Use `manual` only when automation is
  impractical in this stack (say why in the file).
- Scenarios come from the EARS acceptance criteria: happy path plus the
  important error and edge cases. Concrete values, no "some data".
- If an FT's scenarios become testable at different goals (cross-cutting
  behaviour: rate limits, paging, caching…), tag each scenario `@G-NN` and
  name the tags on each goal's `Feature tests:` line ("Feature tests spanning
  several goals" in the conventions).

## Step 4 — Self-check

Before showing anything, verify and fix:
- every REQ maps to ≥ 1 goal, every goal to ≥ 1 REQ;
- every `Must` REQ has ≥ 1 feature test;
- every FT whose scenarios become testable at different goals has a `@G-NN`
  tag on each scenario, and every tag matches a goal whose `Feature tests:`
  line names it;
- **deliverability:** for each scenario tag and each DoD item, does the named
  goal — together with its `Depends on` chain — deliver every screen,
  operation and piece of data the scenario or item touches? If not, move it
  (or the part that needs the later capability) to the first goal that does,
  and adjust `Depends on` if needed. A typical trap: an early "access model" or
  "foundation" goal whose DoD or tagged scenarios exercise operations that
  later goals add;
- the Traceability table matches the WBS and FT tables;
- Before vs After and Backward Compatibility mention nothing the requirement
  does not imply (no gold-plating).

## Step 5 — Review gate

Show the user a compact summary: goals (ID, outcome, DoD count), feature tests
(ID, title, automation), BC impacts, risks. Point to the files for detail. Ask
for approval; approval triggers: *set `status: planned`, commit
`docs(vX.Y.Z.T): add plan and feature tests`, push `build/vX`*. Revise until
approved, then do exactly that.

**Bước tiếp theo:** `/engineer:architect`

Then run the silent retro (`${CLAUDE_PLUGIN_ROOT}/references/retro.md`).
