#!/usr/bin/env bash
# commitlint-check.sh — does this repo's commitlint accept the SDD commit type
# `improve`? Many repos extend @commitlint/config-conventional, whose
# type-enum rejects it in the commit-msg hook and in CI.
#
# Output: "commitlint: <config or none>" and "improve: accepted | rejected |
# unknown (<why>)". Exit 0 = accepted or no commitlint, 1 = rejected,
# 2 = config found but the answer is unknown (check by hand).
# The fix (type-enum snippets): references/commitlint.md.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

config=""
for f in commitlint.config.js commitlint.config.cjs commitlint.config.mjs \
         commitlint.config.ts commitlint.config.cts commitlint.config.mts \
         .commitlintrc .commitlintrc.json .commitlintrc.yaml .commitlintrc.yml \
         .commitlintrc.js .commitlintrc.cjs .commitlintrc.mjs .commitlintrc.ts .commitlintrc.cts; do
  if [[ -f "$f" ]]; then config="$f"; break; fi
done
if [[ -z "$config" && -f package.json ]] && grep -q '"commitlint"[[:space:]]*:' package.json; then
  config="package.json (commitlint key)"
fi

echo "commitlint: ${config:-none}"
if [[ -z "$config" ]]; then
  echo "improve: accepted (no commitlint config)"
  exit 0
fi

# 1. Ask commitlint itself when it is installed locally (never download it).
bin="node_modules/.bin/commitlint"
if [[ -x "$bin" ]]; then
  if out="$(printf 'improve: probe for the SDD improve type\n' | "$bin" 2>&1)"; then
    echo "improve: accepted"
    exit 0
  elif grep -q 'type-enum' <<<"$out"; then
    echo "improve: rejected (type-enum)"
    exit 1
  fi
  # Other rules (required scope, body…) failed on the probe, not the type.
  echo "improve: accepted (other rules rejected the probe message: $(grep -m1 -E '✖|error' <<<"$out" || head -n 1 <<<"$out"))"
  exit 0
fi

# 2. Read the config: an explicit type list that names improve, or the
#    conventional preset without a type-enum override.
file="${config%% *}"
# Text of the type-enum rule only, comments removed: from the line naming it
# until its brackets close (JS/JSON/YAML flow) or, for a YAML block list, until
# a line indented no deeper than the rule.
rule="$(sed -e 's|//.*$||' -e 's|[[:space:]]#.*$||' -e 's|^#.*$||' "$file" | awk '
  !on && /type-enum/ {
    on = 1; ind = match($0, /[^ \t]/)
    text = substr($0, index($0, "type-enum"))   # ignore what precedes the rule
    depth = 0; seen = 0
    for (i = 1; i <= length(text); i++) {       # cut where the brackets close
      c = substr(text, i, 1)
      if (c == "[") { depth++; seen = 1 } else if (c == "]") depth--
      if (seen && depth == 0) { print substr(text, 1, i); done = 1; exit }
    }
    next }
  on {
    if (!seen && $0 ~ /[^ \t]/ && match($0, /[^ \t]/) <= ind) { print text; done = 1; exit }
    text = text "\n" $0
    if (index($0, "[")) seen = 1
    depth += gsub(/\[/, "[") - gsub(/\]/, "]")
    if (seen && depth <= 0) { print text; done = 1; exit } }
  END { if (on && !done) print text }')"
if [[ -n "$rule" ]]; then
  if grep -qE "(^|[^A-Za-z0-9_-])improve([^A-Za-z0-9_-]|$)" <<<"$rule"; then
    echo "improve: accepted (listed in type-enum of $file)"
    exit 0
  fi
  echo "improve: rejected (type-enum in $file does not list it)"
  exit 1
fi
if grep -q "config-conventional" "$file"; then
  echo "improve: rejected (extends @commitlint/config-conventional without a type-enum override)"
  exit 1
fi
echo "improve: unknown (commitlint not installed in node_modules; config $file has no type-enum)"
exit 2
