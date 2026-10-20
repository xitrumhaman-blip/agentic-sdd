#!/usr/bin/env bash
# port.sh — bring build/vX commits to main through port/vX (cherry-pick -x).
#
# Idempotent: commits already on main or on port/vX (found through their
# "(cherry picked from commit <sha>)" trailer) are skipped, so the same command
# serves the first port and every UAT fix round. On a conflict it stops with
# exit code 3 and leaves the cherry-pick in progress in the port worktree:
# resolve, `git cherry-pick --continue`, then run this script again.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  cat <<'EOF'
Usage: port.sh --version vX.Y.Z.T [--worktree DIR]
       port.sh --version vX.Y.Z.T --pending [--against REF]

  --worktree  Where to check out port/vX (default: a sibling directory
              "<repo>-port-vX.Y.Z.T"). The current working tree is never touched.
  --pending   Only list build commits that have not reached main yet
              (exit 0 if none, 1 if some). Touches nothing.
  --against   With --pending: compare with REF instead of origin/main, e.g. the
              latest rc tag, to check that STAG actually ran every commit.

Exit codes: 0 done, 3 conflict to resolve in the worktree, 1 error.
Prints "PORT_WORKTREE=<dir>" and "PICKED=<n>" for the caller.
EOF
}

VERSION=""; WT=""; PENDING=0; AGAINST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)  VERSION="${2:-}"; shift 2 ;;
    --worktree) WT="${2:-}"; shift 2 ;;
    --pending)  PENDING=1; shift ;;
    --against)  AGAINST="${2:-}"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

require_git_repo
is_version "$VERSION" || die "--version must look like v1.3.0.0."
BUILD="build/$VERSION"; PORT="port/$VERSION"
TOP="$(git rev-parse --show-toplevel)"
WT="${WT:-$(dirname "$TOP")/$(basename "$TOP")-port-$VERSION}"

fetch_remote
remote_branch_exists "$MAIN_BRANCH" || die "'$REMOTE/$MAIN_BRANCH' not found."
remote_branch_exists "$RELEASE_BRANCH" || die "'$REMOTE/$RELEASE_BRANCH' not found."
if (( PENDING )); then
  # Judge what PROD would receive: the remote branch, never a stale local copy.
  remote_branch_exists "$BUILD" || die "$REMOTE/$BUILD not found."
  BUILD_REF="$REMOTE/$BUILD"
  if git show-ref --verify --quiet "refs/heads/$BUILD" \
     && [[ -n "$(git rev-list "$REMOTE/$BUILD..$BUILD")" ]]; then
    die "local $BUILD has commits not pushed to $REMOTE. Push them (and port them) first."
  fi
# Otherwise prefer the local build branch (may hold unpushed fixes).
elif git show-ref --verify --quiet "refs/heads/$BUILD"; then BUILD_REF="$BUILD"
elif remote_branch_exists "$BUILD"; then BUILD_REF="$REMOTE/$BUILD"
else die "$BUILD not found locally or on $REMOTE."; fi

# SHAs of build commits that main already carries, via the -x trailer.
picked_on() {
  git log --format=%B "$@" \
    | sed -n 's/.*(cherry picked from commit \([0-9a-f]\{40\}\)).*/\1/p' | sort -u
}

if (( PENDING )); then
  TARGET="${AGAINST:-$REMOTE/$MAIN_BRANCH}"
  git rev-parse -q --verify "$TARGET^{commit}" >/dev/null || die "'$TARGET' not found."
  already="$(picked_on "$TARGET")"
  # git cherry also catches commits whose identical patch reached main another
  # way (e.g. a squashed PR); "+" means no equivalent patch on main.
  missing=0
  while read -r mark sha subject; do
    [[ "$mark" == "+" ]] || continue
    grep -qx "$sha" <<<"$already" && continue
    git diff --quiet "$sha^" "$sha" 2>/dev/null && continue
    echo "pending: ${sha:0:9} $subject"; missing=$((missing + 1))
  done < <(git cherry -v "$TARGET" "$BUILD_REF" "$REMOTE/$RELEASE_BRANCH")
  echo "PENDING=$missing"
  (( missing == 0 ))
  exit
