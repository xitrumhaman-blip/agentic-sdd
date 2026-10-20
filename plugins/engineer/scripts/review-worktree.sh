#!/usr/bin/env bash
# review-worktree.sh — a throwaway worktree whose uncommitted diff is exactly
# BASE..HEAD, for reviewers that look at "the current diff" (Claude Code's
# /code-review). The build branch and the current working tree are untouched.
#
#   review-worktree.sh create --base <commit> [--head <commit>]
#       prints REVIEW_WORKTREE=<dir> and the changed files (FILE=<path>);
#       inside it, `git diff` and `git diff HEAD` both show BASE..HEAD (new
#       files as intent-to-add). The worktree lives inside the repository,
#       under .engineer-review/ (added to .git/info/exclude), because agent
#       harnesses often refuse to keep a shell inside directories outside the
#       project.
#   review-worktree.sh remove <dir>
#       removes a worktree created by this script.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() { sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

cmd="${1:-}"; shift || true
require_git_repo
case "$cmd" in
  create)
    BASE=""; HEAD_REF="HEAD"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --base|--head)
          [[ $# -ge 2 && -n "$2" ]] || die "$1 needs a value."
          if [[ "$1" == --base ]]; then BASE="$2"; else HEAD_REF="$2"; fi
          shift 2 ;;
        *) usage >&2; exit 2 ;;
      esac
    done
    [[ -n "$BASE" ]] || { usage >&2; exit 2; }
    base="$(git rev-parse -q --verify "$BASE^{commit}")" || die "unknown commit '$BASE'."
    head="$(git rev-parse -q --verify "$HEAD_REF^{commit}")" || die "unknown commit '$HEAD_REF'."
    top="$(git rev-parse --show-toplevel)"
    exclude="$(git rev-parse --git-path info/exclude)"
    mkdir -p "$(dirname "$exclude")"
    grep -qx '/.engineer-review/' "$exclude" 2>/dev/null || echo '/.engineer-review/' >>"$exclude"
    mkdir -p "$top/.engineer-review"
    dir="$(mktemp -d "$top/.engineer-review/engineer-review.XXXXXX")/review"
    git worktree add --quiet --detach "$dir" "$base"
    git -C "$dir" read-tree -u --reset "$head"   # files of HEAD, HEAD ref at BASE
    git -C "$dir" reset -q                       # changes become unstaged
    git -C "$dir" ls-files -z --others --exclude-standard \
      | (cd "$dir" && xargs -0 git add -N --)    # new files visible to git diff
    echo "REVIEW_WORKTREE=$dir"
    echo "Range: ${base:0:9}..${head:0:9} — $(git -C "$dir" diff --shortstat HEAD | sed 's/^ //')"
    git -C "$dir" diff --name-only HEAD | sed 's/^/FILE=/' 
    ;;
  remove)
    dir="${1:-}"
    [[ "$dir" == */engineer-review.*/review ]] || die "'$dir' was not created by review-worktree.sh."
    git worktree remove --force "$dir"
    rmdir "$(dirname "$dir")" 2>/dev/null || true
    rmdir "$(dirname "$(dirname "$dir")")" 2>/dev/null || true   # .engineer-review/ when empty
    echo "Removed $dir"
    ;;
  -h|--help|"") usage ;;
  *) usage >&2; exit 2 ;;
esac
