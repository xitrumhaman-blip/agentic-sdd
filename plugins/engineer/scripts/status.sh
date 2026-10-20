#!/usr/bin/env bash
# status.sh — one table of every version in flight plus recent PROD releases.
#
# Status: "released" if the vX tag exists, "staging (rc.N)" if an rc tag exists,
# otherwise the `status:` frontmatter of $PLANS/vX/requirement.md on the
# build branch. See references/sdd-conventions.md.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

USE_GH=1; FETCH=1
for a in "$@"; do
  case "$a" in
    --no-gh) USE_GH=0 ;;
    --no-fetch) FETCH=0 ;;
    -h|--help) echo "Usage: status.sh [--no-gh] [--no-fetch]"; exit 0 ;;
  esac
done
command -v gh >/dev/null 2>&1 || USE_GH=0

require_git_repo
(( FETCH )) && fetch_remote
LAYOUT="$(dirname "${BASH_SOURCE[0]}")/docs-layout.sh"
PLANS="$(bash "$LAYOUT" --get plans)"   # working tree layout

status_line() { awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} /^status:/{sub(/^status:[ \t]*/,""); sub(/[ \t]*#.*/,""); print; exit}'; }

frontmatter_status() {  # $1 = ref, $2 = version — layout read from that ref
  local plans; plans="$(bash "$LAYOUT" --ref "$1" --get plans 2>/dev/null || echo "$PLANS")"
  { git show "$1:$plans/$2/requirement.md" 2>/dev/null || true; } | status_line
}

pr_summary() {  # $1 = head branch
  (( USE_GH )) || return 0
  bash "$(dirname "${BASH_SOURCE[0]}")/gh.sh" pr list --head "$1" --state all --limit 5 \
    --json number,state,baseRefName \
    --jq 'map("#\(.number)→\(.baseRefName):\(.state|ascii_downcase)") | join(" ")' 2>/dev/null || true
}

current="$(git branch --show-current 2>/dev/null || true)"
current_ver="${current#build/}"; [[ "$current" == build/* ]] || current_ver=""

# Remote build branches + a local-only current build branch.
versions="$(reserved_versions)"
local_only=""
if [[ -n "$current_ver" ]] && ! grep -qxF "$current_ver" <<<"$versions"; then
  local_only="$current_ver"
  versions="$(printf '%s\n%s\n' "$versions" "$current_ver" | grep . | sort_versions)"
fi

printf '  %-13s %-30s %-28s %s\n' VERSION STATUS "PR build->release" "PR port->main"
printf '  %-13s %-30s %-28s %s\n' ------- ------ ----------------- -------------
if [[ -z "$versions" ]]; then
  echo "(no build/v* branches)"
fi
while read -r v; do
  [[ -z "$v" ]] && continue
  # Frontmatter first: the working tree is the freshest source for the branch
  # we are on, the remote build branch for the others.
  if [[ "$v" == "$current_ver" && -f "$PLANS/$v/requirement.md" ]]; then
    fm="$(status_line <"$PLANS/$v/requirement.md")"
    [[ -n "$(git status --porcelain -- "$PLANS/$v" 2>/dev/null)" ]] && fm="$fm*"
  else
    fm="$(frontmatter_status "$REMOTE/build/$v" "$v")"
  fi
  rc="$(rc_tags_of "$v" | tail -n 1)"
  if git rev-parse -q --verify "refs/tags/$v" >/dev/null; then
    st="released"
  elif [[ -n "$rc" ]]; then
    # A revision after STAG resets the status to an earlier phase, which then
    # wins over the rc tag (sdd-conventions.md, "Lifecycle status").
    case "${fm%\*}" in
      approved|planned|architected|building) st="$fm (${rc##*-} on STAG)" ;;
      *) st="staging (${rc##*-})" ;;
    esac
  else
    st="${fm:-reserved (no requirement)}"
  fi
  [[ "$v" == "$local_only" ]] && st="$st [local, not pushed]"
  mark=" "; [[ "$v" == "$current_ver" ]] && mark="*"
  printf '%s %-13s %-30s %-28s %s\n' "$mark" "$v" "$st" \
    "$(pr_summary "build/$v")" "$(pr_summary "port/$v")"
done <<<"$versions"

echo
[[ -n "$current_ver" ]] && echo "(* = current branch)"
drift="$(bash "$(dirname "${BASH_SOURCE[0]}")/drift.sh" --no-fetch | sed -n 's/^DRIFT=//p' || true)"
[[ "${drift:-0}" != 0 ]] && echo "Drift: $drift commit(s) on $MAIN_BRANCH that are not on $RELEASE_BRANCH (run scripts/drift.sh)"
echo "Latest PROD: $(prod_tags | tail -n 3 | tr '\n' ' ')"
echo "Feedback queued: $(bash "$(dirname "${BASH_SOURCE[0]}")/feedback-queue.sh" count)"
