# cursor-prime-cloud

Project-level install of [cursor-prime](https://github.com/xnoahwang/cursor-prime) for cloud and other headless coding agents.

cursor-prime is a local, Windows-only global Cursor settings package: Plan Gate, Karpathy-derived discipline, slash commands, and maintainability rules. It installs into the user profile. Cloud agents never see that profile. They only see files committed in the repo they were started on, and a Plan Gate that waits for a human to type `GO` stalls an autonomous run.

Use both:

| | cursor-prime | cursor-prime-cloud |
|---|---|---|
| Where it applies | Your machine, every project, after one User Rules paste | One git repo, after `install.sh` |
| Who it is for | Cursor desktop on Windows | Cloud agents, CI agents, and other headless agents on Linux |
| Rule text | `payload/` in cursor-prime | The same `payload/`, vendored here at a pinned commit |
| Plan Gate | Output `<plan>`, wait for `GO` | Same plan, plus a cloud overlay that records it and continues |

Rule substance stays in cursor-prime. This repo does not fork it.

## Why a vendored snapshot

Three ways to share one `payload/` were considered:

- A **git submodule** is empty when a clone forgets `--recurse-submodules`. An agent following `AGENTS.md` would then install nothing.
- A **download during every project install** needs network on the target repo and follows whatever cursor-prime `main` is that minute, so an unreviewed rule change can land mid-task.
- A **vendored copy plus a lock file** installs offline, the pin is a commit SHA, and an update is a diff you can read before committing.

This package uses the third. `scripts/sync-upstream.sh` copies `payload/` and `LICENSE` from cursor-prime into `vendor/cursor-prime/` and writes `UPSTREAM.lock`. The first pin is cursor-prime v0.3.3. After that, `UPSTREAM.lock` is the authority.

The cloud overlay (`overlay/cloud-mode.mdc`) is the only rule text that lives in this repo. It does not rewrite the upstream rules. It says what to do instead of waiting when no human is in the session.

## Requirements

- bash
- python3 (manifest and `AGENTS.md` merge)
- git, only for `scripts/sync-upstream.sh` and `scripts/check-upstream.sh`

The project installer itself does not use the network.

## Quick start

```bash
git clone https://github.com/xnoahwang/cursor-prime-cloud.git
cd cursor-prime-cloud
./install.sh --mode autonomous /path/to/your-project
```

Commit the resulting `.cursor/` and `AGENTS.md` in that project. The next cloud agent on that repo will see the rules. Do not commit `.cursor/cursor-prime-cloud-backups/`.

An agent can do this without you pasting the commands. Point it at [AGENTS.md](AGENTS.md) and name the target repo.

## What install writes

Inside the target repo:

| Path | Source |
|---|---|
| `.cursor/rules/behavior.mdc` | cursor-prime `payload/behavior.mdc` (bytes unchanged, `alwaysApply: true`) |
| `.cursor/rules/maintainability.mdc` | cursor-prime `payload/maintainability.mdc` |
| `.cursor/rules/cloud-overlay.mdc` | `overlay/cloud-mode.mdc` from this package |
| `.cursor/commands/*.md` | cursor-prime `payload/commands/` |
| `.cursor/cursor-prime-cloud-mode` | one word: `autonomous`, `plan-only`, or `interactive` |
| `.cursor/cursor-prime-cloud-manifest.json` | files this install owns, plus the upstream commit |
| `AGENTS.md` | marked section between `<!-- cursor-prime-cloud:begin -->` and `<!-- cursor-prime-cloud:end -->` |

Local cursor-prime pastes both rule files into Cursor User Rules and only best-effort-copies `behavior.mdc` into `~/.cursor/rules/`. Cloud agents have no User Rules paste, so both files are installed as project rules. The `AGENTS.md` section inlines the same text so agents that do not read `.cursor/rules` still see it.

Not installed into the target: the Windows hook, the global gitignore, and `submission/` templates. Those stay in the vendored payload for sync completeness. Submission docs stay opt-in, as in cursor-prime.

Re-running install refreshes managed files. Identical files are left alone. A managed file that changed is copied to `.cursor/cursor-prime-cloud-backups/<timestamp>/` before it is replaced. Files this package does not own (other rules, other commands, the rest of `AGENTS.md`) are not modified. A managed path that a newer install no longer ships is removed.

## Modes

Set the mode at install time, or override one run with the environment variable. The env var wins when it is set to one of the three names.

| Mode | How | Behavior |
|---|---|---|
| `autonomous` | default | Write the `<plan>`, put it in the PR `## Plan` section (or `PLAN.md` if there is no PR), then implement. Put the Verify Receipt and Delta Report in the PR `## Verify` section. |
| `plan-only` | `--mode plan-only` | Write that plan and stop. A later message that is exactly `GO`, or a switch to `autonomous`, means implement. |
| `interactive` | `--mode interactive` | Follow cursor-prime: wait for literal `GO` before edits. |

```bash
./install.sh --mode plan-only /path/to/your-project
CURSOR_PRIME_CLOUD_MODE=autonomous   # overrides the mode file for one run
```

Switching the mode file, or re-running `install.sh --mode ...`, does not require an upstream sync.

## Update

```bash
bash scripts/sync-upstream.sh --latest
bash scripts/check-upstream.sh
bash scripts/self-test.sh
```

`sync-upstream.sh --ref <commit-or-tag>` pins a specific revision. With no flag, the script re-copies the commit already in `UPSTREAM.lock`.

Review the diff, then commit `vendor/cursor-prime/` and `UPSTREAM.lock`. Do not hand-edit `vendor/cursor-prime/payload/`.

### Drift check

[`.github/workflows/upstream-drift.yml`](.github/workflows/upstream-drift.yml) does two jobs:

- On pull requests and pushes to `main`, **integrity**: the vendored tree must match the locked commit. A hand-edit fails the check.
- On a weekly schedule and on manual `workflow_dispatch`, **freshness**: the lock must also equal cursor-prime's default-branch tip. When it does not, the job fails and names `scripts/sync-upstream.sh --latest`.

The action does not commit upstream changes. Rule diffs should be reviewed before they land. That is the sync step; the action is the check.

## Uninstall

```bash
./uninstall.sh /path/to/your-project
./uninstall.sh --restore-backups /path/to/your-project
```

Uninstall deletes only manifest paths. It strips the marked `AGENTS.md` section, or deletes `AGENTS.md` when install created that file and nothing else was added. `--restore-backups` copies the install-time backups back over overwritten files. Backup directories are kept either way. Running uninstall when nothing is installed exits 0.

## Safety

- Install refuses to run against this package's own checkout, a symlinked `.cursor` or `AGENTS.md`, or broken section markers. Marker errors happen before any file is written.
- Uninstall refuses manifest paths that are absolute or contain `..`, and refuses a manifest whose name is not `cursor-prime-cloud`.
- Scripts are short. Read `install.sh`, `uninstall.sh`, and `scripts/project_io.py` before running them.
- No telemetry.

## Verify

```bash
bash scripts/self-test.sh
```

That creates a throwaway repo, installs, installs again, and uninstalls.

## Layout

```
install.sh / uninstall.sh
overlay/cloud-mode.mdc          # cloud Plan Gate only
vendor/cursor-prime/payload/    # cursor-prime snapshot; do not edit
UPSTREAM.lock
scripts/sync-upstream.sh
scripts/check-upstream.sh
scripts/self-test.sh
scripts/project_io.py           # manifest and AGENTS.md merge
```

## License

MIT. See [LICENSE](LICENSE).

The rule text under `vendor/cursor-prime/` is from [cursor-prime](https://github.com/xnoahwang/cursor-prime), also MIT, copyright cursor-prime contributors. See `vendor/cursor-prime/LICENSE`. This package does not change that license.
