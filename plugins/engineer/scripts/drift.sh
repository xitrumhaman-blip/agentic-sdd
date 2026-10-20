#!/usr/bin/env bash
# drift.sh — list commits that are on main (STAG) but will never reach release
# (PROD) through the SDD flow: direct commits to main that are neither ports of
# a build branch (cherry-pick -x trailer), nor port-only fixes (`fix(port): …`),
# nor already present on release as an equivalent patch.
#
# A build branch starts from release, so code it depends on that exists only on
# main is silently missing from it. See references/sdd-conventions.md.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FETCH=1
for a in "$@"; do
  case "$a" in
    --no-fetch) FETCH=0 ;;
    -h|--help) echo "Usage: drift.sh [--no-fetch]   (exit 0 none, 1 some; prints DRIFT=<n>)"; exit 0 ;;
  esac
done

require_git_repo
(( FETCH )) && fetch_remote
remote_branch_exists "$MAIN_BRANCH" || die "'$REMOTE/$MAIN_BRANCH' not found."
remote_branch_exists "$RELEASE_BRANCH" || die "'$REMOTE/$RELEASE_BRANCH' not found."

# Patches already on release ("-" in git cherry) do not count.
equivalent="$(git cherry "$REMOTE/$RELEASE_BRANCH" "$REMOTE/$MAIN_BRANCH" | sed -n 's/^- //p')"

# Let git drop ports (-x trailer) and port-only fixes first: release..main
# grows with every port ever made, so per-commit checks must stay few.
candidates="$(git rev-list --reverse --no-merges --invert-grep -E \
  --grep='^\(cherry picked from commit [0-9a-f]{40}\)$' --grep='^fix\(port\)' \
  "$REMOTE/$RELEASE_BRANCH..$REMOTE/$MAIN_BRANCH")"

n=0
while read -r sha; do
  [[ -z "$sha" ]] && continue
  grep -qx "$sha" <<<"$equivalent" && continue
  git diff --quiet "$sha^" "$sha" 2>/dev/null && continue   # empty commit
  echo "drift: ${sha:0:9} $(git log -1 --format=%s "$sha")"
  n=$((n + 1))
done <<<"$candidates"

echo "DRIFT=$n"
(( n == 0 ))
