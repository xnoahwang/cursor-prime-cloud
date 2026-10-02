#!/usr/bin/env python3
"""Project-file helpers for the cursor-prime-cloud installer.

Owns AGENTS.md marker merges, the install manifest, and uninstall.
Does not decide which upstream rules to install and does not fetch the network.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

BEGIN = "<!-- cursor-prime-cloud:begin -->"
END = "<!-- cursor-prime-cloud:end -->"
MANIFEST_REL = ".cursor/cursor-prime-cloud-manifest.json"
HEADER = "# AGENTS.md"


def log(message: str) -> None:
    print(f"[cursor-prime-cloud] {message}")


def fail(message: str) -> None:
    print(f"[cursor-prime-cloud] {message}", file=sys.stderr)
    raise SystemExit(1)


def safe_path(target: Path, rel: str) -> Path:
    """Resolve a manifest path that must stay inside the target repo.

    Rejects absolute paths and '..' so uninstall cannot delete outside the project.
    Does not follow a final symlink; intermediate symlinks that leave the target fail.
    """
    rel_path = Path(rel)
    if rel_path.is_absolute() or any(part == ".." for part in rel_path.parts):
        fail(f"Refusing unsafe path: {rel}")
    root = target.resolve()
    candidate = root.joinpath(*rel_path.parts)
    parent = candidate.parent
    if parent.exists():
        parent_resolved = parent.resolve()
        if parent_resolved != root and root not in parent_resolved.parents:
            fail(f"Refusing path outside target: {rel}")
    return candidate


def strip_frontmatter(text: str) -> str:
    """Drop a leading YAML frontmatter block. Rules text is what agents must follow."""
    if not text.startswith("---\n"):
        return text.lstrip("\n")
    end = text.find("\n---\n", 4)
    if end == -1:
        return text
    return text[end + len("\n---\n") :].lstrip("\n")


def read_text(path: Path) -> str:
    if not path.is_file():
        fail(f"Missing file: {path}")
    return path.read_text(encoding="utf-8")


def outside_section(text: str) -> str:
    """Return AGENTS.md content outside the managed markers."""
    if BEGIN not in text and END not in text:
        return text.strip()
    _require_one_pair(text)
    pre, rest = text.split(BEGIN, 1)
    _post_ignored, post = rest.split(END, 1)
    return (pre + post).strip()


def _require_one_pair(text: str) -> None:
    begin_count = text.count(BEGIN)
    end_count = text.count(END)
    if begin_count != 1 or end_count != 1 or text.find(BEGIN) > text.find(END):
        fail(
            "AGENTS.md has broken cursor-prime-cloud markers "
            f"({BEGIN} / {END}). Fix or remove them, then re-run install."
        )


def merge_agents(existing: str | None, body: str) -> str:
    """Insert or replace the managed section. Leave all other text in place."""
    if BEGIN in body or END in body:
        fail("Rule text contains cursor-prime-cloud markers; refusing to splice.")
    section = f"{BEGIN}\n{body.rstrip()}\n{END}\n"
    if existing is None:
        return f"{HEADER}\n\n{section}"
    if BEGIN not in existing and END not in existing:
        base = existing.rstrip("\n")
        if not base.strip():
            return f"{HEADER}\n\n{section}"
        return f"{base}\n\n{section}"
    _require_one_pair(existing)
    pre, rest = existing.split(BEGIN, 1)
    _old, post = rest.split(END, 1)
    post = post.lstrip("\n")
    pre = pre.rstrip("\n")
    if pre:
        return f"{pre}\n\n{section}{post}"
    return f"{section}{post}"


def build_body(
    mode: str,
    upstream_commit: str,
    upstream_version: str,
    overlay_text: str,
    behavior_text: str,
    maintainability_text: str,
) -> str:
    overlay = strip_frontmatter(overlay_text).rstrip()
    behavior = strip_frontmatter(behavior_text).rstrip()
    maintainability = strip_frontmatter(maintainability_text).rstrip()
    short = upstream_commit[:12]
    return f"""## cursor-prime-cloud

