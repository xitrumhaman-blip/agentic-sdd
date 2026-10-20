---
name: release
description: >-
  Tag an Agentic SDD version for an environment. "stag": after PR #2
  (port/vX → main) is merged, create and push the vX.Y.Z.T-rc.N tag on main for
  STAG/UAT. "prod": after UAT passes, merge PR #1 (build/vX → release), create
  and push the vX.Y.Z.T tag on release, and publish the GitHub Release.
  "prod --uat-waived <reason>": release without STAG/UAT (e.g. no environments
  yet), recording the waiver in the tag and the release notes.
argument-hint: "stag|prod [vX.Y.Z.T] [--uat-waived \"<lý do>\"]"
disable-model-invocation: true
---

# /engineer:release

Read `${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md` ("Versions and
tags", "Human gates"). `S="${CLAUDE_PLUGIN_ROOT}/scripts"`. Call GitHub only as
`bash "$S/gh.sh" <gh args>` (see "GitHub CLI"; never through a variable
holding the command — zsh does not split it).

Arguments: `$ARGUMENTS` = `stag` or `prod`, optionally a version, and for
`prod` optionally `--uat-waived "<reason>"`. If the environment is missing, ask. Resolve the version per "Selecting the version"
(the build branch need not be checked out; read files with
`git show origin/build/vX:<path>`). `git fetch --tags --prune origin` first.

Docs paths (`docs/plans/…`) are resolved with `scripts/docs-layout.sh`
("Docs layout" in the conventions).

All tags are **annotated** and are created only after the user confirms the
exact tag name and target commit.

## stag — tag `vX.Y.Z.T-rc.N` on main

1. Find PR #2: `bash "$S/gh.sh" pr list --head port/vX.Y.Z.T --base main --state all --json number,state,mergeCommit,url`.
   - Not merged → tell the user to review and merge it with **Create a merge
     commit**. Offer `bash "$S/gh.sh" pr merge <n> --merge` if they want you to do it (ask).
   - Merged → target = its `mergeCommit`.
2. Check that the merge brought everything:
   `bash "$S/port.sh" --version vX.Y.Z.T --pending --against <merge commit>`.
   `PENDING>0` means the PR was squashed or is missing commits — warn the user
   (UAT fix rounds still work, but each round re-applies earlier changes) and
   list the pending commits.
3. `N` = 1 + the highest existing `vX.Y.Z.T-rc.*` tag (`git tag -l 'vX.Y.Z.T-rc.*'`).
4. If PR #2 starts with a **Tests skipped** warning, repeat it — UAT on this
   rc is then the only test of the port. Confirm, then:
   ```bash
   git tag -a vX.Y.Z.T-rc.N <merge commit> -m "vX.Y.Z.T-rc.N — <title> (STAG)"
   git push origin vX.Y.Z.T-rc.N
   ```
5. Give the user the **UAT checklist**: every FT of this version (ID, title,
   automation), highlighting the "needs UAT" ones from the test report, plus
   the Backward Compatibility items from `plan.md`.

**Bước tiếp theo:** UAT trên STAG. Pass → `/engineer:release prod`. Có lỗi →
`/engineer:build uat-fix: <mô tả lỗi>`.

## prod — tag `vX.Y.Z.T` on release

**UAT waiver.** With `--uat-waived "<reason>"`, steps 1 and 2 do not block:
run their checks anyway and report what was skipped (no rc tag, commits that
never reached `main`/STAG). The reason must be concrete ("no STAG environment
yet", "PO accepted after demo on build branch") — if it is empty or vague, ask
for one. Confirm the waiver as its own question, naming who waives it:
*"Release vX lên PROD **không qua UAT**, lý do: <reason>, người quyết định:
<name> — xác nhận?"*. `<name>` is the person the user says decided (default
`git config user.name`). The waiver is written into the tag message and the
release notes (step 5); it never replaces the ordering check (step 3).

1. **STAG ran everything.** With the latest rc tag of this version:
   `bash "$S/port.sh" --version vX.Y.Z.T --pending --against vX.Y.Z.T-rc.N`
   must report `PENDING=0`. Otherwise stop: a new rc round is needed
   (`/engineer:ship`, merge PR #2, `/engineer:release stag`) — or, only with
   `--uat-waived`, list the pending commits in the waiver confirmation.
2. **UAT.** At least one `-rc` tag exists for this version. Ask the user to
   confirm explicitly that UAT on the latest rc passed. Do not proceed on
   anything less — except with `--uat-waived`, where the waiver confirmation
   replaces this question. Without the flag and without any rc tag, tell the
   user the two ways forward: a STAG round, or `--uat-waived "<reason>"`.
3. **Ordering.** `bash "$S/next-version.sh" --check vX.Y.Z.T`. If blocked (a
   higher version reached PROD first), explain and offer to renumber:
   `next-version.sh --bump <bump>` → rename branch `build/vX` → `build/vNew`
   (push new, delete old remote — ask; deleting the old branch **closes PR #1**,
   so `ship` must open a new one), `git mv docs/plans/vX docs/plans/vNew`,
   `git mv docs/test-cases/unit-tests/vX.md docs/test-cases/unit-tests/vNew.md`,
   update frontmatter, `Refs:` in future commits and the CHANGELOG heading
   (FT IDs keep their original version — IDs never change), then
   `/engineer:ship` and `/engineer:release stag` again.
4. **Merge PR #1.** Find it: `bash "$S/gh.sh" pr list --head build/vX.Y.Z.T --base release --state all --json number,state,mergeCommit,mergedAt,url`.
   If open: show mergeability and checks, confirm, `bash "$S/gh.sh" pr merge <n> --merge`.
   Target = its `mergeCommit`.
   **Out-of-order merge.** If PR #1 is already merged, compare `mergedAt` with
   the latest rc tag's date (`git log -1 --format=%cI vX.Y.Z.T-rc.N`): merged
   before any rc tag, or before the latest one, means PROD code was merged
   before UAT finished. Say so plainly (with both timestamps) — never pass over
   it silently. Continue only with `--uat-waived` or after the user confirms
   that UAT has since passed on an rc that contains everything (step 1).
5. **Tag and release.** If PR #1 (or the merged PR #2 of the latest rc) starts
   with a **Tests skipped** warning (`/engineer:ship --skip-test`), repeat it in
   the confirmation. Confirm tag name + commit, then:
   ```bash
   git tag -a vX.Y.Z.T <merge commit> -m "vX.Y.Z.T — <title>"
   git push origin vX.Y.Z.T
   bash "$S/gh.sh" release create vX.Y.Z.T --verify-tag --title "vX.Y.Z.T — <title>" --notes-file <notes>
   ```
   With `--uat-waived`, the tag message carries the waiver as extra paragraphs
   (standard wording, so it can be grepped with `git tag -n99 | grep "UAT waived"`):
   ```bash
   git tag -a vX.Y.Z.T <merge commit> -m "vX.Y.Z.T — <title>" \
     -m "UAT waived: <reason>" \
     -m "Waived by: <name> on <YYYY-MM-DD>; rc tags: <list or none>; commits not on STAG: <n>"
   ```
   Notes: the CHANGELOG entry, then a short "Details" section linking
   `docs/plans/vX/requirement.md` and the two PRs. With a waiver, the notes
   start with a callout:
   `> [!WARNING]` / `> Released without UAT on STAG. Reason: <reason>. Waived by <name> on <date>.`
6. **Clean up (ask):** delete remote `build/vX` and `port/vX` (the tag now
   anchors the version), remove the port worktree (`git worktree remove`).

**Bước tiếp theo:** `/engineer:status` hoặc `/engineer:requirement` cho version kế tiếp.

Then run the silent retro (`${CLAUDE_PLUGIN_ROOT}/references/retro.md`).
