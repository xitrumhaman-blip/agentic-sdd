#!/usr/bin/env bash
# docs-layout.sh — resolve where this repo keeps each SDD document.
#
# Defaults are the layout created by /engineer:init-docs. A repo with its own
# docs tree overrides entries in .claude/engineer.yml (written by init-docs in
# "adopt" mode):
#
#   paths:
#     invariants: docs/architecture/invariants.md
#     decisions: docs/adr
#   invariant_id: "#{n}"        # how invariants are cited; default INV-{nnn}
#
# Output, one line per key:   <key>\t<path>\t<ok|missing>
# preceded by "config\t<file or none>" and "invariant_id\t<format>", and
# followed by "hint\tadopt-needed" when the repo already uses the SDD (version
# folders, build/v* branches or vX.Y.Z.T tags) but has no config and its core
# documents are not at the default paths — the one-time migration to 0.3+.
# Defaults of nested documents follow their parent: overriding `decisions`
# moves the default `adr_template`, overriding `conventions` moves `testing`
# and `git_workflow`. Only simple "  key: value" lines are understood.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: docs-layout.sh [--get KEY | --ignore] [--root DIR] [--ref REF]
  (no args)   print every key with its resolved path and ok/missing
  --get KEY   print only the path for KEY
  --ignore    print the test_report_ignore patterns of the config, one per line
              (paths whose changes do not make a test report stale)
  --root DIR  repository root (default: git toplevel or .)
  --ref REF   read .claude/engineer.yml from a git ref (e.g. origin/build/v1.3.0.0)
              instead of the working tree; ok/missing is checked in that ref
EOF
}

GET=""; ROOT=""; REF=""; IGNORE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --get)  GET="${2:-}"; shift 2 ;;
    --root) ROOT="${2:-}"; shift 2 ;;
    --ref)  REF="${2:-}"; shift 2 ;;
    --ignore) IGNORE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CFG_REL=".claude/engineer.yml"

# Config text, normalised (no CR, no trailing blanks); empty if absent.
if [[ -n "$REF" ]]; then
  CONFIG_TEXT="$(git -C "$ROOT" show "$REF:$CFG_REL" 2>/dev/null || true)"
else
  CONFIG_TEXT="$(cat "$ROOT/$CFG_REL" 2>/dev/null || true)"
fi
CONFIG_TEXT="$(printf '%s\n' "$CONFIG_TEXT" | tr -d '\r' | sed 's/[[:blank:]]*$//')"
HAS_CONFIG=0; [[ -n "${CONFIG_TEXT//[[:space:]]/}" ]] && HAS_CONFIG=1

# key|default — order is the reading order used in reports. "@parent/" makes a
# default relative to the resolved parent key.
DEFAULTS='readme|docs/README.md
context|docs/00-context
architecture|docs/01-architecture/overview.md
components|docs/01-architecture/components
data_model|docs/01-architecture/data-model.md
invariants|docs/02-constraints/invariants.md
non_functional|docs/02-constraints/non-functional.md
dependencies|docs/02-constraints/dependencies.md
decisions|docs/03-decisions
adr_template|@decisions/_template.md
conventions|docs/04-conventions
testing|@conventions/testing.md
git_workflow|@conventions/git-workflow.md
agent_workflow|docs/06-agent-guide/workflow.md
pitfalls|docs/06-agent-guide/known-pitfalls.md
plans|docs/plans
feature_tests|docs/test-cases/feature-tests
unit_tests|docs/test-cases/unit-tests'

