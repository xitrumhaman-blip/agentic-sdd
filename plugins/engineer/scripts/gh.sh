#!/usr/bin/env bash
# gh.sh — run `gh` with a fallback for app-scoped env tokens.
#
# Desktop agent apps often export GH_TOKEN/GITHUB_TOKEN with a GitHub App token
# whose installation does not cover every organisation. gh then fails with
# "Could not resolve to a Repository" even though the user's own `gh auth login`
# (keyring) has access. On such access errors, and only then, the command is
# retried once with the env tokens unset. Any other failure is returned as is,
# so non-idempotent commands (pr create, issue create) are never run twice after
# a partial success.
#
# Usage: gh.sh <gh arguments…>     e.g. gh.sh pr list --head build/v1.3.0.0
set -uo pipefail

# Only errors that mean "this token cannot see the repository". Rate limits
# (HTTP 403 with other text) and generic failures are not retried.
ACCESS_RE='Could not resolve to a Repository|Resource not accessible by integration|Bad credentials|HTTP 401'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
out="$tmp/out"; err="$tmp/err"; input="$tmp/in"
# Only when gh is told to read stdin ("-" as a value, e.g. --body-file -), keep
# that input so a retry gets it too. Otherwise never touch stdin: agent shells
# often have a non-terminal stdin that is never closed.
piped=0
for a in "$@"; do
  if [[ "$a" == "-" || "$a" == *=- ]]; then piped=1; fi
done
if (( piped )); then cat >"$input"; fi
run() { if (( piped )); then "$@" <"$input"; else "$@"; fi; }

run gh "$@" >"$out" 2>"$err"; rc=$?
if (( rc != 0 )) && [[ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]] && grep -qE "$ACCESS_RE" "$err"; then
  cp "$err" "$tmp/err.first"
  if run env -u GH_TOKEN -u GITHUB_TOKEN gh "$@" >"$out" 2>"$err"; then
    rc=0
    echo "note: GH_TOKEN/GITHUB_TOKEN has no access to this repository (likely a GitHub App token whose installation does not include the organisation); used your own gh login instead." >&2
  else
    rc=$?
    echo "note: the env token was refused:" >&2
    cat "$tmp/err.first" >&2
    echo "note: retried with your own gh login, which failed too (below). Check 'env -u GH_TOKEN -u GITHUB_TOKEN gh auth status' and your access to the repository." >&2
  fi
fi
cat "$out"; cat "$err" >&2
exit "$rc"
