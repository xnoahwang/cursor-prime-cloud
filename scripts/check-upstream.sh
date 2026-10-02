#!/usr/bin/env bash
# Check that vendor/cursor-prime still matches the pinned cursor-prime commit.
#
# Integrity (default): clone the locked commit and diff payload/ plus LICENSE.
# Fails if someone hand-edited the vendored rule text.
#
# --freshness: also fail when UPSTREAM.lock is not the default-branch tip.
# Use that on a schedule. Do not fail every pull request solely because
# upstream moved; review the diff via scripts/sync-upstream.sh --latest.
#
# Requires git and network. Does not modify the repo.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
EXPECTED_REPO="https://github.com/xnoahwang/cursor-prime"

log() { printf '[cursor-prime-cloud] %s\n' "$1"; }
die() { printf '[cursor-prime-cloud] %s\n' "$1" >&2; exit 1; }

FRESHNESS=0
if [[ "${1:-}" == "--freshness" ]]; then
  FRESHNESS=1
  shift
fi
if [[ $# -gt 0 ]]; then
  die "Unknown argument: $1"
fi

command -v git >/dev/null 2>&1 || die "git is required."
[[ -f "$ROOT/UPSTREAM.lock" ]] || die "Missing UPSTREAM.lock."

lock_get() {
  sed -n "s/^${1}=//p" "$ROOT/UPSTREAM.lock" | head -n 1
}

REPO=$(lock_get repo)
COMMIT=$(lock_get commit)
[[ -n "$REPO" && -n "$COMMIT" ]] || die "UPSTREAM.lock is missing repo or commit."

normalize() {
  local url="$1"
  url=${url%.git}
  printf '%s' "$url"
}

[[ "$(normalize "$REPO")" == "$EXPECTED_REPO" ]] || die "Refusing unexpected upstream repo: $REPO"
[[ -d "$ROOT/vendor/cursor-prime/payload" ]] || die "Missing vendor/cursor-prime/payload."
[[ -f "$ROOT/vendor/cursor-prime/LICENSE" ]] || die "Missing vendor/cursor-prime/LICENSE."

export GIT_TERMINAL_PROMPT=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git init -q "$TMP/src"
git -C "$TMP/src" remote add origin "${EXPECTED_REPO}.git"
git -C "$TMP/src" fetch --depth 1 origin "$COMMIT"
git -C "$TMP/src" checkout -q --detach FETCH_HEAD

if ! diff -rq "$TMP/src/payload" "$ROOT/vendor/cursor-prime/payload"; then
  die "Integrity failed: vendor/cursor-prime/payload does not match ${COMMIT}."
fi
if ! diff -q "$TMP/src/LICENSE" "$ROOT/vendor/cursor-prime/LICENSE"; then
  die "Integrity failed: vendor/cursor-prime/LICENSE does not match ${COMMIT}."
fi
log "Integrity: vendor matches ${COMMIT}."

if [[ "$FRESHNESS" -eq 1 ]]; then
  TIP=$(git ls-remote "${EXPECTED_REPO}.git" HEAD | awk '{print $1}')
  [[ -n "$TIP" ]] || die "Could not read cursor-prime HEAD."
  if [[ "$TIP" != "$COMMIT" ]]; then
    die "Freshness: lock ${COMMIT} is behind cursor-prime HEAD ${TIP}. Run: bash scripts/sync-upstream.sh --latest"
  fi
  log "Freshness: lock matches cursor-prime HEAD ${TIP}."
fi
