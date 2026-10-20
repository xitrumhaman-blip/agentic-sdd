#!/usr/bin/env bash
# next-version.sh — compute the next vX.Y.Z.T for a bump kind.
#
# Base is the latest PROD tag on the release branch (v0.0.0.0 if none). Numbers
# reserved by build/v* branches on the remote are skipped by bumping the same
# digit again. See references/sdd-conventions.md.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  next-version.sh --bump <major|feature|improvement|fix> [--no-fetch]
      Print the next free version, e.g. v1.3.0.0
  next-version.sh --info [--no-fetch]
      Print the base PROD version and the reserved versions.
  next-version.sh --check <vX.Y.Z.T> [--no-fetch]
      Exit 0 if the version can go to PROD now (greater than every PROD tag),
      1 otherwise.
EOF
}

MODE=""; BUMP=""; CHECK=""; FETCH=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump)     MODE=bump;  BUMP="${2:-}"; shift 2 ;;
    --info)     MODE=info;  shift ;;
    --check)    MODE=check; CHECK="${2:-}"; shift 2 ;;
    --no-fetch) FETCH=0; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ -n "$MODE" ]] || { usage >&2; exit 2; }

require_git_repo
(( FETCH )) && fetch_remote
remote_branch_exists "$RELEASE_BRANCH" \
  || die "branch '$REMOTE/$RELEASE_BRANCH' not found. Create the PROD branch first (e.g. git push $REMOTE main:$RELEASE_BRANCH)."

BASE="$(latest_prod_tag)"; BASE="${BASE:-v0.0.0.0}"

case "$MODE" in
  info)
    echo "base: $BASE"
    reserved="$(reserved_versions)"
    echo "reserved: ${reserved:+$(echo "$reserved" | tr '\n' ' ')}"
    drift="$(bash "$(dirname "${BASH_SOURCE[0]}")/drift.sh" --no-fetch | sed -n 's/^DRIFT=//p' || true)"
    echo "drift: ${drift:-0} commit(s) on $MAIN_BRANCH not on $RELEASE_BRANCH (scripts/drift.sh)"
    ;;

  check)
    is_version "$CHECK" || die "'$CHECK' is not a vX.Y.Z.T version."
    highest="$(printf '%s\n%s\n' "$BASE" "$CHECK" | sort_versions | tail -n 1)"
    if [[ "$CHECK" != "$BASE" && "$highest" == "$CHECK" ]]; then
      echo "ok: $CHECK > $BASE"
    else
      echo "blocked: $CHECK is not greater than the latest PROD tag $BASE" >&2
      exit 1
    fi
    ;;

  bump)
    case "$BUMP" in
      major) idx=0 ;; feature) idx=1 ;; improvement) idx=2 ;; fix) idx=3 ;;
      *) die "--bump must be one of: major, feature, improvement, fix." ;;
    esac
    IFS=. read -r -a parts <<<"${BASE#v}"
    reserved="$(reserved_versions)"
    while :; do
      parts[$idx]=$(( parts[idx] + 1 ))
      for (( i = idx + 1; i < 4; i++ )); do parts[$i]=0; done
      candidate="v${parts[0]}.${parts[1]}.${parts[2]}.${parts[3]}"
      grep -qxF "$candidate" <<<"$reserved" || break
    done
    echo "$candidate"
    ;;
esac
