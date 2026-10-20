---
name: plugins-resolve-feedback
description: >-
  Maintainer workflow that resolves feedback on the engineer plugin end to end:
  collect open issues filed by /engineer:feedback on this repository
  (plus unsent entries of the local feedback queue), triage them, implement the
  fixes in plugins/engineer, test scripts in a throwaway repo, run an
  independent review, bump the plugin version and CHANGELOG, and commit one
  Conventional Commit per issue group with "Closes #n". Use when the user asks
  to handle / fix / resolve plugin feedback or the open feedback issues.
argument-hint: "[--approved] [issue numbers or a label filter]"
---

# /plugins-resolve-feedback

You maintain the `engineer` plugin in this repo. Feedback arrives as GitHub
issues on this repository (label `feedback`, filed by
`/engineer:feedback`) and as unsent entries in the local queue. Your job is to
turn them into released-quality fixes. Speak the user's language (Vietnamese
if they write Vietnamese); keep code, skills and commits in English.

Lives only in this repo, like `/triage` (which stops after analysis — this
skill goes all the way to commits). Ground rules:

- **Single source of truth.** Process rules live in
  `plugins/engineer/references/sdd-conventions.md`. Change them there first,
  then align every skill, agent, template and guide page that depends on them.
  Read the conventions before changing anything.
