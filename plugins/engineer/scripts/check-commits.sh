#!/usr/bin/env bash
# check-commits.sh — enforce Conventional Commits on a commit range and/or a PR
# title. Allowed types and the bump mapping: references/sdd-conventions.md.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  check-commits.sh --range <rev-range> [--require-refs <vX.Y.Z.T/G-NN>]
  check-commits.sh --title "<PR title>" [--bump <major|feature|improvement|fix>]

Exit 0 when everything is valid; 1 and a list of offenders otherwise.
Merge commits are ignored.

A "Refs:" line must be a real git trailer, i.e. part of the last paragraph of
the message together with any other trailers (no blank line between "Refs:"
and "Co-Authored-By:"). --require-refs additionally demands that trailer, with
that value, on every commit of the range (used for a WBS goal's commits).
EOF
}

TYPES='feat|fix|perf|refactor|improve|docs|test|build|ci|chore|style|revert'
SUBJECT_RE="^($TYPES)(\([a-zA-Z0-9._/-]+\))?!?: [^ ].*"
# Default `git revert` subjects are accepted as the `revert` type.
REVERT_RE='^Revert ".+"$'

RANGE=""; TITLE=""; BUMP=""; REQUIRE_REFS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --range) RANGE="${2:-}"; shift 2 ;;
    --title) TITLE="${2:-}"; shift 2 ;;
    --bump)  BUMP="${2:-}"; shift 2 ;;
    --require-refs) REQUIRE_REFS="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ -n "$RANGE" || -n "$TITLE" ]] || { usage >&2; exit 2; }

bad=0

if [[ -n "$RANGE" ]]; then
  require_git_repo
  # An unknown ref must fail loudly, not look like an empty, valid range.
  # One record per commit: sha, subject, parsed Refs trailers, has-a-Refs-line.
  # %(trailers) is git's own parser, so a "Refs:" line outside the trailer
  # block shows up as "line present, trailer empty".
  # Records are NUL-separated (-z), which cannot occur in a commit message;
  # the body comes last so a stray \x1f in it stays inside "body".
  # An unknown ref must fail loudly, not look like an empty, valid range.
  git log --no-merges --format=%H "$RANGE" >/dev/null 2>&1 \
    || die "cannot read commit range '$RANGE'."
  while IFS=$'\x1f' read -r -d '' sha subject refs body; do
    [[ -z "$sha" ]] && continue
    if [[ ! "$subject" =~ $SUBJECT_RE && ! "$subject" =~ $REVERT_RE ]]; then
      echo "✗ ${sha:0:9} $subject"
      bad=1
    fi
    if [[ -z "$refs" ]] && grep -qE '^Refs:' <<<"$body"; then
      echo "✗ ${sha:0:9} 'Refs:' is not a git trailer (keep it in the last paragraph with the other trailers, no blank line in between)"
      bad=1
    elif [[ -n "$REQUIRE_REFS" && ",${refs// /}," != *",$REQUIRE_REFS,"* ]]; then
      echo "✗ ${sha:0:9} missing trailer 'Refs: $REQUIRE_REFS'"
      bad=1
    fi
  done < <(git log -z --no-merges \
    --format='%H%x1f%s%x1f%(trailers:key=Refs,valueonly,separator=%x2C)%x1f%B' "$RANGE")
  (( bad )) || echo "✓ all commits in $RANGE follow Conventional Commits${REQUIRE_REFS:+ and carry Refs: $REQUIRE_REFS}"
fi

if [[ -n "$TITLE" ]]; then
  title_bad=0
  if [[ ! "$TITLE" =~ $SUBJECT_RE ]]; then
    echo "✗ PR title is not a Conventional Commit: $TITLE"
    title_bad=1
  elif [[ -n "$BUMP" ]]; then
    type="${TITLE%%:*}"; breaking=0
    [[ "$type" == *'!' ]] && breaking=1
    type="${type%!}"; type="${type%%(*}"
    case "$BUMP" in
      major)       (( breaking )) ;;
      feature)     [[ "$type" == feat && $breaking == 0 ]] ;;
      improvement) [[ "$type" =~ ^(perf|refactor|improve)$ && $breaking == 0 ]] ;;
      fix)         [[ "$type" == fix && $breaking == 0 ]] ;;
      *) die "--bump must be one of: major, feature, improvement, fix." ;;
    esac || { echo "✗ PR title '${TITLE%%:*}' does not match bump '$BUMP' (see sdd-conventions.md)"; title_bad=1; }
  fi
  (( title_bad )) && bad=1 || echo "✓ PR title ok"
fi

exit "$bad"
