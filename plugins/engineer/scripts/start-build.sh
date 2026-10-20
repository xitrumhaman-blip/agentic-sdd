#!/usr/bin/env bash
# start-build.sh — create build/vX.Y.Z.T from the release branch.
#
# The branch is NOT pushed here. The caller commits the first artifact
# (requirement.md) and then pushes: because that commit is unique, a concurrent
# reservation of the same number is rejected by the remote instead of silently
# succeeding. See references/sdd-conventions.md.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  cat <<'EOF'
Usage: start-build.sh --version vX.Y.Z.T [--worktree DIR]

  --version   Version to reserve (from next-version.sh).
  --worktree  Create the branch in a new git worktree at DIR instead of
              switching the current working tree (which must then be clean).

Afterwards: commit requirement.md, then `git push -u origin build/vX.Y.Z.T`.
A rejected push means someone reserved the number first: re-run
next-version.sh and rename the branch.
EOF
}

VERSION=""; WORKTREE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)  VERSION="${2:-}"; shift 2 ;;
    --worktree) WORKTREE="${2:-}"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

require_git_repo
is_version "$VERSION" || die "--version must look like v1.3.0.0 (got '$VERSION')."
BRANCH="build/$VERSION"

fetch_remote
remote_branch_exists "$RELEASE_BRANCH" || die "'$REMOTE/$RELEASE_BRANCH' not found."
remote_branch_exists "$BRANCH" \
  && die "$REMOTE/$BRANCH already exists: $VERSION is reserved. Re-run next-version.sh."
git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null \
  && die "tag $VERSION already exists."
git show-ref --verify --quiet "refs/heads/$BRANCH" \
  && die "local branch $BRANCH already exists. Delete it or pick another version."

# Warn (do not fail) about code that exists on main only: the new branch,
# created from release, will not contain it.
if ! bash "$(dirname "${BASH_SOURCE[0]}")/drift.sh" --no-fetch >&2; then
  echo "Warning: the commits above are on $MAIN_BRANCH but not on $RELEASE_BRANCH; $BRANCH will not contain them." >&2
fi

if [[ -n "$WORKTREE" ]]; then
  git worktree add -b "$BRANCH" "$WORKTREE" "$REMOTE/$RELEASE_BRANCH" >/dev/null
  echo "Created $BRANCH in worktree $WORKTREE"
  cd "$WORKTREE"
else
  [[ -z "$(git status --porcelain)" ]] \
    || die "working tree is not clean. Commit/stash first, or use --worktree DIR."
  git switch --quiet -c "$BRANCH" "$REMOTE/$RELEASE_BRANCH"
  echo "Switched to new branch $BRANCH (from $REMOTE/$RELEASE_BRANCH)"
fi
# Do not track release: the first push sets the upstream to build/vX.
git branch --quiet --unset-upstream 2>/dev/null || true
PLANS="$(bash "$(dirname "${BASH_SOURCE[0]}")/docs-layout.sh" --get plans 2>/dev/null || echo docs/plans)"
echo "Next: write and commit $PLANS/$VERSION/requirement.md, then: git push -u $REMOTE $BRANCH"
