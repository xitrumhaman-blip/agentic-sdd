---
name: build
description: >-
  Build phase of Agentic SDD. Implement the WBS goals of docs/plans/vX/plan.md
  on the build/vX branch — one goal-builder subagent per goal, checked by a
  goal-verifier subagent — keep the State column up to date, run all unit and
  feature tests, sync docs, then hand over to engineer:ship to open the PRs.
  Also handles UAT fix rounds while a version is on STAG. Use after
  /engineer:architect, to resume an interrupted build, or when UAT finds a bug.
argument-hint: "[vX.Y.Z.T] [--approved] [uat-fix: <bug description>]"
---

# /engineer:build

You are the build lead. You orchestrate; subagents write and verify code. Read
`${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md` first.

Speak the user's language. Keep commits, IDs and headings in English.

**`--approved`** in `$ARGUMENTS`: the user pre-approves every proposal that
comes up during this build — read "Approved runs (`--approved`)" in the
conventions for exactly what that covers, how each auto-approval is recorded,
and the cases where you must still stop and ask. Wherever a step below says
"ask", "show the user … and ask" or "once the user approves", an approved run
records the auto-approval and continues, unless the case is on the
never-pre-approved list (a merge conflict whose intent is unclear in Step 1
is one of them). In an approved run only, pass `--approved` on to
`engineer:code-review`, `engineer:ship` and `/engineer:architect` (mid-build
mode).

## Step 0 — Select the version and the mode

Resolve the docs layout first ("Docs layout" in the conventions); every
`docs/…` path below means the resolved location.

Follow "Selecting the version" in the conventions, then pick the mode:

| Status | Mode |
|---|---|
| `architected` | Build every goal that is not `Done` or `Dropped` (after a revision, Done goals stay Done unless the plan re-opened them) |
| `building` | Resume: continue with goals not `Done`/`Dropped`. For a `WIP` goal, do not commit WIP again: set `BASE` to its `docs(vX.Y.Z.T): start G-NN` commit (`git log --grep "start G-NN" -1 --format=%H`), keep its commits and any recorded approval, and continue at step 2 with "resume: <what the log shows is done>" as findings |
| `in-review` or `staging` (an `-rc` tag exists), with a bug description | **UAT fix**, see Step 5 |
| `building` or `architected` with every goal `Done`/`Dropped`, no fresh `code-review.md` | Continue at **Step 3** (tests), then Step 4 (sync-docs, code review, ship) |
| `in-review` without a bug description, or reviewed and green but no PRs yet | Re-ship: invoke `engineer:ship` (it resumes) |
| anything else | Stop and point to the missing phase |

The frontmatter `status` decides the mode. An rc tag matters only when the
status is `in-review`: after a scope revision on STAG the status is back to
`architected`/`building` and the normal or resume mode applies.

## Step 1 — Prepare

1. Working tree clean; `git pull --ff-only`.
2. If `origin/release` has moved since the branch was created
   (`git merge-base --is-ancestor origin/release HEAD` fails), merge it:
   `git merge origin/release` (merge commits are exempt from the commit
   check). Resolve conflicts preserving both intents; ask if unsure.
3. Read `docs/plans/vX/architecture.md`, `plan.md`,
   `docs/02-constraints/invariants.md`, `docs/04-conventions/testing.md`.
4. Make sure `testing.md` has `commands:` for at least `unit` (and `feature`
   if any FT is automated). If missing, detect them (ask `codebase-analyzer`),
   confirm with the user, and write them back.
5. If any commit of this version will use the `improve` type (bump
   `improvement`, or improvement items in the plan), run
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/commitlint-check.sh"`; on `rejected`,
   apply the fix from `${CLAUDE_PLUGIN_ROOT}/references/commitlint.md` first
   (a `build: allow the improve commit type` commit on `build/vX`), so the
   commit-msg hook does not reject the builder's commits.
6. Normal mode only: set `status: building`, commit
   `docs(vX.Y.Z.T): start build`.

## Step 2 — Goal loop

Order goals by `Depends on`; skip `Done` and `Dropped`. If the PO changes the
scope mid-build, stop the loop and switch to `/engineer:requirement revise`
("Scope change during a version" in the conventions). One goal at a time (they share the
working tree). For each goal:

1. Set its `State` to `WIP` in the WBS table and commit it right away:
   `docs(vX.Y.Z.T): start G-NN` with trailer `Refs: vX.Y.Z.T/G-NN` (a real
   trailer, in one block with any co-author line — "Commits and PRs" in the
   conventions). The tree
   is clean before any subagent starts. Record `BASE=$(git rev-parse HEAD)`.
2. Spawn the **`goal-builder`** agent (may be listed as `engineer:goal-builder`)
   with: version, goal ID, the absolute plugin root (`${CLAUDE_PLUGIN_ROOT}`
   expanded), the resolved docs layout (output of `docs-layout.sh`), and — on
   a retry — the verifier's findings verbatim.
