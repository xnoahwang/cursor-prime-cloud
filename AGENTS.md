# AGENTS.md

This file tells an AI agent how to install cursor-prime-cloud into a project repo, and how to refresh the vendored cursor-prime rules. The rule text itself lives in `vendor/cursor-prime/payload/`. Do not edit that tree by hand.

## Install cursor-prime-cloud into a project

When asked to install cursor-prime-cloud rules into a repo, do these steps and stop. This is the install procedure: run it, do not wait for a separate `GO`.

1. **Package checkout.** If the current directory is not this package (no `install.sh` and `UPSTREAM.lock` here), clone it and call that directory `PACKAGE`:

   ```bash
   git clone https://github.com/xnoahwang/cursor-prime-cloud.git
   ```

2. **Target.** `TARGET` is the project you were asked to install into. The directory must already exist. Do not pass the cursor-prime-cloud checkout as `TARGET`.

3. **Install.** Default mode is `autonomous` (write the plan, record it, continue).

   ```bash
   bash PACKAGE/install.sh --mode autonomous TARGET
   ```

   Use `--mode plan-only` only when the request says to stop after the plan. Use `--mode interactive` only when a human will type `GO`.

4. **Verify.** All of the following must succeed:

   ```bash
   test -f TARGET/.cursor/rules/behavior.mdc
   test -f TARGET/.cursor/rules/maintainability.mdc
   test -f TARGET/.cursor/rules/cloud-overlay.mdc
   grep -q 'alwaysApply: true' TARGET/.cursor/rules/cloud-overlay.mdc
   test -f TARGET/.cursor/commands/plan.md
   test -f TARGET/.cursor/cursor-prime-cloud-manifest.json
   test "$(grep -c 'cursor-prime-cloud:begin' TARGET/AGENTS.md)" = 1
   grep -qx autonomous TARGET/.cursor/cursor-prime-cloud-mode
   ```

   Change the last command if you passed a different `--mode`.

5. **Idempotent check.** Run the same `install.sh` command again. It must exit 0 and print `Updated: 0`.

6. **Persist.** If later cloud runs must see the rules, commit `.cursor/` and `AGENTS.md` in `TARGET`. Do not commit `.cursor/cursor-prime-cloud-backups/`.

7. **Report the mode.** `CURSOR_PRIME_CLOUD_MODE` (`autonomous`, `plan-only`, or `interactive`) overrides `.cursor/cursor-prime-cloud-mode` for one run. No reinstall is required to switch.

## Update rules from cursor-prime

From this package checkout:

```bash
bash scripts/sync-upstream.sh --latest
bash scripts/check-upstream.sh
bash scripts/self-test.sh
```

Review the diff. Commit `vendor/cursor-prime/` and `UPSTREAM.lock` when the diff is the upstream payload you expect. Rule substance is maintained only in [cursor-prime](https://github.com/xnoahwang/cursor-prime) `payload/`.

## Uninstall

```bash
bash PACKAGE/uninstall.sh TARGET
bash PACKAGE/uninstall.sh --restore-backups TARGET
```

Uninstall removes only paths listed in `.cursor/cursor-prime-cloud-manifest.json`, and strips the marked `AGENTS.md` section. `--restore-backups` copies install-time backups back first.

## Verify this package

```bash
bash scripts/self-test.sh
```

## Do not

- Do not edit `vendor/cursor-prime/payload/`.
- Do not keep a second hand-written copy of the cursor-prime rules.
- Do not add telemetry or network calls to `install.sh`.
