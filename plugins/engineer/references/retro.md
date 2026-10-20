# Silent retro (last step of every user-facing skill)

Purpose: capture friction with the plugin itself at the moment it happens, so
`/engineer:feedback` can report it later without the user retyping anything.
This is about the **plugin** (its skills, scripts, templates, agents), not about
the product being built.

## What counts as friction

Record an entry only if at least one of these happened during this skill run:

- The user corrected or rejected output the skill produced ("sai rồi", "không
  phải vậy", "redo", manual edits to a generated file).
- A plugin script failed, or its output was wrong or confusing.
- An instruction in the skill was ambiguous, contradictory, or did not fit this
  repo (e.g. a stack the skill did not anticipate), and you had to improvise.
- A step had to be repeated, or the user had to do by hand something the skill
  should have done.
- The user explicitly said the process or tool was awkward.
- The build had to stop for a decision the design could have taken. `build`
  records these itself (skill `architect`, the kind of gap only — never the
  product question); do not record them a second time here.

If nothing like that happened, do nothing and say nothing.

## How to record

Pipe a short Markdown body into the queue script. One entry per distinct
problem:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/feedback-queue.sh" add \
  --skill "<skill name, e.g. plan>" \
  --kind "<bug | enhancement | docs>" \
  --title "<one line, plugin-centric, e.g. 'plan: WBS table loses State column on re-run'>" <<'EOF'
**What happened:** …
**Expected:** …
**Evidence:** short excerpt of the error or of the user's correction (paraphrased)
**Suggested fix:** … (optional)
EOF
```

Rules:
- Never include source code, secrets, credentials, customer data, or the
  product's requirement content. Describe the plugin problem in generic terms.
- Keep each entry under ~15 lines.
- Do not ask the user for permission and do not interrupt the flow; this writes
  only to `~/.claude/engineer-feedback/queue/` on their machine. Mention it in
  one short line at most: "(Đã ghi 1 feedback cho plugin — gửi bằng
  `/engineer:feedback`.)"
