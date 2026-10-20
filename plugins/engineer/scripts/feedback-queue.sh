#!/usr/bin/env bash
# feedback-queue.sh — local queue of plugin feedback, one Markdown file per entry
# in ~/.claude/engineer-feedback/queue/. Written by the silent retro
# (references/retro.md), drained by /engineer:feedback.
set -euo pipefail

QUEUE_DIR="${ENGINEER_FEEDBACK_DIR:-$HOME/.claude/engineer-feedback/queue}"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  feedback-queue.sh add --skill NAME --kind bug|enhancement|docs --title TEXT  < body.md
  feedback-queue.sh list        # print every entry (path header + content)
  feedback-queue.sh count
  feedback-queue.sh remove FILE...
EOF
}

plugin_version() {
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n 1
}

repo_name() {
  local url
  url="$(git remote get-url origin 2>/dev/null || true)"
  url="${url%.git}"
  [[ -n "$url" ]] && echo "${url##*[:/]}" || basename "$PWD"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  add)
    SKILL=""; KIND=""; TITLE=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --skill) SKILL="${2:-}"; shift 2 ;;
        --kind)  KIND="${2:-}"; shift 2 ;;
        --title) TITLE="${2:-}"; shift 2 ;;
        *) usage >&2; exit 2 ;;
      esac
    done
    [[ -n "$SKILL" && -n "$TITLE" ]] || { usage >&2; exit 2; }
    case "$KIND" in bug|enhancement|docs) ;; *) KIND=bug ;; esac
    mkdir -p "$QUEUE_DIR"
    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    file="$QUEUE_DIR/$ts-$SKILL-$$.md"
    {
      echo "---"
      echo "skill: $SKILL"
      echo "kind: $KIND"
      echo "title: \"${TITLE//\"/}\""
      echo "plugin_version: $(plugin_version)"
      echo "repo: $(repo_name)"
      echo "branch: $(git branch --show-current 2>/dev/null || true)"
      echo "recorded_at: $ts"
      echo "---"
      cat
    } >"$file"
    echo "$file"
    ;;
  list)
    [[ -d "$QUEUE_DIR" ]] || exit 0
    for f in "$QUEUE_DIR"/*.md; do
      [[ -e "$f" ]] || continue
      echo "=== $f"
      cat "$f"
      echo
    done
    ;;
  count)
    if [[ -d "$QUEUE_DIR" ]]; then
      find "$QUEUE_DIR" -maxdepth 1 -name '*.md' | wc -l | tr -d ' '
    else
      echo 0
    fi
    ;;
  remove)
    for f in "$@"; do
      case "$(cd "$(dirname "$f")" 2>/dev/null && pwd)" in
        "$(cd "$QUEUE_DIR" 2>/dev/null && pwd)") rm -f "$f" ;;
        *) echo "Skipping $f: not in $QUEUE_DIR" >&2 ;;
      esac
    done
    ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
