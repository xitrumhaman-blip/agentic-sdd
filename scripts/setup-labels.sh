#!/usr/bin/env bash
# setup-labels.sh — create the issue labels used by /engineer:feedback and
# /triage. Maintainers run it once (needs triage rights); re-running is safe.
set -euo pipefail
REPO="${1:-}"   # owner/name; default: the repository of the current directory
args=(); [[ -n "$REPO" ]] && args=(--repo "$REPO")

label() { bash "$(dirname "$0")/../plugins/engineer/scripts/gh.sh" label create "$1" ${args[@]+"${args[@]}"} --color "$2" --description "$3" --force >/dev/null && echo "✓ $1"; }

label feedback       "5319e7" "Filed through /engineer:feedback or the issue forms"
label bug            "d73a4a" "Something is not working"
label enhancement    "a2eeef" "New feature or improvement"
label documentation  "0075ca" "Guide or skill text"
label P1             "b60205" "Blocks the SDD cycle or risks wrong pushes/tags/PRs"
label P2             "fbca04" "Wrong output the user must fix by hand"
label P3             "c5def5" "Friction, wording"
for s in init-docs requirement plan architect build code-review run-tests sync-docs ship release status guide feedback next-version start-build; do
  label "skill:$s" "ededed" "engineer:$s"
done
