#!/usr/bin/env bash
# End-to-end check for install.sh / uninstall.sh.
#
# Creates throwaway repos under a temp directory, installs, reinstalls, and
# uninstalls. Does not use the network and does not modify this package.
# Exit 0 only when every assertion holds.
#
# Usage: bash scripts/self-test.sh

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALL="$ROOT/install.sh"
UNINSTALL="$ROOT/uninstall.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS %s\n' "$1"; }

run() {
  printf '+ %s\n' "$*"
  "$@"
}

[[ -f "$ROOT/vendor/cursor-prime/payload/behavior.mdc" ]] || fail "vendor payload missing; run scripts/sync-upstream.sh"
[[ -f "$ROOT/overlay/cloud-mode.mdc" ]] || fail "overlay missing"

python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))' "$ROOT/scripts/project_io.py"
pass "project_io.py parses"

run bash "$INSTALL" --help >/dev/null
run bash "$UNINSTALL" --help >/dev/null
run bash "$ROOT/scripts/sync-upstream.sh" --help >/dev/null
pass "help exits 0"

if bash "$INSTALL" >/dev/null 2>&1; then fail "missing target should fail"; fi
if bash "$INSTALL" --mode nope "$TMP" >/dev/null 2>&1; then fail "bad mode should fail"; fi
if bash "$INSTALL" --mode >/dev/null 2>&1; then fail "missing mode value should fail"; fi
if bash "$INSTALL" "$ROOT" >/dev/null 2>&1; then fail "install into package root should fail"; fi
pass "usage errors are rejected"

# --- demo: existing AGENTS.md, custom rule, custom command ---
DEMO="$TMP/demo"
mkdir -p "$DEMO/.cursor/rules" "$DEMO/.cursor/commands"
printf '# Existing\n\nkeep me\n' > "$DEMO/AGENTS.md"
printf 'user rule\n' > "$DEMO/.cursor/rules/behavior.mdc"
printf 'custom rule\n' > "$DEMO/.cursor/rules/mine.mdc"
printf 'custom cmd\n' > "$DEMO/.cursor/commands/mine.md"
cp "$DEMO/AGENTS.md" "$TMP/agents-before.txt"
cp "$DEMO/.cursor/rules/behavior.mdc" "$TMP/behavior-before.txt"

printf '\n== install demo ==\n'
run bash "$INSTALL" "$DEMO"

printf '\n== tree after install ==\n'
(cd "$DEMO" && find . -type f | sort)

for rel in \
  .cursor/rules/behavior.mdc \
  .cursor/rules/maintainability.mdc \
  .cursor/rules/cloud-overlay.mdc \
  .cursor/cursor-prime-cloud-mode \
  .cursor/cursor-prime-cloud-manifest.json \
  .cursor/commands/plan.md \
  .cursor/commands/verify.md \
  .cursor/commands/loop.md \
  .cursor/commands/debug.md \
  .cursor/commands/grill.md \
  .cursor/commands/handoff.md \
  .cursor/commands/delta.md \
  .cursor/commands/submission-init.md \
  AGENTS.md
do
  [[ -f "$DEMO/$rel" ]] || fail "missing $rel"
done
pass "managed files exist"

cmp -s "$ROOT/vendor/cursor-prime/payload/behavior.mdc" "$DEMO/.cursor/rules/behavior.mdc" || fail "behavior.mdc was modified"
cmp -s "$ROOT/vendor/cursor-prime/payload/maintainability.mdc" "$DEMO/.cursor/rules/maintainability.mdc" || fail "maintainability.mdc was modified"
cmp -s "$ROOT/overlay/cloud-mode.mdc" "$DEMO/.cursor/rules/cloud-overlay.mdc" || fail "overlay was modified"
pass "rule bytes match upstream payload and overlay"

grep -q 'alwaysApply: true' "$DEMO/.cursor/rules/behavior.mdc" || fail "behavior frontmatter"
grep -q 'alwaysApply: true' "$DEMO/.cursor/rules/maintainability.mdc" || fail "maintainability frontmatter"
grep -q 'alwaysApply: true' "$DEMO/.cursor/rules/cloud-overlay.mdc" || fail "overlay frontmatter"
grep -q 'STOP and wait for the user to reply with the literal word `GO`' "$DEMO/.cursor/rules/behavior.mdc" || fail "upstream Plan Gate text missing"
grep -q 'this overlay wins' "$DEMO/.cursor/rules/cloud-overlay.mdc" || fail "overlay override missing"
grep -qx 'autonomous' "$DEMO/.cursor/cursor-prime-cloud-mode" || fail "mode file"
[[ "$(grep -c 'cursor-prime-cloud:begin' "$DEMO/AGENTS.md")" -eq 1 ]] || fail "marker not unique"
[[ "$(grep -c 'cursor-prime-cloud:end' "$DEMO/AGENTS.md")" -eq 1 ]] || fail "end marker not unique"
grep -q 'keep me' "$DEMO/AGENTS.md" || fail "existing AGENTS.md text dropped"
grep -q 'custom rule' "$DEMO/.cursor/rules/mine.mdc" || fail "custom rule clobbered during install"
pass "frontmatter, mode, and non-destructive merge"

