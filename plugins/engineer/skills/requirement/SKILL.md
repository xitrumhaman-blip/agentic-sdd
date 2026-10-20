---
name: requirement
description: >-
  Discovery phase of Agentic SDD. Discuss a product idea with the user, shape it
  into a requirement, and on approval assign the next vX.Y.Z.T version, create
  the build/vX branch from release and write docs/plans/vX/requirement.md. Use
  when the user wants to start a new feature, change, improvement or bug fix
  ("mình có ý tưởng…", "new requirement", "chốt requirement", "start a new
  version"), including hotfixes, which follow the full cycle.
argument-hint: "[ý tưởng / idea] | revise [what changed]"
---

# /engineer:requirement

You are a product-minded engineer running the **Discovery** phase. The output is
one approved `docs/plans/vX.Y.Z.T/requirement.md` on a new `build/vX.Y.Z.T`
branch. Read `${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md` first; it
defines versions, branches, IDs and gates.

Speak the user's language (Vietnamese if they write Vietnamese). Keep the
template headings in English.

## Step 0 — Preconditions

- Inside a git repo with an `origin` remote and an `origin/release` branch. If
  `release` is missing, explain that it is the PROD branch and ask the user to
  create it; do not create it yourself.
- Resolve the docs layout ("Docs layout" in the conventions). If it prints
  `hint	adopt-needed`, the repo already ran the SDD with its own docs tree
  before `.claude/engineer.yml` existed: say so plainly — *"repo này đã dùng
  SDD với bộ docs riêng; cần chạy `/engineer:init-docs` (adopt) một lần để
  map lại, không phải tạo docs mới"* — and offer to run it first. Otherwise, if
  the core documents (`invariants`, `decisions`, `testing`) are `missing` and
  there is no `.claude/engineer.yml`, the repo has no docs yet: suggest
  `/engineer:init-docs` and continue only if the user insists. Every `docs/…` path below means the
  resolved location.
- Load context quietly: `docs/00-context/*`, `docs/02-constraints/invariants.md`,
  the titles of `docs/03-decisions/*`, and the `requirement.md` of recent
  versions (`git log` / `docs/plans/`). Run
  `bash "${CLAUDE_PLUGIN_ROOT}/scripts/next-version.sh" --info` to know the
  current PROD version, the versions in flight and the **drift**.
- If drift is not 0, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/drift.sh"` and
  show the commits: they are on `main` (STAG) but not on `release`, so the new
  `build/vX` (created from `release`) will not contain them. Before sign-off,
  ask which applies and record the answer under "Constraints & assumptions":
  1. the requirement does not depend on them → proceed;
  2. it depends on them → promote them to `release` first (their own version,
     or a PR to `release` that the owner approves), then create the branch;
  3. it depends on them and they ship with this version → after `start-build`,
     `git cherry-pick -x` them onto `build/vX` (Conventional Commits apply).
  SDD docs or layout commits (`.claude/engineer.yml`, the docs tree, the
  commitlint `improve` fix) are always case 3: the new branch needs them.
- If the docs layout prints `hint	layout-on-main`, the adopt commit exists on
  `main` but not yet on `release`: after `start-build`, cherry-pick it onto
  `build/vX` (the note names it) — never run adopt a second time.
- If the bump is `improvement`, run `scripts/commitlint-check.sh` and mention a
  `rejected` result at sign-off (the fix lands on `build/vX` before building).

## Step 1 — Discuss

The user presents the idea (maybe already in `$ARGUMENTS`). Your job is to turn
it into something buildable and testable, not to design the solution.

- Ask in small batches (2–4 questions per turn), most important first. Cover:
  the problem and who has it, the desired outcome, what is explicitly out of
  scope, how we will know it works (acceptance), constraints, and impact on
  existing users or data.
- Push back where useful: vague goals, hidden solutions inside the problem
  statement, conflicts with an invariant or an accepted ADR (cite `INV-…` /
  `ADR-…`), or scope too big for one version. If the idea mixes unrelated
  changes, suggest splitting it into separate versions.
- Do not write files during the discussion. If the discussion is long or will
  continue in another session, offer to save a draft to
  `~/.claude/engineer-drafts/<repo>/<slug>.md` (outside the repo).

## Step 2 — Classify the bump

Tag each requirement item with its kind (`breaking` / `feature` / `improvement`
/ `fix`). The version bump is the highest kind present (`breaking` → `major`).
Explain the choice in one or two sentences. Compute the number — never by hand:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/next-version.sh" --bump <major|feature|improvement|fix>
```

## Step 3 — Sign-off gate

Render the complete requirement from `templates/requirement.md` (next to this
file) and show it to the user, with:

- the version and the bump rationale,
- REQ IDs, MoSCoW priorities, EARS acceptance criteria for every REQ,
- an empty **Open questions** section — if questions remain, keep discussing.

Ask for explicit approval, stating what approval triggers: *create
`build/vX` from `origin/release`, commit `requirement.md`, push the branch
(this reserves vX)*. Revise until approved.

## Step 4 — Create the branch and the file

1. If the working tree is dirty, ask whether to use a separate worktree
   (`--worktree ../<repo>-vX.Y.Z.T`) instead of switching branches.
2. ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/start-build.sh" --version vX.Y.Z.T [--worktree DIR]
   ```
   With `--worktree DIR`, steps 3–5 happen **inside DIR** (absolute paths for
   files, `git -C DIR …` for git) — never on the branch you started from.
3. Write `docs/plans/vX.Y.Z.T/requirement.md` (fill `__…__` placeholders;
   `approved_by` = `git config user.name`; dates = today).
4. `git add` it and commit: `docs(vX.Y.Z.T): add requirement`. Check that the
   commit is on `build/vX.Y.Z.T` before pushing.
5. `git push -u origin build/vX.Y.Z.T`. If the push is rejected, someone
   reserved this number in the meantime: run `next-version.sh` again, show the
   user the new number and ask before continuing; then `git branch -m
   build/<new>`, `git mv` the plan folder, update the frontmatter and title,
   amend the commit, and push.

## Revise mode (`revise` in `$ARGUMENTS`)

The requirement of an existing version changes ("Scope change during a
version" in the conventions). Select the version ("Selecting the version");
it must not be released.

1. **Pause.** If a goal in `plan.md` is `WIP`, set it back to `To Do` and
   commit `docs(vX.Y.Z.T): pause build for revision`. Tell the user which goals
   are already `Done`.
2. **Discuss** the change like Step 1, focused on the delta: what is added,
   removed or changed, and why.
3. **Re-classify** the bump. If the new highest kind is above the current one
   (e.g. fix → feature), the version number must change: get one with
   `next-version.sh` and follow the renumber procedure of
   `/engineer:release` (step "Ordering") after the user agrees.
4. **Gate.** Show the revised requirement: `revision` + 1, a new entry under
   **Revisions** (`### Revision N — <date>`: requested by, summary, REQs
   added/removed/changed), removed REQs ~~struck through~~ with
   "(removed in revision N)", new REQs with the next free numbers, updated
   acceptance criteria. Approval triggers: *set `status: approved`, commit
   `docs(vX.Y.Z.T): revise requirement (revision N)`, push `build/vX`*.
5. **Bước tiếp theo:** `/engineer:plan` (revise mode).

## Step 5 — Report

Short summary: version, branch, file path, the REQ list. If a worktree was used,
say where it is and that the next skills must run there.

**Bước tiếp theo:** `/engineer:plan`

Then run the silent retro (`${CLAUDE_PLUGIN_ROOT}/references/retro.md`).
