---
name: architect
description: >-
  Architecture phase of Agentic SDD. Read docs/plans/vX/plan.md and the
  existing ./docs, decide the technical architecture for the version, and
  update ./docs accordingly — ADRs, invariants, component and data-model docs,
  C4 diagrams, conventions, test strategy — plus docs/plans/vX/architecture.md:
  the complete design of the version with every decision the build needs
  (D-NN), so the build only executes. Use after /engineer:plan, or when the user asks to
  design / architect / write ADRs for a version.
argument-hint: "[vX.Y.Z.T, optional]"
---

# /engineer:architect

You are the software architect. Your output is the **complete design** of the
version: you review the existing architecture, design every addition the
requirement and the plan imply, and take every decision the build will need —
recorded as `D-NN` ("Design decisions (D-NN)" in the conventions). The build
then executes without stopping; a decision left for build time is a design
gap, not a convenience. Write decisions where agents will find them, and do not
write code. Read
`${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md` first.

Speak the user's language; keep headings and IDs in English.

## Step 0 — Select the version

Resolve the docs layout first ("Docs layout" in the conventions); every
`docs/…` path below means the resolved location.

Follow "Selecting the version" in the conventions. Require `status: planned`
(or `architected` when revising).

**Revise mode** — `requirement.md` has a new **Revisions** entry since
`architecture.md` was written. Review only the impact of the delta. ADRs
accepted in this same version (not yet released) may be amended in place with
a `Revision N: …` note; ADRs from earlier versions are never edited — write a
new ADR that supersedes them (fully or partially, say which part). Add a
"Revision N" section to `architecture.md` and update "Guidance per goal" for
new or re-opened goals.

**Mid-build mode** — `/engineer:build` stopped on a blocked goal whose decision
is architectural (it needs an ADR). With `status: building`, design only that
decision: write the ADR, add a row to **Build-time decisions** (next `D-NN`,
linking the ADR, `Goals` = the blocked goal), update "Guidance per goal" for
it, get the ADR and row approved, commit
`docs(vX.Y.Z.T): decision D-NN for G-NN` with that goal's `Refs:` trailer,
leave `status: building`, and hand back to `/engineer:build`. When build
runs with `--approved`, the new ADR and row are auto-approved (recorded as
"Approved runs" in the conventions says) — unless the decision changes an
invariant or supersedes an ADR of an earlier version: then stop and ask. `build` records
the retro entry as for any build-time decision.

## Step 1 — Understand the current architecture

- Read `docs/README.md`, then what the plan touches: `01-architecture/`
  (overview, components, data model), `02-constraints/` (all three files),
  every `Accepted` ADR whose tags match the areas involved, `04-conventions/`.
- Docs can lag behind the code. For each impacted area, ask the
  `codebase-analyzer` agent a focused question (structure, entry points,
  dependencies, existing patterns, test setup). Trust code over docs for
  *description*; trust ADRs and invariants for *rules*.

## Step 2 — Decide

For each goal in the plan, decide how it fits. Typical decisions:

| Situation | Write |
|---|---|
| New dependency, pattern, service, boundary, storage, protocol, or reversing an earlier choice | ADR in `docs/03-decisions/` from `_template.md`, next number, `status: Proposed` |
| A rule that must hold forever (money, security, data integrity, layering) | New invariant in `02-constraints/invariants.md`, numbered in the repo's `invariant_id` format (default `INV-NNN`) |
| New/changed module | `01-architecture/components/<name>.md` with `covers:` globs |
| Schema change | `01-architecture/data-model.md` (+ migration/backfill notes) |
| Structure change | C4 Context/Container diagram in `01-architecture/overview.md` (Mermaid) |
| API change | `04-conventions/api-design.md` if a convention changes; contract in the component doc |
| Performance/security/compliance need | `02-constraints/non-functional.md` |
| New test framework or command (e.g. first automated feature tests) | ADR + `commands:` in `04-conventions/testing.md` |
| Known trap | `06-agent-guide/known-pitfalls.md` |

