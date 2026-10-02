#!/usr/bin/env bash
# Install cursor-prime rules into one target project for cloud and headless agents.
#
# Copies the vendored cursor-prime rule files into .cursor/rules (alwaysApply
# frontmatter unchanged), copies slash commands into .cursor/commands, layers
# overlay/cloud-mode.mdc, and merges a marked section into AGENTS.md.
# Does not edit upstream rule text, install Windows hooks, or change gitignore.
#
# Usage:
#   ./install.sh [--mode autonomous|plan-only|interactive] <target-repo>
#
# Errors: missing target, bad mode, broken AGENTS.md markers, symlink escape.
# Re-running is idempotent: identical files are left in place; changed managed
# files are backed up once under .cursor/cursor-prime-cloud-backups/<timestamp>/.
# Invariant: only paths recorded in .cursor/cursor-prime-cloud-manifest.json
# are owned by this install. Uninstall removes those and nothing else.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PY="$ROOT/scripts/project_io.py"

log() { printf '[cursor-prime-cloud] %s\n' "$1"; }
die() { printf '[cursor-prime-cloud] %s\n' "$1" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: install.sh [--mode autonomous|plan-only|interactive] <target-repo>

Install cursor-prime rules into a project repo for cloud/headless agents.
Default mode is autonomous (plan, record it, continue). See README.md.
EOF
}