python3 - "$DEMO/.cursor/cursor-prime-cloud-manifest.json" "$ROOT/UPSTREAM.lock" "$ROOT/VERSION" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1], encoding="utf-8"))
lock = {}
for line in open(sys.argv[2], encoding="utf-8"):
    if line.startswith("commit="):
        lock["commit"] = line.split("=", 1)[1].strip()
    if line.startswith("version="):
        lock["version"] = line.split("=", 1)[1].strip()
version = open(sys.argv[3], encoding="utf-8").read().strip()
assert manifest["name"] == "cursor-prime-cloud", manifest["name"]
assert manifest["package_version"] == version, manifest["package_version"]
assert manifest["mode"] == "autonomous"
assert manifest["agents_created"] is False
assert manifest["upstream"]["commit"] == lock["commit"]
assert manifest["upstream"]["version"] == lock["version"]
paths = [f["path"] for f in manifest["files"]]
assert "AGENTS.md" in paths
assert ".cursor/rules/behavior.mdc" in paths
assert ".cursor/rules/mine.mdc" not in paths
assert ".cursor/commands/mine.md" not in paths
backed = [f for f in manifest["files"] if f["path"] == ".cursor/rules/behavior.mdc"][0]
assert backed["backup"], "pre-existing behavior.mdc was not backed up"
PY
pass "manifest records upstream pin and skips foreign files"

cp "$DEMO/AGENTS.md" "$TMP/agents-after.txt"
backup_dirs=$(find "$DEMO/.cursor/cursor-prime-cloud-backups" -mindepth 1 -maxdepth 1 -type d | wc -l)
[[ "$backup_dirs" -eq 1 ]] || fail "expected one backup dir, got $backup_dirs"

printf '\n== reinstall demo (idempotent) ==\n'
relog=$(bash "$INSTALL" "$DEMO")
printf '%s\n' "$relog"
printf '%s\n' "$relog" | grep -q 'Updated: 0' || fail "reinstall changed files"
cmp -s "$TMP/agents-after.txt" "$DEMO/AGENTS.md" || fail "reinstall rewrote AGENTS.md"
backup_dirs=$(find "$DEMO/.cursor/cursor-prime-cloud-backups" -mindepth 1 -maxdepth 1 -type d | wc -l)
[[ "$backup_dirs" -eq 1 ]] || fail "reinstall created another backup dir"
pass "second install is a no-op"

# Plant a managed path from a previous package version and confirm reinstall removes it.
python3 - "$DEMO/.cursor/cursor-prime-cloud-manifest.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
data["files"].append({"path": ".cursor/commands/obsolete.md", "backup": None})
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY
printf 'obsolete\n' > "$DEMO/.cursor/commands/obsolete.md"
bash "$INSTALL" "$DEMO" >/dev/null
[[ ! -e "$DEMO/.cursor/commands/obsolete.md" ]] || fail "stale managed command was kept"
pass "reinstall removes stale managed files"

printf '\n== uninstall demo ==\n'
run bash "$UNINSTALL" "$DEMO"
[[ ! -e "$DEMO/.cursor/rules/behavior.mdc" ]] || fail "behavior.mdc remains"
[[ ! -e "$DEMO/.cursor/rules/cloud-overlay.mdc" ]] || fail "overlay remains"
[[ ! -e "$DEMO/.cursor/commands/plan.md" ]] || fail "plan.md remains"
[[ ! -e "$DEMO/.cursor/cursor-prime-cloud-manifest.json" ]] || fail "manifest remains"
[[ ! -e "$DEMO/.cursor/cursor-prime-cloud-mode" ]] || fail "mode file remains"
[[ -f "$DEMO/.cursor/rules/mine.mdc" ]] || fail "custom rule removed"
[[ -f "$DEMO/.cursor/commands/mine.md" ]] || fail "custom command removed"
grep -q 'keep me' "$DEMO/AGENTS.md" || fail "user AGENTS.md text lost on uninstall"
if grep -q 'cursor-prime-cloud:begin' "$DEMO/AGENTS.md"; then fail "marker left behind"; fi
[[ -d "$DEMO/.cursor/cursor-prime-cloud-backups" ]] || fail "backups were deleted"
run bash "$UNINSTALL" "$DEMO"
pass "uninstall is scoped and repeatable"