Follow these rules for every task in this repo. Rule text is [cursor-prime](https://github.com/xnoahwang/cursor-prime) v{upstream_version} (`{short}`) plus the cloud overlay. Where the overlay and the rules disagree about waiting for a human, the overlay wins.

Installed default mode: `{mode}`.
At runtime, `CURSOR_PRIME_CLOUD_MODE` (`autonomous`, `plan-only`, or `interactive`) overrides `.cursor/cursor-prime-cloud-mode`.

Do not edit this marked section by hand. Re-run cursor-prime-cloud `install.sh` to refresh it.

Slash commands from cursor-prime are in `.cursor/commands/` (`/plan`, `/verify`, `/loop`, `/debug`, `/grill`, `/handoff`, `/delta`, `/submission-init`).

### Cloud overlay

{overlay}

### Coding Behavior

{behavior}

### Maintainability

{maintainability}

### Reminder

Mode from `CURSOR_PRIME_CLOUD_MODE` or `.cursor/cursor-prime-cloud-mode` overrides any "stop and wait for GO" line above and in `/plan`. `autonomous` writes the plan, records it, and continues. `plan-only` writes the plan and stops. `interactive` waits for `GO`.
"""


def our_header_only(text: str) -> bool:
    return text.strip() in ("", HEADER)


def cmd_render_agents(args: argparse.Namespace) -> None:
    existing = None
    existed = args.existing is not None
    if existed:
        path = Path(args.existing)
        if path.is_symlink():
            fail(f"Refusing to follow symlinked AGENTS.md: {path}")
        if not path.is_file():
            fail(f"AGENTS.md path is not a file: {path}")
        existing = path.read_text(encoding="utf-8")
    body = build_body(
        mode=args.mode,
        upstream_commit=args.upstream_commit,
        upstream_version=args.upstream_version,
        overlay_text=read_text(Path(args.overlay)),
        behavior_text=read_text(Path(args.behavior)),
        maintainability_text=read_text(Path(args.maintainability)),
    )
    merged = merge_agents(existing, body)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(merged, encoding="utf-8")
    created = 0
    if not existed:
        created = 1
    elif existing is not None and not existing.strip():
        created = 1
    elif args.previously_created and existing is not None and our_header_only(outside_section(existing)):
        created = 1
    print(f"created={created}")


def _load_manifest(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"Manifest is not valid JSON: {path} ({exc})")
    if not isinstance(data, dict):
        fail(f"Manifest is not an object: {path}")
    if data.get("name") != "cursor-prime-cloud":
        fail("Refusing to touch a manifest whose name is not cursor-prime-cloud.")
    files = data.get("files")
    if not isinstance(files, list):
        fail("Manifest files field is missing.")
    return data


def cmd_write_manifest(args: argparse.Namespace) -> None:
    files = []
    tsv = Path(args.files_tsv).read_text(encoding="utf-8")
    for line in tsv.splitlines():
        if not line.strip():
            continue
        rel, sep, backup = line.partition("\t")
        if sep == "":
            fail(f"Bad files TSV line: {line}")
        if rel == "" or Path(rel).is_absolute() or ".." in Path(rel).parts:
            fail(f"Refusing unsafe manifest path: {rel}")
        backup_value = backup or None
        if backup_value is not None and (".." in Path(backup_value).parts or Path(backup_value).is_absolute()):
            fail(f"Refusing unsafe backup path: {backup_value}")
        files.append({"path": rel, "backup": backup_value})
    payload = {
        "name": "cursor-prime-cloud",
        "package_version": args.package_version,
        "upstream": {
            "repo": args.upstream_repo,
            "commit": args.upstream_commit,
            "version": args.upstream_version,
        },
        "mode": args.mode,
        "installed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "agents_created": args.agents_created == "1",
        "files": files,
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    log(f"Manifest: {out}")


def cmd_prune_stale(args: argparse.Namespace) -> None:
    manifest = Path(args.manifest)
    if not manifest.is_file():
        return
    target = Path(args.target)
    data = _load_manifest(manifest)
    keep: set[str] = set()
    for line in Path(args.keep_tsv).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        rel, _sep, _backup = line.partition("\t")
        keep.add(rel)
    for entry in data["files"]:
        rel = entry.get("path")
        if not isinstance(rel, str) or rel in keep:
            continue
        path = safe_path(target, rel)
        if path.is_symlink() or (path.exists() and not path.is_dir()):
            path.unlink()
            log(f"Removed stale: {rel}")
        elif path.is_dir():
            fail(f"Refusing to delete directory listed in an old manifest: {rel}")


def _remove_file(path: Path, rel: str) -> None:
    if path.is_symlink() or (path.is_file() and not path.is_dir()):
        path.unlink()
        log(f"Removed: {rel}")
    elif path.exists():
        fail(f"Refusing to delete non-file: {rel}")


def _handle_agents(target: Path, entry: dict | None, agents_created: bool, restore: bool) -> None:
    rel = "AGENTS.md"
    path = safe_path(target, rel)
    backup_rel = entry.get("backup") if entry else None
    if path.is_symlink():
        fail("Refusing to follow symlinked AGENTS.md during uninstall.")
    if restore and backup_rel:
        backup = safe_path(target, backup_rel)
        if backup.is_file():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(backup.read_bytes())
            log(f"Restored: {rel} (from {backup_rel})")
            return
        log(f"Backup missing: {backup_rel}")
    if not path.is_file():
        if backup_rel and not restore:
            log(f"Backup kept: {backup_rel}")
        return
    text = path.read_text(encoding="utf-8")
    if BEGIN not in text and END not in text:
        if agents_created and our_header_only(text):
            path.unlink()
            log(f"Removed: {rel}")
        return
    _require_one_pair(text)
    pre, rest = text.split(BEGIN, 1)
    _old, post = rest.split(END, 1)
    post = post.lstrip("\n")
    pre = pre.rstrip("\n")
    if pre and post:
        remainder = f"{pre}\n\n{post}"
    elif pre:
        remainder = pre + "\n"
    else:
        remainder = post
    if agents_created and our_header_only(remainder):
        path.unlink()
        log(f"Removed: {rel}")
    else:
        if remainder and not remainder.endswith("\n"):
            remainder += "\n"
        path.write_text(remainder, encoding="utf-8")
        log(f"Stripped cursor-prime-cloud section: {rel}")
    if backup_rel:
        log(f"Backup kept: {backup_rel}")


def _rmdir_if_empty(path: Path) -> None:
    if path.is_dir() and not any(path.iterdir()):
        path.rmdir()


def cmd_uninstall(args: argparse.Namespace) -> None:
    target = Path(args.target).resolve()
    if not target.is_dir():
        fail(f"Target is not a directory: {target}")
    manifest_path = safe_path(target, MANIFEST_REL)
    if not manifest_path.is_file():
        log(f"Not installed (no manifest at {manifest_path}).")
        return
    data = _load_manifest(manifest_path)
    agents_entry = None
    for entry in data["files"]:
        rel = entry.get("path")
        if not isinstance(rel, str):
            fail("Manifest file entry is missing a path.")
        if rel == "AGENTS.md":
            agents_entry = entry
            continue
        path = safe_path(target, rel)
        backup_rel = entry.get("backup")
        if args.restore_backups and backup_rel:
            backup = safe_path(target, backup_rel)
            if backup.is_file() and not backup.is_symlink():
                if path.is_dir() and not path.is_symlink():
                    fail(f"Refusing to restore over directory: {rel}")
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(backup.read_bytes())
                log(f"Restored: {rel} (from {backup_rel})")
            else:
                log(f"Backup missing: {backup_rel}")
                _remove_file(path, rel)
        else:
            _remove_file(path, rel)
            if backup_rel:
                log(f"Backup kept: {backup_rel}")
    _handle_agents(target, agents_entry, bool(data.get("agents_created")), args.restore_backups)
    manifest_path.unlink()
    log(f"Removed: {MANIFEST_REL}")
    cursor = target / ".cursor"
    _rmdir_if_empty(cursor / "rules")
    _rmdir_if_empty(cursor / "commands")
    log("Uninstalled.")


def previously_created(manifest: Path) -> int:
    if not manifest.is_file():
        return 0
    try:
        data = json.loads(manifest.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"Manifest is not valid JSON: {manifest} ({exc})")
    if isinstance(data, dict) and data.get("name") == "cursor-prime-cloud" and data.get("agents_created"):
        return 1
    return 0


def cmd_merge_backups(args: argparse.Namespace) -> None:
    """Keep prior backup pointers when a reinstall does not change the file.

    A second identical install must not drop the original backup path, or
    --restore-backups can no longer undo the first install.
    """
    target = Path(args.target)
    old: dict[str, str] = {}
    manifest = Path(args.manifest)
    if manifest.is_file():
        data = _load_manifest(manifest)
        for entry in data["files"]:
            rel = entry.get("path")
            backup = entry.get("backup")
            if isinstance(rel, str) and isinstance(backup, str) and backup:
                backup_path = safe_path(target, backup)
                if backup_path.is_file() and not backup_path.is_symlink():
                    old[rel] = backup
    lines: list[str] = []
    for line in Path(args.files_tsv).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        rel, sep, backup = line.partition("\t")
        if sep == "":
            fail(f"Bad files TSV line: {line}")
        if not backup and rel in old:
            backup = old[rel]
        lines.append(f"{rel}\t{backup}")
    Path(args.files_tsv).write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def cmd_agents_flag(args: argparse.Namespace) -> None:
    """Print 1 if the previous manifest says this install created AGENTS.md."""
    print(previously_created(Path(args.manifest)))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="cursor-prime-cloud project file helper")
    sub = parser.add_subparsers(dest="cmd", required=True)

    render = sub.add_parser("render-agents")
    render.add_argument("--existing")
    render.add_argument("--previously-created", type=int, default=0)
    render.add_argument("--mode", required=True)
    render.add_argument("--upstream-commit", required=True)
    render.add_argument("--upstream-version", required=True)
    render.add_argument("--overlay", required=True)
    render.add_argument("--behavior", required=True)
    render.add_argument("--maintainability", required=True)
    render.add_argument("--out", required=True)
    render.set_defaults(func=cmd_render_agents)

    write = sub.add_parser("write-manifest")
    write.add_argument("--out", required=True)
    write.add_argument("--package-version", required=True)
    write.add_argument("--upstream-repo", required=True)
    write.add_argument("--upstream-commit", required=True)
    write.add_argument("--upstream-version", required=True)
    write.add_argument("--mode", required=True)
    write.add_argument("--agents-created", required=True, choices=("0", "1"))
    write.add_argument("--files-tsv", required=True)
    write.set_defaults(func=cmd_write_manifest)

    merge = sub.add_parser("merge-backups")
    merge.add_argument("--target", required=True)
    merge.add_argument("--manifest", required=True)
    merge.add_argument("--files-tsv", required=True)
    merge.set_defaults(func=cmd_merge_backups)

    prune = sub.add_parser("prune-stale")
    prune.add_argument("--target", required=True)
    prune.add_argument("--manifest", required=True)
    prune.add_argument("--keep-tsv", required=True)
    prune.set_defaults(func=cmd_prune_stale)

    uninstall = sub.add_parser("uninstall")
    uninstall.add_argument("--target", required=True)
    uninstall.add_argument("--restore-backups", action="store_true")
    uninstall.set_defaults(func=cmd_uninstall)

    flag = sub.add_parser("agents-flag")
    flag.add_argument("--manifest", required=True)
    flag.set_defaults(func=cmd_agents_flag)
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