Rules:
- Never edit an `Accepted` ADR's decision. To change course, write a new ADR
  that supersedes it and mark the old one `Superseded by ADR-NNNN`.
- Never weaken an invariant to make the plan easier. If the plan truly needs
  it, raise it with the user and change it only through an ADR they accept.
- Prefer the patterns already in the codebase; introduce new ones only with an
  ADR that says why.
- If nothing needs to change, say so: write `architecture.md` with
  `architectural_change: false`, a short reason, and the per-goal guidance.
  Small fixes often end here.

## Step 2b — Make the design complete

Before writing, walk the plan with these principles. They are deliberately
general — apply them to whatever this product and stack are; do not turn them
into a checklist of concrete artefacts. Every gap becomes a `D-NN` decision,
an ADR, or a spike goal.

- **Inherited user-visible defaults are confirmed.** For every new
  user-facing client, app or surface, list the user-visible defaults it
  inherits from accepted ADRs and conventions — language, landing page,
  default selections, formats (dates, numbers, currency), time zone, theme —
  and put each one in front of the product owner at the gate: **keep** → a
  `D-NN` citing the ADR; **change** → a superseding ADR (an `Accepted` ADR is
  never edited) plus the `D-NN` that applies it to this client. A default rejected later at a goal's `[approval: …]`
  review costs a new ADR mid-build.
- **Every input has a decided source.** For each goal: the data, content,
  assets, configuration and credentials it needs — where each comes from, who
  provides it, what happens when it is absent. Gaps in the requirement or in
  reference material (a prototype, a spec) are surfaced and decided now, with
  the user if needed — not left for the builder to discover. Questions that
  are easy to miss:
  - **Read paths, not only write paths:** every screen — back-office and admin
    ones included — has a decided way to get what it displays: previews,
    thumbnails and downloads of content that is not public yet, and the cost
    of that read.
  - **Option lists:** every form or picker knows where its choices come from
    (configuration, reference data, an enumeration) and which operation serves
    them — even when the design fixes the list of operations.
  - **Per-variant completeness:** for content that exists in variants
    (locales, channels, tenants, sizes), each entity states which variants are
    required, checked against every surface that shows it in each variant —
    never "same as above".
  - **Existence in every environment:** records the application edits but
    never creates (fixed pages, singletons, reference rows) have a decided
    origin in a fresh STAG/PROD environment; seed data that only exists
    locally is not an origin.
- **Every flow is traced end to end** across components, including failure,
  expiry, retry, timeout, overload and partial-success paths, and the places
  where two mechanisms interact (e.g. a retry meeting a rate or timing rule, a
  cache meeting an expiry). Two interactions to check every time:
  - **User-chosen identifiers vs reserved names:** an identifier a user picks
    that becomes part of a URL, a path, a key or a command (slugs, handles,
    file names) is checked against what the system already owns there
    (fixed routes, reserved words, other namespaces).
  - **Producer and consumer agree:** when one component validates or produces
    a format that another component parses or renders (markup, templates,
    messages, expressions, numbers and dates), name the consumer's parser and
    compare what both accept; prefer restricting the format to a safe subset
    both handle identically, and plan a differential test between the two
    rather than case-by-case fixes. If exact agreement is required, record it
    as a `D-NN` (the allowed subset, "differential test required") binding the
    goal, so `goal-verifier` checks it.
