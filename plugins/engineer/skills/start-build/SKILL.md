---
name: start-build
description: >-
  Create the Agentic SDD integration branch build/vX.Y.Z.T from origin/release
  (in place or in a separate git worktree) for a newly approved version. Used by
  engineer:requirement at sign-off; use whenever a build branch must be created
  so the checks against duplicates and dirty trees are applied.
argument-hint: "vX.Y.Z.T [--worktree DIR]"
user-invocable: false
---

# engineer:start-build

Rules: "Environments and branches" in
`${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md`.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/start-build.sh" --version vX.Y.Z.T [--worktree DIR]
```

- Without `--worktree`, the current tree must be clean; the script switches to
  the new branch. With `--worktree DIR`, the current tree is untouched and all
  later work for this version happens in `DIR`.
- The script refuses if `origin/build/vX`, the tag `vX`, or a local branch of
  that name already exists.
- It does **not** push. The caller commits the first artifact
  (`requirement.md`) and then runs `git push -u origin build/vX.Y.Z.T`; that
  push is what reserves the version. A rejected push means someone else took
  the number: get a new one from `next-version.sh`, rename the branch
  (`git branch -m`), move `docs/plans/<old>` to `docs/plans/<new>`, update the
  frontmatter, amend, and push again.