# Value of "  key: value" inside the "paths:" block of the config.
override() {
  (( HAS_CONFIG )) || return 0
  printf '%s\n' "$CONFIG_TEXT" | awk -v k="$1" '
    /^[^ \t#]/ { inpaths = ($0 ~ /^paths:[ \t]*$/) ; next }
    inpaths && $0 ~ "^[ \t]+" k ":" {
      sub("^[ \t]+" k ":[ \t]*", ""); sub(/[ \t]+#.*$/, "")
      gsub(/^["\x27]|["\x27]$/, ""); sub(/\/$/, ""); print; exit }'
}

invariant_id() {
  local v=""
  (( HAS_CONFIG )) && v="$(printf '%s\n' "$CONFIG_TEXT" | awk '/^invariant_id:/ { sub(/^invariant_id:[ \t]*/, ""); sub(/[ \t]+#.*$/, ""); gsub(/^["\x27]|["\x27]$/, ""); print; exit }')"
  local def='INV-{nnn}'
  echo "${v:-$def}"
}

resolve() {  # $1 key → path
  local def
  def="$(awk -F'|' -v k="$1" '$1 == k { print $2 }' <<<"$DEFAULTS")"
  [[ -n "$def" ]] || { echo "Error: unknown key '$1'" >&2; exit 2; }
  local o; o="$(override "$1")"
  if [[ -n "$o" ]]; then echo "$o"; return; fi
  if [[ "$def" == @* ]]; then
    local parent="${def%%/*}"; parent="${parent#@}"
    echo "$(resolve "$parent")/${def#*/}"
  else
    echo "$def"
  fi
}

# Warn when the config has a paths: block whose entries cannot be read (flow
# syntax "paths: {…}", unknown keys, …) — otherwise overrides vanish silently.
if (( HAS_CONFIG )); then
  if grep -qE '^paths:[[:blank:]]*[^[:blank:]#]' <<<"$CONFIG_TEXT"; then
    echo "Warning: $CFG_REL: write 'paths:' as a block, one '  key: path' line per document." >&2
  fi
  known="|$(cut -d'|' -f1 <<<"$DEFAULTS" | tr '\n' '|')"
  while read -r k; do
    [[ "$known" == *"|$k|"* ]] || echo "Warning: $CFG_REL: unknown key '$k' under paths: (see docs-layout.sh --help)." >&2
  done < <(printf '%s\n' "$CONFIG_TEXT" | awk '
    /^[^ \t#]/ { inpaths = ($0 ~ /^paths:$/); next }
    inpaths && /^[ \t]+[^ \t#]/ { k = $1; sub(/:.*/, "", k); print k }')
fi

exists() {  # path relative to repo root, in the working tree or in $REF
  if [[ -n "$REF" ]]; then
    git -C "$ROOT" cat-file -e "$REF:$1" 2>/dev/null
  else
    [[ -e "$ROOT/$1" ]]
  fi
}

if [[ -n "$GET" ]]; then
  resolve "$GET"
  exit 0
fi

# test_report_ignore: a block list ("- path", indented or not) or a flow list
# ("[a, b]", possibly over several lines). Unreadable lines are reported.
if (( IGNORE )); then
  (( HAS_CONFIG )) || exit 0
  printf '%s\n' "$CONFIG_TEXT" | awk -v cfg="$CFG_REL" '
    function out(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); gsub(/^["\x27]|["\x27]$/, "", v); if (v != "") print v }
    function flow(t,   n, a, i) { gsub(/[\[\]]/, "", t); n = split(t, a, ","); for (i = 1; i <= n; i++) out(a[i]) }
    /^test_report_ignore:/ {
      rest = $0; sub(/^test_report_ignore:[ \t]*/, "", rest); sub(/[ \t]+#.*$/, "", rest)
      if (rest ~ /^\[/) { buf = rest; if (rest ~ /\]/) { flow(buf); exit } inflow = 1; next }
      if (rest != "") { print "Warning: " cfg ": test_report_ignore must be a list" > "/dev/stderr"; exit }
      inlist = 1; next }
    inflow { line = $0; sub(/[ \t]+#.*$/, "", line); buf = buf "," line; if (line ~ /\]/) { flow(buf); exit } next }
    inlist && /^[ \t]*-[ \t]/ { v = $0; sub(/^[ \t]*-[ \t]+/, "", v); sub(/[ \t]+#.*$/, "", v); out(v); next }
    inlist && /^[ \t]*(#.*)?$/ { next }
    inlist && /^[^ \t]/ { exit }
    inlist { print "Warning: " cfg ": cannot read test_report_ignore line: " $0 > "/dev/stderr" }'
  exit 0
fi

printf 'config\t%s\n' "$( (( HAS_CONFIG )) && echo "$CFG_REL${REF:+ @ $REF}" || echo none)"
printf 'invariant_id\t%s\n' "$(invariant_id)"
core_missing=0
while IFS='|' read -r key _; do
  p="$(resolve "$key")"
  exists "$p" && st=ok || st=missing
  case "$key:$st" in invariants:missing|decisions:missing|testing:missing) core_missing=1 ;; esac
  printf '%s\t%s\t%s\n' "$key" "$p" "$st"
done <<<"$DEFAULTS"

# Earlier SDD use without a layout config (plugin 0.2 had no engineer.yml).
if (( ! HAS_CONFIG && core_missing )); then
  # Files of the tree being inspected (working tree or $REF).
  list_files() {
    if [[ -n "$REF" ]]; then git -C "$ROOT" ls-tree -r --name-only "$REF" -- "$1" 2>/dev/null || true
    else (cd "$ROOT" && find "$1" -type f 2>/dev/null) || true; fi
  }
  plans="$(resolve plans)"
  used=""
  if list_files "$plans" | grep -E "^$plans/v[0-9]" >/dev/null; then
    used="$plans/v*"
  elif list_files docs | grep -v "^$plans/" | grep -E '\.md$' >/dev/null; then
    # A docs tree exists; SDD use is shown by build branches or PROD tags.
    if [[ -n "$(git -C "$ROOT" for-each-ref --count=1 --format=x 'refs/remotes/*/build/v*' 'refs/heads/build/v*' 2>/dev/null)" ]]; then
      used="build/v* branches"
    elif [[ -n "$(git -C "$ROOT" for-each-ref --count=1 --format=x 'refs/tags/v*.*.*.*' 2>/dev/null)" ]]; then
      used="vX.Y.Z.T tags"
    fi
  fi
  if [[ -n "$used" ]]; then
    # The adopt commit may already exist on main, waiting in a version's PR #1.
    on_main=""
    for m in "refs/remotes/origin/main" "refs/heads/main"; do
      if git -C "$ROOT" cat-file -e "$m:$CFG_REL" 2>/dev/null; then on_main="$m"; break; fi
    done
    if [[ -n "$on_main" ]]; then
      name="${on_main#refs/remotes/}"; name="${name#refs/heads/}"
      printf 'hint\tlayout-on-main\n'
      echo "Note: $CFG_REL exists on $name but not here. Do not adopt again: cherry-pick the commit that added it (git log $name -- $CFG_REL) onto this branch." >&2
    else
      printf 'hint\tadopt-needed\n'
      echo "Note: this repo already uses Agentic SDD ($used) but has no $CFG_REL and its core documents are not at the default paths. This is the one-time migration to plugin 0.3+: run /engineer:init-docs and choose adopt to map the existing docs." >&2
    fi
  fi
fi
