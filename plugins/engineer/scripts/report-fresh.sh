#!/usr/bin/env bash
# report-fresh.sh — is a test report still valid for HEAD?
#
# A report stays fresh when every change since the reported commit is in a path
# that cannot affect the product's tests: the docs (every path of the docs
# layout), CHANGELOG.md, agent/editor tooling under .claude/, and the patterns
# listed under test_report_ignore in .claude/engineer.yml. Three things always
# make it stale even though they live there: the feature-test documents, the
# testing document (its commands:), and .claude/engineer.yml itself. The layout
# and the ignore list are read as they were at the reported commit, so a later
# config edit cannot hide a change. Used by engineer:ship; see
# references/sdd-conventions.md.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  cat <<'USAGE'
Usage: report-fresh.sh --since <reported commit> [--head REF]
Prints "fresh" or "stale" plus the files that make it stale.
Exit 0 fresh, 1 stale, 2 usage error / unknown commit / git failure.
Anything but exit 0 means: run the tests again (or fix the call).
USAGE
}

SINCE=""; HEAD_REF="HEAD"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since|--head)
      [[ $# -ge 2 && -n "$2" ]] || { echo "Error: $1 needs a value." >&2; usage >&2; exit 2; }
      if [[ "$1" == --since ]]; then SINCE="$2"; else HEAD_REF="$2"; fi
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ -n "$SINCE" ]] || { usage >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Error: not inside a git repository." >&2; exit 2; }
for r in "$SINCE" "$HEAD_REF"; do
  git rev-parse -q --verify "$r^{commit}" >/dev/null || { echo "Error: unknown commit '$r'." >&2; exit 2; }
done
# Pathspecs are relative to the current directory: work from the top.
cd "$(git rev-parse --show-toplevel)"

LAYOUT="$(dirname "${BASH_SOURCE[0]}")/docs-layout.sh"
CFG=".claude/engineer.yml"

specs=(. ":(exclude).claude" ":(exclude)CHANGELOG.md" ":(exclude)docs")
must=("$CFG")   # changes here are always stale
while IFS=$'\t' read -r key path _; do
  case "$key" in
    config|invariant_id|hint|"") continue ;;
    feature_tests|testing) must+=("$path") ;;
  esac
  specs+=(":(exclude)$path")
done < <(bash "$LAYOUT" --ref "$SINCE" 2>/dev/null || true)

# Repo-specific ignores: "dir/" covers everything below it, a pattern without
# a slash matches at any depth, a leading "/" anchors at the repo root.
while read -r pat; do
  [[ -z "$pat" ]] && continue
  pat="${pat#/}"
  [[ "$pat" == */ ]] && pat="${pat}**"
  [[ "$pat" != */* ]] && pat="**/$pat"
  specs+=(":(exclude,glob)$pat")
done < <(bash "$LAYOUT" --ref "$SINCE" --ignore 2>/dev/null || true)

if ! changed="$(git diff --name-only "$SINCE" "$HEAD_REF" -- "${specs[@]}" 2>&1)"; then
  echo "Error: git diff failed: $changed" >&2; exit 2
fi
if ! forced="$(git diff --name-only "$SINCE" "$HEAD_REF" -- "${must[@]}" 2>&1)"; then
  echo "Error: git diff failed: $forced" >&2; exit 2
fi
changed="$(printf '%s\n%s\n' "$changed" "$forced" | grep . | sort -u || true)"

if [[ -z "$changed" ]]; then
  echo "fresh"
  exit 0
fi
echo "stale — changed since $(git rev-parse --short "$SINCE"):"
sed 's/^/  /' <<<"$changed"
exit 1
