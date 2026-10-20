---
name: next-version
description: >-
  Compute the next Agentic SDD version vX.Y.Z.T for a bump kind (major,
  feature, improvement, fix) from the PROD tags on the release branch and the
  versions reserved by build/v* branches, or check that a version may go to
  PROD. Used by engineer:requirement and engineer:release; use it whenever a
  version number is needed — never compute one by hand.
argument-hint: "<major|feature|improvement|fix> | --info | --check vX.Y.Z.T"
user-invocable: false
---

# engineer:next-version

Rules: "Versions and tags" in `${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md`.

```bash
S="${CLAUDE_PLUGIN_ROOT}/scripts"
bash "$S/next-version.sh" --bump feature        # → v1.3.0.0
bash "$S/next-version.sh" --info                # base PROD version + reserved list
bash "$S/next-version.sh" --check v1.3.0.0      # exit 1 if not > every PROD tag
```

The script fetches from `origin` (add `--no-fetch` offline). It fails if
`origin/release` does not exist — report that to the user; the PROD branch must
be created by them.

Report the number with its basis, e.g. *"v1.3.0.0 (PROD hiện tại v1.2.0.4;
v1.3.0.0 chưa ai giữ chỗ)"*. Remember that the number is only reserved once
`build/vX` is pushed.