3. If the builder reports `blocked`: stop the loop and bring the decision to the
   user. The builder proposes it in the `D-NN` format ("Design decisions" in
   the conventions). An architectural one needs an ADR → `/engineer:architect`
   in mid-build mode, then resume here. Otherwise, once the user approves, append it
   to **Build-time decisions** in `architecture.md` (next `D-NN`, `approved:`
   authority) — if it grants an exception to an enforced convention, also list
   the exception in that convention doc — commit
   `docs(vX.Y.Z.T): record decision D-NN` with the goal's `Refs:` trailer, record one silent retro entry (skill `architect`, kind
   `enhancement`, title *"build-time decision: <kind of gap>"* where the kind
   is one of: input source, mechanism interaction, abuse/shared resource,
   measured parameter, feasibility, convention conflict, existing
   data/constraint, other — never the product question itself,
   see `retro.md`; the end-of-run retro does not record it again), and spawn
   the builder again with the decision. `builder:`-authority decisions settled
   inside their bounds are not blocks: copy the reported value into the
   decision's row.
   **Approval items.** If the goal's DoD has `[approval: <role>]` items, show
   the user the builder's review summary for each and ask for that role's
   sign-off. Changes requested → spawn `goal-builder` again with them as
   findings and ask again. Approved → record
   `Approved: <role> <name>, <YYYY-MM-DD> — <item>` in the goal's Notes and
   commit `docs(vX.Y.Z.T): record approval for G-NN` with the goal's `Refs:`
   trailer.
4. Spawn the **`goal-verifier`** agent with: version, goal ID, range
   `$BASE..HEAD`, the resolved docs layout, and the absolute path of
   `${CLAUDE_PLUGIN_ROOT}/scripts/check-commits.sh`. Say that `plan.md` and
   `architecture.md` changes in the range are the orchestrator's (State,
   approvals, recorded decisions), as are convention-doc lines listing an
   exception granted by a decision recorded in the range. Every commit in `$BASE..HEAD` — the
   builder's and the orchestrator's — carries the goal's `Refs:` trailer.
5. A **plan defect** reported by the verifier (an item that needs a later
   goal's capability, "Feature tests spanning several goals" in the
   conventions) is fixed by you, not by the builder: move the item or scenario
   tag to the first goal that delivers the capability, commit
   `docs(vX.Y.Z.T): move <item> to G-MM` with the current goal's `Refs:`
   trailer, tell the user, and re-verify.
   On **FAIL**: back to 2 with the findings. If it is the **second FAIL on the
   same area** (the same component or rule, with new failing cases), do not
   send the cases alone: ask the builder to generalise — replace case-by-case
   patches with one general rule (e.g. restrict an accepted format to a safe
   subset, within what the DoD, feature tests and `D-NN` allow) and, when two implementations must agree, add a differential or
   property-based test between them before handing back. A **convention exception**
   finding is not retried as is: treat it as the builder's `blocked` (step 3)
   — the builder proposes a `D-NN` (or removes the need for the exception);
   never a second suppression attempt. After 2 failed retries, stop and show
   the user the open findings. If the rework changes approved content,
   the approval must be given again (step 3).
6. On **PASS**: if the goal is a spike, fill its pre-registered `D-NN` row
   (ask the approver it names, if any) — not a build-time decision, no retro.
   Set `State` to `Done`, fill the goal's **Notes** (commit SHAs,
   deviations from the builder's report), add any reported pitfall to
   `docs/06-agent-guide/known-pitfalls.md`, and commit
   `docs(vX.Y.Z.T): complete G-NN` with trailer `Refs: vX.Y.Z.T/G-NN`.
7. Give the user a one-line progress update (`G-02 Done — 3/5`).

Push `build/vX` every few goals so progress is visible to `/engineer:status`.
Ask once, at the start of Step 2: *"Mình sẽ push `build/vX` định kỳ trong lúc
build — đồng ý không?"* If the user declines, push only at ship time. With
`--approved`, do not ask: push.

## Step 3 — Full test run

Invoke the **`engineer:run-tests`** skill (all suites, all FTs). If anything is
red: decide which goal it belongs to, record `BASE=$(git rev-parse HEAD)`,
spawn `goal-builder` with the failure as findings, verify with range
`$BASE..HEAD` (the fix commits carry that goal's `Refs:`), and rerun until
green. A failure unrelated to this version
(pre-existing flaky test) is reported to the user, not silently skipped.

## Step 4 — Docs, code review and hand-over

1. Invoke **`engineer:sync-docs`** for this version.
2. Invoke **`engineer:code-review`** (with `--approved` if this run has it):
   it reviews the whole version's implementation, applies the accepted
   fixes and optimisations, and reruns every test, leaving a fresh green
   report.
3. Show the user: goals done, review findings applied/rejected, tests green
   (counts), deviations, docs updated — and, in an approved run, the list of
   auto-approvals.
4. Ask: *"Sẵn sàng mở PR (build→release và port→main)?"*. On yes, invoke
   **`engineer:ship`**. In an approved run, do not ask: invoke it with
   `--approved`.

## Step 5 — UAT fix mode

Used when STAG testing finds a problem in this version.

1. Get the bug description (from `$ARGUMENTS` or ask): steps, expected, actual.
2. Decide the affected goal. If the behaviour was never specified, the gap is in
   the plan: add or update a feature test first (the bug becomes a scenario),
   and note it in the goal's Notes.
3. Spawn `goal-builder` for that goal with the bug as findings; then
   `goal-verifier` on `$BASE..HEAD` (`BASE` recorded before spawning the
   builder); commits use `fix(<scope>): …` with the goal's `Refs:` trailer.
4. `engineer:run-tests`, then `engineer:code-review` (incremental: it reviews
   only the commits since its last round), then `engineer:ship` — it updates
   PR #1 and ports only the new commits to `main` for the next rc round.

**Bước tiếp theo:** handled by `engineer:ship` (merge PR #2, then
`/engineer:release stag`).

Then run the silent retro (`${CLAUDE_PLUGIN_ROOT}/references/retro.md`).
