---
name: triage
description: >-
  Maintainer-only triage of feedback issues filed against this plugin repo
  (this repository) by /engineer:feedback or by hand — group
  duplicates, label, prioritize, and propose the next plugin version's scope.
  Use when the user wants to review plugin feedback, triage issues, or decide
  what goes into the next engineer plugin release.
argument-hint: "[label or skill filter, optional]"
---

# /triage

Lives only in this repo (not shipped in the plugin). The plugin repo does not
run the SDD cycle on itself (plugin versions must be SemVer 3 digits in
`plugins/engineer/.claude-plugin/plugin.json`). Its flow: fixes land on `main`
with Conventional Commits, the version in `plugin.json` and
`plugins/engineer/CHANGELOG.md` are bumped, and the maintainer promotes `main`
to `release` (which users install).

## Step 1 — Collect

```bash
bash plugins/engineer/scripts/gh.sh issue list --state open --limit 200 \
  --json number,title,labels,createdAt,comments,body,url
```

Apply `$ARGUMENTS` as a filter if given (e.g. `skill:plan`, `bug`).

## Step 2 — Analyse

For each issue extract: skill, kind, plugin version reported, and the core
problem in one line. Then:

- **Group** issues describing the same root cause; pick the clearest as the
  primary, the others are duplicates.
- **Already fixed?** Compare the reported plugin version and the problem with
  `plugins/engineer/CHANGELOG.md` and the current skill text. If fixed, draft a
  closing comment naming the version that fixed it.
- **Classify** each group: `bug` (skill does the wrong thing), `enhancement`,
  `docs` (guide or skill text unclear).
- **Prioritize**: P1 = blocks the SDD cycle or risks wrong pushes/tags/PRs;
  P2 = wrong output the user must correct by hand; P3 = friction, wording.
- Recurrence counts: a problem reported from several repos or by several people
  ranks higher.

## Step 3 — Report

Show a table: group, primary issue, duplicates, kind, priority, affected
skill/files, one-line proposed fix. Below it, a proposal for the next plugin
version: which groups go in, and the SemVer bump (`patch` for fixes and docs,
`minor` for new behaviour, `major` if a skill's contract or the conventions
change incompatibly).

## Step 4 — Apply (only with approval)

Ask before each kind of action, then:
- add labels: `bash plugins/engineer/scripts/gh.sh issue edit <n> --add-label "P1,skill:plan"`;
- close duplicates with a comment linking the primary
  (`bash plugins/engineer/scripts/gh.sh issue close <n> --reason "not planned" --comment "Duplicate of #<m>"`);
- comment and close already-fixed issues.

**Next step:** implement the chosen groups on `main` (one commit per group,
`fix(<skill>): …` / `feat(<skill>): …`, with `Closes #<n>` in the body), bump
`plugin.json` + CHANGELOG, and let the maintainer promote `main` to `release`.
