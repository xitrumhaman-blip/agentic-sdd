---
version: __VERSION__
requirement: ./requirement.md
created_at: __DATE__
---

# Plan — __TITLE__ (__VERSION__)

## Problem Statement
The problem this version solves, restated from `requirement.md` in a few
sentences, plus the constraints that shape any solution.

## Before vs After

| Aspect | Before (today) | After (__VERSION__) |
|--------|----------------|---------------------|
| … | What users/systems see now | What they will see |

## Backward Compatibility

| Impact | Who/what is affected | Resolution |
|--------|----------------------|------------|
| e.g. API field renamed | Mobile app ≤ v… | Keep old field as alias until v…; deprecation notice |

State "No backward-compatibility impact" explicitly if that is the case, and
why. Cover: data and migrations, public APIs/contracts, configuration,
behaviour users rely on, rollback.

## WBS

Goals are **outcomes**, not technical tasks — the builder decides how. `State`
is maintained by `/engineer:build`: `To Do` → `WIP` → `Done` (or `Dropped`
after a scope change).

| ID | Goal | Covers | Depends on | State |
|----|------|--------|------------|-------|
| G-01 | … | REQ-01 | — | To Do |

### G-01 — <goal title>
- **Outcome:** what is true for the user/system once this goal is reached.
- **Definition of Done:**
  - [ ] observable, verifiable condition
  - [ ] FT-__VERSION__-01 passes
  - [ ] unit tests cover the new or changed logic; mapped in `docs/test-cases/unit-tests/__VERSION__.md`
        _(or `N/A — <reason>` when the goal changes no code)_
  - [ ] _(only when a human must sign off)_ `[approval: PO]` <what is approved>
- **Feature tests:** FT-__VERSION__-01 _(scenarios spread over goals: `FT-…-NN (@G-01)`)_
- **Notes:** _(filled by /engineer:build: commits, deviations, decisions)_

## Feature tests

| FT ID | Title | Domain | Covers | Automation | Change |
|-------|-------|--------|--------|------------|--------|
| FT-__VERSION__-01 | … | … | REQ-01, G-01 | automated | new |

`Change`: `new`, `updated` (existing FT edited — keeps its old ID) or
`deprecated` (behaviour removed).

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|

## Out of scope
Copied from the requirement's Non-goals plus anything the plan deliberately
defers.

## Traceability

| REQ | Goals | Feature tests |
|-----|-------|---------------|
| REQ-01 | G-01 | FT-__VERSION__-01 |
