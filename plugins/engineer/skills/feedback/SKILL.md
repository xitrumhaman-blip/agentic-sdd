---
name: feedback
description: >-
  Report problems with and ideas for the engineer plugin itself as GitHub issues
  on the plugin's GitHub repository, built from the current conversation and the
  local feedback queue — the user only reviews the draft. Use when the user says
  a skill misbehaved, wants to report a bug or suggestion about the plugin or
  the SDD process, runs /engineer:feedback, or when queued feedback exists.
argument-hint: "[ghi chú thêm, optional]"
---

# /engineer:feedback

Goal: turn what already happened into good issues without making the user
retype anything. The issues are about the **plugin** (skills, scripts,
templates, agents, process docs), never about the product repo's own code.

Target repository `R`: `$ENGINEER_FEEDBACK_REPO` if set, otherwise the
`owner/name` of `repository` in `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.
`Q="${CLAUDE_PLUGIN_ROOT}/scripts/feedback-queue.sh"`,
`G="${CLAUDE_PLUGIN_ROOT}/scripts/gh.sh"` — every GitHub call is
`bash "$G" <gh args>`: it retries with the user's own `gh` login when an
app-scoped `GH_TOKEN` cannot see that repository (see "GitHub CLI" in the
conventions).

## Step 1 — Collect

1. **Queue:** `bash "$Q" list` — entries recorded by the silent retro of earlier
   skill runs (possibly other sessions or repos). Each has skill, kind, title,
   plugin version, repo.
2. **This conversation:** scan it for plugin friction — moments where the user
   corrected a skill's output, a plugin script failed, a skill instruction did
   not fit, a step was repeated or done by hand, or the user complained about
   the process. Also take anything the user wrote in `$ARGUMENTS`.
3. Plugin version: `version` in `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.

If nothing is found, ask the user in one line what they want to report.

## Step 2 — Shape issues

- One issue per distinct problem; merge queue entries and conversation findings
  that describe the same thing.
- Title: `<skill>: <problem>` (≤ 80 chars), e.g.
  `plan: WBS State column dropped when revising a plan`.
- Body:

  ```markdown
  **Skill:** engineer:<skill>   **Plugin version:** 0.x.y   **Kind:** bug | enhancement | docs
  **Repo stack:** <e.g. TypeScript/Next.js> (no repo name if the user prefers)

  ### What happened
  ### Expected
  ### Evidence
  (error output or paraphrased exchange — trimmed)
  ### Suggested fix
  ```

- **Redact.** No source code, secrets, tokens, URLs of internal systems,
  customer data, or the product's requirement content. Paraphrase instead.
- Labels: `feedback`, the kind (`bug` / `enhancement` / `documentation`), and
  `skill:<skill>`.

## Step 3 — Avoid duplicates

For each issue, search open issues:
`bash "$G" issue list --repo "$R" --state open --search "<key words> in:title" --json number,title,url`.
A clear match becomes a **comment** on that issue (new evidence, plugin
version) instead of a new issue.

## Step 4 — Review gate

Show the drafts (title + body, and "new" vs "comment on #N"). The user can
approve all, drop some, or edit. Send nothing before approval.

## Step 5 — Send

- New: `bash "$G" issue create --repo "$R" --title … --body-file … --label …`.
  If it fails because a label does not exist, retry without `--label` and add a
  `Labels: …` line at the top of the body.
- Comment: `bash "$G" issue comment <n> --repo "$R" --body-file …`.
- If `bash "$G"` still fails (it already retried with the user's own login), explain
  its note to the user, save the drafts to
  `~/.claude/engineer-feedback/outbox/` and tell the user to open them via
  `https://github.com/<R>/issues/new/choose`.

Then remove the sent queue entries: `bash "$Q" remove <files…>` (keep entries the
user dropped only if they asked to keep them).

Report the issue links. Do not run the silent retro for this skill.
