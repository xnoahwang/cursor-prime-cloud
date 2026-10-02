#!/usr/bin/env bash
# Uninstall cursor-prime-cloud from one target project.
#
# Reads .cursor/cursor-prime-cloud-manifest.json and removes only the files
# that install listed. Strips the marked AGENTS.md section, or deletes
# AGENTS.md when this install created it and nothing else is in the file.
# Backups under .cursor/cursor-prime-cloud-backups/ are kept.
#
# Usage:
#   ./uninstall.sh [--restore-backups] <target-repo>
#
# --restore-backups copies each install-time backup back over the managed path.
# Exit 0 when the manifest is already absent (safe to run twice).
# Refuses a manifest whose name is not cursor-prime-cloud, and refuses paths
# that leave the target directory.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

die() { printf '[cursor-prime-cloud] %s\n' "$1" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: uninstall.sh [--restore-backups] <target-repo>

Remove only the files recorded by install.sh. Does nothing if not installed.
EOF
}

RESTORE=0
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restore-backups)
      RESTORE=1
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
fi

[[ -n "$TARGET" ]] || { usage >&2; die "Target repo path is required."; }
[[ -d "$TARGET" ]] || die "Target is not a directory: $TARGET"
command -v python3 >/dev/null 2>&1 || die "python3 is required."

TARGET=$(cd "$TARGET" && pwd)

ARGS=(python3 "$ROOT/scripts/project_io.py" uninstall --target "$TARGET")
if [[ "$RESTORE" -eq 1 ]]; then
  ARGS+=(--restore-backups)
fi
"${ARGS[@]}"
