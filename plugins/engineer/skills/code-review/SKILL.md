---
name: code-review
description: >-
  Review phase of Agentic SDD, between build and ship. Review everything the
  build implemented for a version (the build/vX changes against release) with
  Claude Code's /code-review when the harness allows it, otherwise with review
  agents, triage the findings against the
  version's design (D-NN, ADRs, invariants, conventions), apply the accepted
  fixes and optimisations through goal-builder with goal-verifier checks,
  rerun every unit and feature test, and record the round in
  docs/plans/vX/code-review.md so the version is ready to ship. Called by
  engineer:build before ship (and incrementally after UAT fixes); also use it
  when the user asks to review, optimise or clean up a built version.
argument-hint: "[vX.Y.Z.T] [--approved] [effort: low|medium|high|xhigh|max]"
---

# /engineer:code-review

You are the reviewing lead: an independent pass over the whole version after
the per-goal checks of `/engineer:build`, looking for what goal-by-goal
verification misses — correctness across goals, security, duplicated or
over-complex code, performance, and inconsistency with the rest of the
codebase. Read `${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md` first.

Speak the user's language. Keep IDs, commits and headings in English.

`--approved` in `$ARGUMENTS`: apply every finding you accept without asking,
record each as an auto-approval ("Approved runs (`--approved`)" in the
conventions), and still stop for the never-pre-approved cases — notably any
change to behaviour users see or to what an approved feature test checks.
Effort defaults to `high`.

## Step 0 — Select the version and the range

Resolve the docs layout ("Docs layout" in the conventions) and follow
"Selecting the version". Preconditions:
- every WBS goal is `Done` or `Dropped` (otherwise → `/engineer:build`);
- clean tree, `git pull --ff-only`, and `origin/release` merged in if it moved
  (as `build` Step 1 does; an unclear conflict stops even an approved run).

Range of this round:
- **Full** (first round, or `origin/release` was merged in since the last
  round): `BASE=$(git merge-base origin/release HEAD)` — exactly this
  version's changes.
- **Incremental** (a previous round exists in `docs/plans/vX/code-review.md`
  and no release merge happened since its `head`): `BASE=<that head>` — e.g.
  the UAT fixes since the last review.

Record `START=$(git rev-parse HEAD)`.

## Step 1 — Review

The built-in reviewer looks at "the current diff", so give it one that is
exactly this range, without touching the build branch:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/review-worktree.sh" create --base "$BASE" --head "$START"
```

It prints `REVIEW_WORKTREE=<dir>` and one `FILE=<path>` line per changed file:
a throwaway worktree inside the repo (`.engineer-review/`, git-excluded) where
`git diff` and `git diff HEAD` are precisely `BASE..START`. Findings refer to
paths relative to the repo root — the same in both trees. Pick the reviewer:

**A. Built-in `/code-review` — only when it can really see that diff.** Check
that the shell keeps its directory: run `cd "<dir>"` in one command, then
`pwd` in the **next** one. Many agent harnesses reset the shell to the repo
after every command ("Shell cwd was reset…"); then use B. If `pwd` prints
`<dir>`, invoke Claude Code's built-in skill named exactly **`code-review`**
(the `/code-review` command — not this skill, `engineer:code-review`) at the
chosen effort, asking for the full list of findings. Never pass `--fix` or
`--comment`: this skill decides what is applied, and nothing is posted
anywhere. Then `cd` back to the repo. **Sanity check:** if it reports an empty
diff, or its findings point at files not in the `FILE=` list, it reviewed the
wrong tree — discard its result and use B.

**B. Review agents — the default whenever A is not possible.** Spawn
`general-purpose` agents that work on `<dir>` by absolute path
(`git -C "<dir>" diff HEAD`, reading `<dir>/<file>`), asking each for
correctness bugs, security issues, reuse/simplification/efficiency
opportunities and convention departures — each with file:line, severity and
a concrete fix, no edits. Size the work from the `Range:` line: up to about
40 files **and** 3 000 changed lines, one agent. Above that, split by the
shallowest directory level that yields groups each under that size (e.g.
`src/billing/`, `src/catalog/` rather than `src/`), at most 6 area agents in
parallel, plus one agent for cross-area interactions (calls, contracts and
data shared between the areas). Merge their findings: the same file,
overlapping lines and the same root cause are one finding, keeping the
higher severity.

Either way, give the reviewer the context it cannot infer: the version's
`architecture.md` (Design decisions, Build-time decisions), the invariants
and the convention docs — so it does not "fix" deliberate decisions. Record
which reviewer was used (`reviewer: code-review | review-agents`). Afterwards
run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/review-worktree.sh" remove "<dir>"`
— never leave `.engineer-review/` behind: test runners and linters could pick
up the copy.

