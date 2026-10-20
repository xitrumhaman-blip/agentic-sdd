#!/usr/bin/env bash
# scaffold.sh — create the ./docs knowledge base and CLAUDE.md from templates.
# Safe by default: refuses to run if docs/ already exists in the target.
set -euo pipefail

SCAFFOLD_VERSION="0.2.0"

# --- resolve template dir relative to this script -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/../templates" && pwd)"

# --- defaults -------------------------------------------------------------
TARGET="."
NAME=""
ONE_LINER=""
# To pin a team-wide default stack, change the line below.
STACK="TODO: describe the stack"
REPO=""
CMD_SETUP=""; CMD_LINT=""; CMD_UNIT=""; CMD_FEATURE=""

usage() {
  cat <<'EOF'
Usage: scaffold.sh --name NAME [options]

Options:
  --target DIR       Project root to scaffold into (default: .)
  --name NAME        Project name (required)
  --one-liner TEXT   One-line description of the project
  --stack TEXT       Tech stack summary (e.g. "TypeScript / Fastify, pnpm")
  --repo TEXT        Git remote URL or owner/repo (optional)
  --cmd-setup TEXT   Install/setup command   (testing.md commands.setup)
  --cmd-lint TEXT    Lint command            (testing.md commands.lint)
  --cmd-unit TEXT    Unit test command       (testing.md commands.unit)
  --cmd-feature TEXT Feature/e2e test command (testing.md commands.feature)
  -h, --help         Show this help

Root files (CLAUDE.md, CHANGELOG.md) that already exist are left untouched.
EOF
}

# --- parse args -----------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)    TARGET="$2"; shift 2 ;;
    --name)      NAME="$2"; shift 2 ;;
    --one-liner) ONE_LINER="$2"; shift 2 ;;
    --stack)     STACK="$2"; shift 2 ;;
    --repo)      REPO="$2"; shift 2 ;;
    --cmd-setup)   CMD_SETUP="$2"; shift 2 ;;
    --cmd-lint)    CMD_LINT="$2"; shift 2 ;;
    --cmd-unit)    CMD_UNIT="$2"; shift 2 ;;
    --cmd-feature) CMD_FEATURE="$2"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Error: --name is required." >&2
  usage
  exit 1
fi
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Error: template dir not found at $TEMPLATE_DIR" >&2
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"

# --- safety: never overwrite an existing docs tree ------------------------
if [[ -e "$TARGET/docs" ]]; then
  echo "Error: $TARGET/docs already exists. Refusing to overwrite." >&2
  echo "This skill only initializes. Use a sync/update flow instead." >&2
  exit 1
fi

TODAY="$(date +%Y-%m-%d)"
[[ -z "$ONE_LINER" ]] && ONE_LINER="TODO: one-line description of $NAME"
[[ -z "$REPO" ]] && REPO="TODO: repository url"

# --- substitute placeholders into a file in place ------------------------
# Escape a value for the replacement side of sed s|…|…| (\, & and |).
esc() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }
# Commands land inside double quotes in YAML frontmatter.
yq() { local v="${1//\\/\\\\}"; printf '%s' "${v//\"/\\\"}"; }

fill() {
  local f="$1"
  sed -i.bak \
    -e "s|__PROJECT_NAME__|$(esc "$NAME")|g" \
    -e "s|__ONE_LINER__|$(esc "$ONE_LINER")|g" \
    -e "s|__STACK__|$(esc "$STACK")|g" \
    -e "s|__REPO__|$(esc "$REPO")|g" \
    -e "s|__DATE__|$TODAY|g" \
    -e "s|__SCAFFOLD_VERSION__|$SCAFFOLD_VERSION|g" \
    -e "s|\"__CMD_SETUP__\"|\"$(esc "$(yq "$CMD_SETUP")")\"|g" \
    -e "s|\"__CMD_LINT__\"|\"$(esc "$(yq "$CMD_LINT")")\"|g" \
    -e "s|\"__CMD_UNIT__\"|\"$(esc "$(yq "$CMD_UNIT")")\"|g" \
    -e "s|\"__CMD_FEATURE__\"|\"$(esc "$(yq "$CMD_FEATURE")")\"|g" \
    -e "s|__CMD_SETUP__|$(esc "${CMD_SETUP:-TODO}")|g" \
    -e "s|__CMD_LINT__|$(esc "${CMD_LINT:-TODO}")|g" \
    -e "s|__CMD_UNIT__|$(esc "${CMD_UNIT:-TODO}")|g" \
    -e "s|__CMD_FEATURE__|$(esc "${CMD_FEATURE:-TODO}")|g" \
    "$f"
  rm -f "$f.bak"
}

# --- copy templates -> target, stripping the .tmpl suffix ----------------
count=0; skipped=()
while IFS= read -r -d '' src; do
  rel="${src#"$TEMPLATE_DIR"/}"     # path relative to templates/
  dest="$TARGET/${rel%.tmpl}"       # strip trailing .tmpl if present
  # Never overwrite files outside docs/ (CLAUDE.md, CHANGELOG.md).
  if [[ "$rel" != docs/* && -e "$dest" ]]; then
    skipped+=("${rel%.tmpl}"); continue
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  case "$dest" in
    *.md) fill "$dest" ;;
  esac
  count=$((count + 1))
done < <(find "$TEMPLATE_DIR" -type f -print0)

# --- report ---------------------------------------------------------------
echo "Scaffolded $count files into $TARGET"
for f in ${skipped[@]+"${skipped[@]}"}; do
  echo "Skipped existing $f (left untouched; merge the template by hand if useful)"
done
echo ""
if command -v tree >/dev/null 2>&1; then
  tree -a --noreport "$TARGET/docs" 2>/dev/null || true
else
  (cd "$TARGET" && find docs CLAUDE.md CHANGELOG.md -print 2>/dev/null | sort)
fi
echo ""
echo "Next: fill docs/01-architecture/overview.md (C4 diagrams) and"
echo "docs/02-constraints/invariants.md with real content, check the commands"
echo "in docs/04-conventions/testing.md, then commit."
