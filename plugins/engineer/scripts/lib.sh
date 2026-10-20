#!/usr/bin/env bash
# lib.sh — helpers shared by the engineer plugin scripts. Source, don't execute.
# Conventions: references/sdd-conventions.md

REMOTE="${ENGINEER_REMOTE:-origin}"
RELEASE_BRANCH="${ENGINEER_RELEASE_BRANCH:-release}"
MAIN_BRANCH="${ENGINEER_MAIN_BRANCH:-main}"

# PROD tag: vX.Y.Z.T   STAG tag: vX.Y.Z.T-rc.N
PROD_TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
RC_TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+$'

die() { echo "Error: $*" >&2; exit 1; }

require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository."
}

# Validate "vX.Y.Z.T" (leading v required).
is_version() { [[ "$1" =~ $PROD_TAG_RE ]]; }

# Sort versions (with or without leading v) ascending, one per line on stdin.
sort_versions() {
  sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | sed 's/^/v/'
}

# Fetch branches and tags quietly; tolerate offline use with a warning.
fetch_remote() {
  if ! git fetch --quiet --prune --tags "$REMOTE" 2>/dev/null; then
    echo "Warning: could not fetch from '$REMOTE'; using local refs." >&2
  fi
}

remote_branch_exists() {
  git show-ref --verify --quiet "refs/remotes/$REMOTE/$1"
}

# PROD tags reachable from the release branch, ascending.
prod_tags() {
  remote_branch_exists "$RELEASE_BRANCH" || return 0
  git tag --merged "$REMOTE/$RELEASE_BRANCH" --list 'v*' \
    | grep -E "$PROD_TAG_RE" | sort_versions || true
}

latest_prod_tag() { prod_tags | tail -n 1; }

# Versions reserved by build/v* branches on the remote, ascending.
reserved_versions() {
  git for-each-ref --format='%(refname:strip=3)' "refs/remotes/$REMOTE/build/" \
    | sed -n 's|^build/||p' | grep -E "$PROD_TAG_RE" | sort_versions || true
}

# RC tags of one version, ascending by N.
rc_tags_of() {
  git tag --list "$1-rc.*" | grep -E "$RC_TAG_RE" \
    | sort -t. -k5,5n || true
}