# --- restore backups ---
REST="$TMP/restore"
mkdir -p "$REST/.cursor/rules"
printf '# Title\n\nintro\n' > "$REST/AGENTS.md"
printf 'original behavior\n' > "$REST/.cursor/rules/behavior.mdc"
cp "$REST/AGENTS.md" "$TMP/restore-agents.txt"
cp "$REST/.cursor/rules/behavior.mdc" "$TMP/restore-behavior.txt"
bash "$INSTALL" "$REST" >/dev/null
bash "$INSTALL" "$REST" >/dev/null
run bash "$UNINSTALL" --restore-backups "$REST"
cmp -s "$TMP/restore-agents.txt" "$REST/AGENTS.md" || fail "AGENTS.md restore mismatch"
cmp -s "$TMP/restore-behavior.txt" "$REST/.cursor/rules/behavior.mdc" || fail "behavior restore mismatch"
[[ ! -e "$REST/.cursor/rules/maintainability.mdc" ]] || fail "created file survived restore uninstall"
pass "restore-backups returns overwritten files"

# --- created AGENTS.md is removed ---
CREATED="$TMP/created"
mkdir -p "$CREATED"
bash "$INSTALL" --mode plan-only "$CREATED" >/dev/null
grep -qx 'plan-only' "$CREATED/.cursor/cursor-prime-cloud-mode" || fail "plan-only mode"
grep -q 'Installed default mode: `plan-only`' "$CREATED/AGENTS.md" || fail "mode not in AGENTS.md"
python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); assert m["agents_created"] is True' \
  "$CREATED/.cursor/cursor-prime-cloud-manifest.json"
bash "$UNINSTALL" "$CREATED" >/dev/null
[[ ! -e "$CREATED/AGENTS.md" ]] || fail "created AGENTS.md was left behind"
[[ ! -e "$CREATED/.cursor/rules" ]] || fail "rules dir not empty after uninstall"
pass "plan-only install and created AGENTS.md removal"

# --- markers, symlink, spaced path ---
BROKEN="$TMP/broken"
mkdir -p "$BROKEN"
printf '<!-- cursor-prime-cloud:begin -->\nno end\n' > "$BROKEN/AGENTS.md"
if bash "$INSTALL" "$BROKEN" >/dev/null 2>&1; then fail "broken markers should fail"; fi
[[ ! -e "$BROKEN/.cursor" ]] || fail "broken markers still wrote .cursor"
pass "broken markers abort before writes"

LINK="$TMP/link"
mkdir -p "$LINK"
printf 'outside\n' > "$TMP/outside.md"
ln -s "$TMP/outside.md" "$LINK/AGENTS.md"
if bash "$INSTALL" "$LINK" >/dev/null 2>&1; then fail "symlink should fail"; fi
[[ ! -e "$LINK/.cursor" ]] || fail "symlink still wrote .cursor"
grep -qx 'outside' "$TMP/outside.md" || fail "symlink target was modified"
pass "symlinked AGENTS.md is refused"

SPACE="$TMP/space dir"
mkdir -p "$SPACE"
bash "$INSTALL" --mode interactive "$SPACE" >/dev/null
grep -qx 'interactive' "$SPACE/.cursor/cursor-prime-cloud-mode" || fail "interactive mode"
bash "$UNINSTALL" "$SPACE" >/dev/null
[[ ! -e "$SPACE/AGENTS.md" ]] || fail "space-dir AGENTS.md remains"
pass "paths with spaces and interactive mode"

# --- section sandwiched between user text ---
MID="$TMP/mid"
mkdir -p "$MID"
printf 'intro\n\n<!-- cursor-prime-cloud:begin -->\nold\n<!-- cursor-prime-cloud:end -->\n\noutro\n' > "$MID/AGENTS.md"
bash "$INSTALL" "$MID" >/dev/null
[[ "$(grep -c 'cursor-prime-cloud:begin' "$MID/AGENTS.md")" -eq 1 ]] || fail "duplicate section"
grep -q '^intro$' "$MID/AGENTS.md" || fail "intro dropped"
grep -q '^outro$' "$MID/AGENTS.md" || fail "outro dropped"
bash "$UNINSTALL" "$MID" >/dev/null
grep -q '^intro$' "$MID/AGENTS.md" || fail "intro lost"
grep -q '^outro$' "$MID/AGENTS.md" || fail "outro lost"
if grep -q 'cursor-prime-cloud:begin' "$MID/AGENTS.md"; then fail "section remains"; fi
pass "user text around the section is kept"

printf '\nSELF-TEST PASS\n'