- **GitHub only through** `bash plugins/engineer/scripts/gh.sh …` (it retries
  with the user's own login when an app-scoped `GH_TOKEN` cannot see the org).
- **Work on `main`**; the maintainer promotes `main` to `release`. Plugin
  versions are SemVer 3 digits in `plugins/engineer/.claude-plugin/plugin.json`.
- **Ask before anything outward-facing:** push, labels, comments, closing
  issues, filing queue entries as issues — unless `--approved` is given (see
  "Approved mode").

## Approved mode (`--approved` in `$ARGUMENTS`)

The user pre-approves the whole round, so run every step without stopping for
confirmation:

- **Scope:** every item still valid after triage; queue entries are resolved
  now (not filed first).
- **Designs:** for process changes, implement the design you propose in the
  triage table — still print the table, and in the final report list each
  process change with the design chosen so the user can revisit it.
- **Outward actions:** push `main`, add the priority labels, comment on
  issues that will not auto-close (queue items, already-fixed issues), close
  already-fixed issues — the comment must name the plugin version (CHANGELOG)
  or commit that fixed it — and remove resolved queue entries.

Still stop and ask, even with `--approved`, for:
- a process change that **weakens a safety gate** — skips or waives a human
  approval or confirmation, lets a skill push/tag/merge/file without asking,
  or removes a check — or that needs a **major** SemVer bump;
- an item that needs a product decision with no reasonable default;
- test failures or review findings you cannot fix;
- anything that would rewrite published history (force-push), touch
  `release` (the maintainer promotes `main`), or delete branches or tags.

When you stop on an item, finish and commit the other groups, but **push only
when nothing is pending** — otherwise leave the commits local and report.

The rest of `$ARGUMENTS` (issue numbers or a label) still filters Step 1.

## Step 0 — Preconditions

```bash
git switch main && git pull --ff-only && git status --porcelain
```

The tree must be clean. Note the starting point (`git rev-parse HEAD`) — the
review in Step 5 covers `<start>..HEAD`.

## Step 1 — Collect

1. Issues (filter with the non-flag part of `$ARGUMENTS` if given — numbers
   or a label):
   ```bash
   bash plugins/engineer/scripts/gh.sh issue list \
     --state open --label feedback --limit 200 --json number,title,labels,createdAt,url
   ```
   Then read each one fully, **including comments** — `/engineer:feedback` adds
   later occurrences of the same problem as comments, and they often widen the
   scope (e.g. "same issue also hit plan and architect"):
   `bash plugins/engineer/scripts/gh.sh issue view <n> --json title,body,comments`.
2. Local queue: `bash plugins/engineer/scripts/feedback-queue.sh list`. These
   were never filed. Show them and ask, per entry: resolve now (treated like an
   issue, no `Closes`), file it first with `/engineer:feedback`, or skip.

## Step 2 — Triage

For each item:

- **Still valid?** Check it against the current code and
  `plugins/engineer/CHANGELOG.md` — the reported plugin version may be old. If
  already fixed, plan a comment naming the version that fixed it.
- **Group** items with the same root cause (one fix, several `Closes`).
- **Priority:** P1 = blocks the cycle or risks a wrong push/tag/PR/issue (also
  anything that breaks GitHub access); P2 = wrong output the user must fix by
  hand; P3 = friction or wording.
- **Kind of change:** bug fix in a script/skill, new behaviour, or a **process
  change** (a gate, a status, a branch rule, a new marker in the templates).

Show one table — `#`, title, group, priority, kind, proposed fix in one line —
and the proposed SemVer bump (patch: fixes/docs only; minor: new behaviour or
options; major: a skill's contract or the conventions change incompatibly).
**Process changes need an explicit decision from the user** (e.g. "may UAT be
waived, and how is it recorded?"); propose a concrete design, do not pick one
silently. Proceed with the scope the user approves. With `--approved`, proceed
at once with the full scope and the proposed designs (see "Approved mode").

## Step 3 — Implement (one group at a time, P1 first)

For each group:

1. Find every place the behaviour lives: `grep -rn` across
   `plugins/engineer/{references,skills,agents,scripts,docs}` and
   `docs/design/`. A rule changed in one skill but not in the conventions, an
   agent, a template or the Vietnamese guide (`plugins/engineer/docs/guide/`)
   is the most common defect of this repo.
2. Change the conventions first, then the skills/agents/templates, then the
   guide (how-to/reference in Vietnamese) and `docs/design/agentic-sdd.md` if
   the design itself moved.
3. Scripts (`plugins/engineer/scripts/*.sh`) must:
   - run on macOS bash 3.2 with BSD tools (no associative arrays, no
     `${var,,}`, no GNU-only flags);
   - survive `set -euo pipefail`: a failing command substitution or a `grep`
     with no match aborts the script — guard with `|| true` where absence is
     normal;
   - never read stdin unless the command explicitly takes input from it (agent
     shells keep a non-terminal stdin open forever → hang);
   - never `rm` a path held in a variable that could point outside a temp dir
     you created (`mktemp -d` + `rm -rf "$tmp"` only);
   - resolve docs paths with `docs-layout.sh`, GitHub through `gh.sh`;
   - stay fast on large histories (let `git rev-list --grep/--invert-grep` do
     the filtering, not a per-commit loop).
4. Commit the group (Step 7 format) before moving on, so groups stay separable.

## Step 4 — Test

- Syntax: `for f in plugins/engineer/scripts/*.sh plugins/engineer/skills/*/scripts/*.sh scripts/*.sh; do bash -n "$f" || echo "FAIL $f"; done`
- Manifests: `claude plugin validate .` and `claude plugin validate plugins/engineer`.
- **Every changed script** runs in a throwaway repo with a bare remote, `main`
  and `release`, exercising the issue's scenario and its edge cases:
  ```bash
  T=$(mktemp -d); cd "$T"; git init -q --bare r.git; git clone -q r.git a; cd a
  git config user.email t@t; git config user.name t
  echo a > a; git add .; git commit -qm "chore: init"; git branch -M main
  git push -q origin main; git push -q origin main:release
  ```
  Wrap anything that could block in a timeout: `perl -e 'alarm 40; exec @ARGV' bash …`.
  For `gh.sh`-style logic, use a fake `gh` first on `PATH`.
- Skill discovery, when skills or agents were added or renamed:
  `claude -p --plugin-dir plugins/engineer "Without calling any tools: list every skill starting with 'engineer:' and every engineer agent."`
- What cannot be tested here (LLM-driven steps on a real product repo) is said
  explicitly in the final report, never implied as tested.

## Step 5 — Independent review

Spawn a `general-purpose` agent (foreground) to review `<start>..HEAD`: it reads
the diff, the touched files, and the issues (via `gh.sh`), runs the changed
scripts in a throwaway repo, and reports — without editing — script bugs (bash
3.2, `set -e` traps, stdin, performance), contradictions between files, and
fixes that do not fully address their issue. Fix every valid finding, retest,
and commit as `fix(engineer): … after review` with `Refs: #…`.

## Step 6 — Version and CHANGELOG

- Bump `version` in `plugins/engineer/.claude-plugin/plugin.json` (once per
  round; if the current version is still `unreleased` in the CHANGELOG, add to
  it instead of bumping again).
- `plugins/engineer/CHANGELOG.md` (Keep a Changelog): Added / Changed / Fixed
  entries written for plugin users, each with its issue number `(#n)`.

## Step 7 — Commits

- One commit per group, Conventional Commits, scope = skill or `engineer`:
  `fix(engineer): …`, `feat(release): …`.
- Body: what changed and why in a few lines, then one `Closes #n` line per
  issue (GitHub closes them when `main` is pushed), then the co-author trailer
  required by the environment.
- Check: `bash plugins/engineer/scripts/check-commits.sh --range <start>..HEAD`.

## Step 8 — Close out

1. Remove resolved entries from the local queue
   (`bash plugins/engineer/scripts/feedback-queue.sh remove <files…>`) and say so.
2. Ask before each outward action — or, with `--approved`, just do them: push
   `main`; label issues (`P1`…); comment "fixed in <version>, available after
   promotion to `release`" on issues that will not auto-close (queue items,
   already-fixed issues). After a push, confirm the `Closes` issues are closed.
3. Report in the user's language: a table issue → fix, what was tested and how,
   what was not tested, review findings fixed, version, commits (not pushed
   unless the user agreed), and the next step (push `main`, promote to
   `release`, users run `/plugin marketplace update agentic-sdd`). With
   `--approved`, also list the process-change designs chosen and anything you
   stopped on.
