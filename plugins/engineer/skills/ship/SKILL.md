---
name: ship
description: >-
  Open the two Agentic SDD pull requests for a built version — PR #1
  build/vX → release (PROD) and PR #2 port/vX → main (STAG, cherry-picked from
  the build branch, conflicts resolved, tests rerun) — after checking
  Conventional Commits and the test report, and writing the CHANGELOG entry.
  Called by engineer:build; run /engineer:ship directly to resume an
  interrupted ship. Reruns after UAT fixes update both PRs. With
  --skip-test (user-invoked only) the PRs are opened without running or
  requiring tests, and both PRs say so.
argument-hint: "[vX.Y.Z.T] [--approved] [--skip-test [\"<lý do>\"]]"
---

# engineer:ship

Read `${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md` first ("Environments
and branches", "Commits and PRs"). `S="${CLAUDE_PLUGIN_ROOT}/scripts"`. Call GitHub only as
`bash "$S/gh.sh" <gh args>` (see "GitHub CLI"; never through a variable
holding the command — zsh does not split it).

Resolve the docs layout first ("Docs layout" in the conventions); every
`docs/…` path below means the resolved location.

**`--skip-test`** ("Skipping tests at ship" in the conventions): only when the
user typed it in this `/engineer:ship` call — never because `build`,
`code-review` or `--approved` passed something on, and never on your own
initiative. It changes exactly these steps: gates 2 and 3 become warnings, the
port worktree is not tested (Step 5), and both PRs carry a **Tests skipped**
section (Steps 4–5). Take the reason that follows the flag; if there is none,
ask for one short line (in an approved run, record "no reason given").

## Step 1 — Gate checks (stop on any failure)

On `build/vX`, clean tree, then:

1. Every WBS goal is `Done`.
2. `docs/plans/vX/code-review.md` exists and its last round covers the
   current code: `bash "$S/report-fresh.sh" --since <head: from its
   frontmatter>` prints `fresh`. Otherwise say so and offer
   `engineer:code-review` (in an approved run, run it). It reruns the tests,
   so do this before the next check. With `--skip-test`: do not run the
   review (it runs tests) — note "review missing/stale" for the PRs and go on.
3. `docs/plans/vX/test-report.md` has `result: green` and is still fresh:
   `bash "$S/report-fresh.sh" --since <commit: from the report frontmatter>`.
   Changes to the docs, `CHANGELOG.md`, `.claude/` and the repo's
   `test_report_ignore` patterns do not count (feature-test docs, the testing
   commands and `.claude/engineer.yml` always do). Anything but `fresh`
   (exit 0) → invoke `engineer:run-tests` again; exit 2 means the call itself
   failed — read the error first. With `--skip-test`: run no tests; record the
   report's state for the PRs — `green, fresh`, `green, stale since <commit>`,
   `red`, or `none`.
4. `bash "$S/check-commits.sh" --range origin/release..HEAD`. If commits fail and
   are not yet on the remote, reword them (non-interactive rebase with
   `GIT_SEQUENCE_EDITOR`/`GIT_EDITOR`). If they are already pushed, explain
   that fixing them needs a force-push of `build/vX` and ask first.
5. `bash "$S/commitlint-check.sh"`: if the repo's commitlint rejects a type this
   version uses (typically `improve`), CI will reject the PRs — stop and offer
   the fix from `${CLAUDE_PLUGIN_ROOT}/references/commitlint.md` (a
   `build: allow the improve commit type` commit on `build/vX`).

## Step 2 — CHANGELOG and status

1. `CHANGELOG.md` at the repo root (create with the Keep a Changelog header if
   missing). Add or update the entry for this version, newest first:

   ```markdown
   ## [vX.Y.Z.T]
   ### Added | Changed | Deprecated | Removed | Fixed | Security
   - user-facing line (REQ-01)
   ```

   No date: the release date is the GitHub Release created by
   `/engineer:release prod`. Write for end users, from the requirement and the
   commits — not a commit dump.
2. Commit `docs(vX.Y.Z.T): update changelog` (skip if unchanged).

## Step 3 — Confirm

With `--approved` (passed by an approved `build` or `code-review` run, see
"Approved runs" in the conventions): show what will happen and continue
without asking. Otherwise show what will happen and ask once:
*push `build/vX`; open/update PR #1 → `release`; build `port/vX` from `main`
(cherry-pick), rerun tests there; push it; open/update PR #2 → `main`.*

## Step 4 — PR #1 (build → release)

```bash
git push origin build/vX.Y.Z.T
```

Title per conventions — validate it:
`bash "$S/check-commits.sh" --title "<title>" --bump <bump from requirement.md>`.
Body (write to a temp file, `--body-file`):

- Summary (from the requirement), link to `docs/plans/vX/` files
- Goals table (ID, outcome, Done)
- Backward compatibility notes, ADRs added
- **Auto-approved during build** — every `approved: auto (--approved …)`
  record of this version (D-NN rows, approval items, ADRs, code-review fixes),
  so reviewers check them before merging; omit the section if there are none
- Test report summary + needs-UAT list
- With `--skip-test`, at the top of the body:
  `> [!WARNING]` / `> Tests skipped at ship (--skip-test). Reason: <reason>.
  Requested by <git user.name> on <date>. Test report: <state from gate 3>.
  Code review: <fresh | stale | missing>.` — UAT on STAG must cover the gap.
- "Merge only after UAT passes on STAG, with **Create a merge commit**."

Create with `bash "$S/gh.sh" pr create --base release --head build/vX.Y.Z.T`, or update the
existing one with `bash "$S/gh.sh" pr edit` (find it with `bash "$S/gh.sh" pr list --head build/vX.Y.Z.T`).

## Step 5 — PR #2 (port → main)

```bash
bash "$S/port.sh" --version vX.Y.Z.T
```

- Exit 0: continue. Read `PORT_WORKTREE=` from the output.
- Exit 3 (conflict): in `PORT_WORKTREE`, resolve each file keeping both what
  `main` already has and what this version adds (STAG may contain other
  versions in flight). For `CHANGELOG.md`, keep all entries, newest version
  first. If intent is unclear, ask the user. Then
  `git -C <worktree> add … && git -C <worktree> cherry-pick --continue` and run
  `port.sh` again until exit 0.

Then, in the port worktree (skip this paragraph with `--skip-test`, and say in
PR #2 that the port, including any resolved conflicts, was not tested): invoke
`engineer:run-tests` with `--no-report` (setup + all suites). Every test that ran on the build branch must also run
(not be skipped or missing) on the port; extra tests on the port are normal —
`main` may carry other versions in flight. Fix port-only failures with commits on `port/vX`
(`fix(port): …`) and tell the user — they exist only on STAG.

Push: `git -C <worktree> push -u origin port/vX.Y.Z.T`; if the branch was
restarted from `main` after an earlier round, use `--force-with-lease`
(say so in the Step 3 confirmation; pre-approved in an approved run, see
"Approved runs" in the conventions).
Open or update PR #2 with `bash "$S/gh.sh" pr create --base main --head port/vX.Y.Z.T`,
same title, body = the **Tests skipped** warning if any, PR #1 summary + link
to PR #1 + port notes (conflicts resolved, port-only fixes, test results) +
"Merge with **Create a merge commit** (not squash), then run
`/engineer:release stag`."

## Step 6 — Status

First ship only, once PR #2 exists: set `status: in-review` in
`requirement.md`, commit `docs(vX.Y.Z.T): in review`, push `build/vX` (part of
the confirmed push of Step 3), and port that commit too (rerun `port.sh`, push
`port/vX`) so both branches agree.

## Step 7 — Report

PR links, test results on both branches, conflicts resolved.

**Bước tiếp theo:** review và merge PR #2 vào `main` (merge commit), rồi
`/engineer:release stag`.

Then run the silent retro (`${CLAUDE_PLUGIN_ROOT}/references/retro.md`).