fi

# --- prepare the port worktree ---------------------------------------------
# A round whose PR was merged into main restarts from main; while the PR is
# still open, the round continues on the remote port branch.
if remote_branch_exists "$PORT" \
   && ! git merge-base --is-ancestor "$REMOTE/$PORT" "$REMOTE/$MAIN_BRANCH"; then
  start="$REMOTE/$PORT"
else
  start="$REMOTE/$MAIN_BRANCH"
fi

if [[ -d "$WT" ]]; then
  git -C "$WT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "$WT exists but is not a git worktree."
  [[ "$(git -C "$WT" branch --show-current)" == "$PORT" ]] \
    || die "$WT is not on $PORT."
  if [[ -e "$(git -C "$WT" rev-parse --git-path CHERRY_PICK_HEAD)" ]]; then
    echo "A cherry-pick is still in progress in $WT. Resolve it and run" >&2
    echo "'git -C $WT cherry-pick --continue' first." >&2
    echo "PORT_WORKTREE=$WT"; exit 3
  fi
else
  if git show-ref --verify --quiet "refs/heads/$PORT"; then
    git worktree add --quiet "$WT" "$PORT" 2>/dev/null \
      || die "local branch $PORT exists and is checked out elsewhere."
  else
    git worktree add --quiet -b "$PORT" "$WT" "$start"
  fi
  git -C "$WT" branch --quiet --unset-upstream 2>/dev/null || true
fi

# Untracked files are ignored: setup steps (node_modules, venvs) leave them.
[[ -z "$(git -C "$WT" status --porcelain --untracked-files=no)" ]] \
  || die "$WT has uncommitted changes. Commit them on $PORT (fix(port): …) or discard them, then rerun."

# Keep unpushed local picks; only restart a round that main already merged.
if git merge-base --is-ancestor "$PORT" "$REMOTE/$MAIN_BRANCH" \
   && [[ "$(git rev-parse "$PORT")" != "$(git rev-parse "$start")" ]]; then
  git -C "$WT" reset --quiet --hard "$start"
  echo "Started a new port round on $PORT from $start."
fi

# --- pick what is missing --------------------------------------------------
already="$(picked_on "$REMOTE/$MAIN_BRANCH" "$PORT")"

picked=0
while read -r sha; do
  [[ -z "$sha" ]] && continue
  grep -qx "$sha" <<<"$already" && continue
  # Skip commits that change nothing (e.g. an empty reservation commit).
  if git diff --quiet "$sha^" "$sha" 2>/dev/null; then continue; fi
  if ! out="$(git -C "$WT" cherry-pick -x "$sha" 2>&1)"; then
    if [[ ! -e "$(git -C "$WT" rev-parse --git-path CHERRY_PICK_HEAD)" ]]; then
      echo "$out" >&2
      die "cherry-pick of ${sha:0:9} could not start in $WT (see above)."
    fi
    if git -C "$WT" diff --cached --quiet && git -C "$WT" diff --quiet; then
      # Change already present on main: nothing to apply, move on.
      git -C "$WT" cherry-pick --skip >/dev/null 2>&1
      continue
    fi
    echo "CONFLICT while picking ${sha:0:9}: $(git log -1 --format=%s "$sha")"
    git -C "$WT" diff --name-only --diff-filter=U | sed 's/^/  /'
    echo "PORT_WORKTREE=$WT"; echo "PICKED=$picked"
    exit 3
  fi
  picked=$((picked + 1))
done < <(git rev-list --reverse --no-merges "$REMOTE/$RELEASE_BRANCH..$BUILD_REF")

echo "Ported $picked new commit(s) from $BUILD_REF onto $PORT."
echo "PORT_WORKTREE=$WT"; echo "PICKED=$picked"