MODE="autonomous"
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      [[ $# -ge 2 ]] || die "Missing value for --mode"
      MODE="$2"
      shift 2
      ;;
    --mode=*)
      MODE="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      [[ -z "$TARGET" ]] || die "Unexpected extra argument: $1"
      TARGET="$1"
      shift
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  [[ -z "$TARGET" ]] || die "Unexpected extra argument: $1"
  TARGET="$1"
  shift
  [[ $# -eq 0 ]] || die "Unexpected extra argument: $1"
fi

case "$MODE" in
  autonomous|plan-only|interactive) ;;
  *) die "Mode must be autonomous, plan-only, or interactive (got: ${MODE})" ;;
esac

[[ -n "$TARGET" ]] || { usage >&2; die "Target repo path is required."; }
[[ -d "$TARGET" ]] || die "Target is not a directory: $TARGET"
command -v python3 >/dev/null 2>&1 || die "python3 is required."

TARGET=$(cd "$TARGET" && pwd)
[[ "$TARGET" != "$ROOT" ]] || die "Refusing to install into the cursor-prime-cloud package repo."

if [[ -L "$TARGET/.cursor" ]]; then
  die "Refusing to follow a symlinked .cursor directory."
fi
if [[ -L "$TARGET/AGENTS.md" ]]; then
  die "Refusing to follow a symlinked AGENTS.md."
fi
if [[ -d "$TARGET/AGENTS.md" ]]; then
  die "AGENTS.md is a directory; refusing to replace it."
fi

lock_get() {
  local key="$1"
  local value
  value=$(sed -n "s/^${key}=//p" "$ROOT/UPSTREAM.lock" | head -n 1)
  [[ -n "$value" ]] || die "UPSTREAM.lock is missing ${key}. Run scripts/sync-upstream.sh --latest."
  printf '%s' "$value"
}

[[ -f "$ROOT/UPSTREAM.lock" ]] || die "Missing $ROOT/UPSTREAM.lock. Run scripts/sync-upstream.sh --latest."
[[ -f "$ROOT/VERSION" ]] || die "Missing $ROOT/VERSION."

PKG_VER=$(tr -d '[:space:]' < "$ROOT/VERSION")
UP_REPO=$(lock_get repo)
UP_COMMIT=$(lock_get commit)
UP_VER=$(lock_get version)

BEHAVIOR="$ROOT/vendor/cursor-prime/payload/behavior.mdc"
MAINT="$ROOT/vendor/cursor-prime/payload/maintainability.mdc"
OVERLAY="$ROOT/overlay/cloud-mode.mdc"
CMD_DIR="$ROOT/vendor/cursor-prime/payload/commands"

[[ -f "$BEHAVIOR" && -f "$MAINT" && -f "$OVERLAY" && -d "$CMD_DIR" ]] || \
  die "Vendored payload is incomplete. Run scripts/sync-upstream.sh."

shopt -s nullglob
COMMANDS=("$CMD_DIR"/*.md)
shopt -u nullglob
[[ ${#COMMANDS[@]} -gt 0 ]] || die "No slash commands in $CMD_DIR."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

MANIFEST="$TARGET/.cursor/cursor-prime-cloud-manifest.json"
PREV=0
if [[ -f "$MANIFEST" ]]; then
  PREV=$(python3 "$PY" agents-flag --manifest "$MANIFEST")
fi

EXISTING_ARGS=()
if [[ -f "$TARGET/AGENTS.md" ]]; then
  EXISTING_ARGS=(--existing "$TARGET/AGENTS.md")
fi

CREATED_LINE=$(python3 "$PY" render-agents \
  "${EXISTING_ARGS[@]}" \
  --previously-created "$PREV" \
  --mode "$MODE" \
  --upstream-commit "$UP_COMMIT" \
  --upstream-version "$UP_VER" \
  --overlay "$OVERLAY" \
  --behavior "$BEHAVIOR" \
  --maintainability "$MAINT" \
  --out "$TMP/AGENTS.md")
CREATED="${CREATED_LINE#created=}"
[[ "$CREATED" == "0" || "$CREATED" == "1" ]] || die "render-agents returned: $CREATED_LINE"

printf '%s\n' "$MODE" > "$TMP/mode"

TSV="$TMP/files.tsv"
: > "$TSV"
UPDATED=0
UNCHANGED=0
BACKUP_REL=""

ensure_backup_root() {
  if [[ -n "$BACKUP_REL" ]]; then
    return
  fi
  local stamp base n=1
  stamp=$(date +%Y%m%d-%H%M%S)
  base=".cursor/cursor-prime-cloud-backups/${stamp}"
  while [[ -e "$TARGET/$base" ]]; do
    n=$((n + 1))
    base=".cursor/cursor-prime-cloud-backups/${stamp}-${n}"
  done
  BACKUP_REL="$base"
  mkdir -p "$TARGET/$BACKUP_REL"
}

copy_managed() {
  local src="$1" rel="$2" dst backup=""
  dst="$TARGET/$rel"
  if [[ -d "$dst" && ! -L "$dst" ]]; then
    die "Refusing to replace directory: $rel"
  fi
  if [[ -L "$dst" ]]; then
    die "Refusing to follow symlink: $rel"
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    log "Unchanged: $rel"
    UNCHANGED=$((UNCHANGED + 1))
  else
    if [[ -f "$dst" ]]; then
      ensure_backup_root
      backup="${BACKUP_REL}/$rel"
      mkdir -p "$(dirname "$TARGET/$backup")"
      cp -p "$dst" "$TARGET/$backup"
      log "Backed up: $rel -> $backup"
    fi
    cp "$src" "$dst"
    log "Installed: $rel"
    UPDATED=$((UPDATED + 1))
  fi
  printf '%s\t%s\n' "$rel" "$backup" >> "$TSV"
}

copy_managed "$BEHAVIOR" ".cursor/rules/behavior.mdc"
copy_managed "$MAINT" ".cursor/rules/maintainability.mdc"
copy_managed "$OVERLAY" ".cursor/rules/cloud-overlay.mdc"
copy_managed "$TMP/mode" ".cursor/cursor-prime-cloud-mode"

for cmd in "${COMMANDS[@]}"; do
  copy_managed "$cmd" ".cursor/commands/$(basename "$cmd")"
done

copy_managed "$TMP/AGENTS.md" "AGENTS.md"

python3 "$PY" merge-backups --target "$TARGET" --manifest "$MANIFEST" --files-tsv "$TSV"

if [[ -f "$MANIFEST" ]]; then
  python3 "$PY" prune-stale --target "$TARGET" --manifest "$MANIFEST" --keep-tsv "$TSV"
fi

python3 "$PY" write-manifest \
  --out "$MANIFEST" \
  --package-version "$PKG_VER" \
  --upstream-repo "$UP_REPO" \
  --upstream-commit "$UP_COMMIT" \
  --upstream-version "$UP_VER" \
  --mode "$MODE" \
  --agents-created "$CREATED" \
  --files-tsv "$TSV"

log "Mode: $MODE"
log "Updated: $UPDATED  Unchanged: $UNCHANGED"
if [[ -n "$BACKUP_REL" ]]; then
  log "Backups kept at ${BACKUP_REL}. Do not commit that directory."
fi
log "Done. ${TARGET}"
