---
name: status
description: >-
  Show where every Agentic SDD version of this repo stands — reserved, approved,
  planned, architected, building, in review, on STAG, released — with PR states,
  WBS progress of the current version, the latest PROD versions, queued plugin
  feedback, and the exact next command for each. Use when the user asks
  "đang ở bước nào", "status", "what's next", or seems unsure how to continue.
argument-hint: "[vX.Y.Z.T, optional]"
---

# /engineer:status

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"
```

(`--no-gh` if `gh` is not authenticated; `--no-fetch` offline.)

If a version argument is given, or the current branch is `build/vX`, also read
`docs/plans/vX/plan.md` and count the WBS `State` values (`Done / WIP / To Do`).

Present one compact table in the user's language — version, status, PRs, next
step — using this mapping:

| Status | Next step |
|---|---|
| reserved (no requirement) | Finish `/engineer:requirement`, or delete the branch to release the number |
| `approved` | `/engineer:plan` (revise mode if `plan.md` exists and the requirement has a new revision) |
| `planned` | `/engineer:architect` |
| `architected` | `/engineer:build` |
| `building` | `/engineer:build` (resumes at the first goal not Done) |
| `in-review`, both PRs open | Review + merge PR #2 into `main` (merge commit), then `/engineer:release stag` |
| `building` with all goals Done, no `code-review.md` yet | `/engineer:code-review`, then `/engineer:ship` |
| `building` with all goals Done and reviewed, or a PR missing | `/engineer:ship` (resumes) |
| `staging (rc.N)` | UAT on STAG → pass: `/engineer:release prod`; bug: `/engineer:build uat-fix: …` |
| `released` | Clean up `build/` and `port/` branches if still present |
| `abandoned` | Delete `build/vX` to free the number |
| `… [local, not pushed]` | Push `build/vX` — the number is not reserved yet |

Status marked with `*` (e.g. `planned*`) has uncommitted changes in the working
tree — mention it.

If two versions are in flight, remind the user that PROD must receive them in
ascending order (`/engineer:release prod` checks this).

If `bash "${CLAUDE_PLUGIN_ROOT}/scripts/docs-layout.sh"` prints
`hint	adopt-needed`, add: *"Repo đã dùng SDD nhưng chưa có
`.claude/engineer.yml` — chạy `/engineer:init-docs` (adopt) một lần."*
If it prints `hint	layout-on-main`, add instead: *"Config docs đã có trên
`main` nhưng chưa có ở nhánh này — cherry-pick commit đó sang, không adopt
lại."*

If `Feedback queued` is above 0, add one line: *"Có N feedback cho plugin chưa
gửi → `/engineer:feedback`."*
