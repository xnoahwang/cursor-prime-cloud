#!/usr/bin/env bash
# Copy cursor-prime payload/ into vendor/cursor-prime and pin the commit.
#
# The vendored tree is the single source of rule text for this package.
# Do not hand-edit vendor/cursor-prime/payload. Re-run this script instead.
#
# Usage:
#   scripts/sync-upstream.sh --latest          # cursor-prime default branch tip
#   scripts/sync-upstream.sh --ref <sha|name>  # one commit, tag, or branch
#   scripts/sync-upstream.sh                   # re-copy the commit in UPSTREAM.lock
#
# Overwrites vendor/cursor-prime/payload and LICENSE. Writes UPSTREAM.lock
# and vendor/cursor-prime/README.md. Does not install into a project.
# Requires git and network access to GitHub. No other network calls.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
UPSTREAM_REPO="https://github.com/xnoahwang/cursor-prime.git"

log() { printf '[cursor-prime-cloud] %s\n' "$1"; }
die() { printf '[cursor-prime-cloud] %s\n' "$1" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: scripts/sync-upstream.sh [--latest | --ref <sha-or-name>]

Refresh vendor/cursor-prime from github.com/xnoahwang/cursor-prime.
EOF
}

MODE=""
REF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --latest)
      [[ -z "$MODE" ]] || die "Use only one of --latest or --ref."
      MODE="latest"
      shift
      ;;
    --ref)
      [[ -z "$MODE" ]] || die "Use only one of --latest or --ref."
      [[ $# -ge 2 ]] || die "Missing value for --ref."
      MODE="ref"
      REF="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git is required."
export GIT_TERMINAL_PROMPT=0

if [[ -z "$MODE" ]]; then
  [[ -f "$ROOT/UPSTREAM.lock" ]] || die "No UPSTREAM.lock. Run with --latest."
  REF=$(sed -n 's/^commit=//p' "$ROOT/UPSTREAM.lock" | head -n 1)
  [[ -n "$REF" ]] || die "UPSTREAM.lock has no commit. Run with --latest."
  MODE="ref"
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git init -q "$TMP/src"
git -C "$TMP/src" remote add origin "$UPSTREAM_REPO"

if [[ "$MODE" == "latest" ]]; then
  git -C "$TMP/src" fetch --depth 1 origin HEAD
else
  git -C "$TMP/src" fetch --depth 1 origin "$REF"
fi
git -C "$TMP/src" checkout -q --detach FETCH_HEAD

COMMIT=$(git -C "$TMP/src" rev-parse HEAD)
VERSION=$(sed -n "s/^[[:space:]]*version[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" "$TMP/src/install.ps1" | head -n 1)
if [[ -z "$VERSION" ]]; then
  VERSION="unknown"
  log "Could not read version from install.ps1; recording version=unknown."
fi

[[ -d "$TMP/src/payload" ]] || die "Upstream checkout has no payload/."
[[ -f "$TMP/src/LICENSE" ]] || die "Upstream checkout has no LICENSE."

rm -rf "$ROOT/vendor/cursor-prime/payload"
mkdir -p "$ROOT/vendor/cursor-prime"
cp -a "$TMP/src/payload" "$ROOT/vendor/cursor-prime/payload"
cp -a "$TMP/src/LICENSE" "$ROOT/vendor/cursor-prime/LICENSE"

cat > "$ROOT/vendor/cursor-prime/README.md" <<EOF
# Vendored cursor-prime

Snapshot of [cursor-prime](https://github.com/xnoahwang/cursor-prime) \`payload/\` and \`LICENSE\`.
Written by \`scripts/sync-upstream.sh\`. Do not edit these files by hand.

- Commit: \`${COMMIT}\`
- Version: ${VERSION}
EOF

cat > "$ROOT/UPSTREAM.lock" <<EOF
# Pin for vendored cursor-prime payload. Written by scripts/sync-upstream.sh.
# Update with: bash scripts/sync-upstream.sh --latest
repo=${UPSTREAM_REPO}
commit=${COMMIT}
version=${VERSION}
EOF

log "Vendored cursor-prime ${VERSION} at ${COMMIT}"