## Step 2 — Triage every finding

Number the findings `CR-NN` (continuing across rounds). For each, decide:

| Decision | When |
|---|---|
| **apply** | a real defect or a clear improvement in this version's code that keeps behaviour, the plan's DoD, every `D-NN`, ADR, invariant and convention intact |
| **reject** | false positive, a matter of taste, or it would contradict a `D-NN`, an `Accepted` ADR, an invariant or a convention — give the reason |
| **escalate** | it needs a decision (a new `D-NN`, a convention exception, an ADR or invariant change) — handled like a build-time decision (`build` Step 2.3) |
| **scope** | it would change behaviour users see or what an approved feature test checks — that is a scope question for the product owner (`/engineer:requirement revise`), never applied by a review |
| **defer** | valid but outside this version's code — note it for a later version |

Gate: show the table (ID, severity, kind, where, finding, decision) and ask
which to apply. With `--approved`, apply every **apply** and every
**escalate** that is pre-approvable; **scope** items and the
never-pre-approved cases still go to the user.

For escalations, the retro entry (if any) uses the title
*"code-review escalation: <kind of gap>"* (skill `architect`), not the
build-time decision title.

## Step 3 — Apply

Group the accepted findings by the WBS goal whose code they touch (a finding
spanning goals goes to the goal owning most of it). For each group:

1. Record `GBASE=$(git rev-parse HEAD)`.
2. Spawn **`goal-builder`** for that goal with the findings as its
   instructions ("review fixes: CR-02, CR-05 — …"), the plugin root and the
   resolved docs layout. Commits: `fix(<scope>): …` for defects,
   `refactor(<scope>): …` / `perf(<scope>): …` for optimisations, each with
   the goal's `Refs: vX.Y.Z.T/G-NN` trailer.
3. If the changes touch content covered by an `[approval: <role>]` item of
   that goal, get that approval again as `build` Step 2.3 does (auto in an
   approved run, recorded in the goal's Notes) before verifying.
4. Spawn **`goal-verifier`** on `$GBASE..HEAD` for that goal (same inputs as
   in `build`), telling it these are review fixes and may touch code of other
   goals named in the instructions. FAIL → back to 2 with the findings, at
   most twice, then report to the user. On the second FAIL in the same area,
   ask for a general rule instead of more case fixes (as `build` Step 2.5).

## Step 4 — Docs, then test everything

1. If the fixes changed structure (moved modules, new components) or test
   commands, invoke **`engineer:sync-docs`** first.
2. Invoke **`engineer:run-tests`** (all suites, every active FT) so a fresh
   report exists for the reviewed code.
3. Red → find the change that caused it; fix or revert it through
   `goal-builder` and `goal-verifier` exactly as in Step 3 (same `Refs:`
   rules), then rerun. A new skipped test is never accepted silently, not even
   with `--approved`.

## Step 5 — Record the round and commit

Update `docs/plans/vX/code-review.md` from `templates/code-review.md` (next to
this file): set the frontmatter to this round (`base`, `head` = HEAD after
fixes and tests, before the report commit, `reviewer`, `result`), and
**append** a `## Round N` section — earlier rounds stay. Commit
`docs(vX.Y.Z.T): code review round N` (no `Refs:` — it spans the version).

`ship` checks freshness with `report-fresh.sh --since <head>`: only docs and
tooling may change after a round without another review.

Tell the user: findings by decision, what changed, tests (counts), anything
escalated, scoped out or deferred, and — in an approved run — the
auto-approvals.

**Bước tiếp theo:** `/engineer:ship` (when called from `build`, `build`
continues to ship itself).

Then run the silent retro (`${CLAUDE_PLUGIN_ROOT}/references/retro.md`).