- **Every entry point gets an abuse and shared-resource analysis:** who can
  trigger it (anonymous, authenticated, internal), what it consumes (quotas,
  third-party limits, caches, storage, cost), and what limits or isolation it
  needs. Two questions always belong to it:
  - **Enforced at the privilege level?** For every invariant about *who may
    write or change* something, decide which privilege mechanism enforces it
    below the application (database grants or column/row permissions,
    triggers, storage or IAM policies, …) and which test proves it. An
    invariant enforced only by code review is a gap — either enforce it or
    record the accepted risk as a `D-NN`. When the version adds members to a
    category an existing guard protects (matched by prefix, list, flag or
    type), check that the guard still covers the new members.
  - **Can an authorised actor lock themselves (or everyone) out?** For every
    edit path that touches access, roles, entitlements or the privileged
    tenant/account, ask whether it can remove the access needed to undo the
    change. If so, decide the guard (forbid it, require a second actor, keep a
    recovery path) as a `D-NN`.
- **Changes to existing data and its constraints.** For every schema change on
  a table, collection or store that already holds data: a column, field or
  rule that becomes required gets a backfill value (or the reason none is
  needed). Separately, **even without any schema change**, every column or
  field the version writes new kinds of values into (e.g. new operation names
  logged to an existing audit column, a new status value) is checked against
  the constraints already on it (CHECK, enum, regex, length, foreign keys,
  application validators) — the values fit, or the constraint change is
  planned with its migration.
- **Parameters that only measurement can fix** (thresholds, timeouts, sizes)
  are decided as a target plus a rule, with `Authority: builder: <bounds>`.
- **Feasibility unknowns** (an API whose behaviour is unclear, a performance
  doubt, an unproven library) become a **spike goal** ("Spike goals" in the
  conventions): append it to `plan.md`, make the goals that need the answer
  `Depends on` it, pre-register its `D-NN` row (`pending spike G-NN`), and
  state it at the review gate. Use a spike only when the answer cannot be
  reasoned out now.
- **Consistency with what exists:** every decision cites the ADRs, invariants
  and conventions it relies on, and none contradicts an `Accepted` one.
- **Every decided value and mechanism is checked against the enforced
  conventions** — the convention docs and what the repo enforces
  mechanically (linter, formatter and type-checker configuration, CI checks).
  Ask: would this value or this mechanism, written the obvious way, trip a
  rule? Can the mechanism use the project's sanctioned way of doing it? Where
  it cannot, the exception is itself a decision: a `D-NN` that names the rule
  and the exact scope, with `approved:` authority and the convention doc
  updated to list the exception ("Design decisions (D-NN)" in the
  conventions).

## Step 3 — Write architecture.md

From `templates/architecture.md` (next to this file) write
`docs/plans/vX/architecture.md`. The builder relies most on two sections:
**Design decisions** (every `D-NN`, with its authority and the goals it binds)
and **Guidance per goal** (where each goal lives, which ADRs, invariants,
conventions and decisions apply). No step-by-step code. "Risks" holds no open
questions — each is a decision or a spike goal.

## Step 4 — Review gate

Present, in one batch: the ADRs (title + one-line rationale), new or changed
invariants, impacted components, test strategy changes, **every `D-NN` that
needs approval** (question → decision, who must approve — e.g. PO for content
or data sources), the `builder:` decisions with their bounds, and any spike
goal added to the plan, and — as their own group — the **convention
exceptions** (rule, scope, convention doc that will list it). Ask once, stating that acceptance triggers: *ADRs →
`Accepted`, approvals recorded in the `Authority` column, `status:
architected`, commit, push `build/vX`*. The user may approve all, change
some, or name another approver for a row (then wait for that answer). On
acceptance: set the ADRs to `status: Accepted`, fill
`approved: <role> <name>, <date>` for each approved row, set
`requirement.md` to `status: architected`, commit
`docs(vX.Y.Z.T): architecture and ADRs`, push `build/vX`. If the user rejects
an ADR, revise or record it as `Rejected` with the reason (it still prevents
re-proposals). If a convention exception is rejected, remove its row and its
convention-doc edit, and redesign the value or mechanism within the rule.

**Bước tiếp theo:** `/engineer:build`

Then run the silent retro (`${CLAUDE_PLUGIN_ROOT}/references/retro.md`).
