# Submission init

**Opt-in.** Global rules do **not** auto-create `submission/` anymore. Run this command (or explicitly ask for handover/reflection/appendix docs) when you want the trio.

Scaffold (or refresh) the **`submission/`** trio in the **current project** so Handover / Reflection / Appendix can grow with the work.

## Create if missing

1. Ensure directory `submission/` at the project root.
2. Copy from the local cursor-prime clone (do not invent a second structure):

```powershell
$Prime = "$env:USERPROFILE\cursor-prime"
# or e.g. C:\XW\cursor-prime if that is where the user cloned it
New-Item -ItemType Directory -Force submission | Out-Null
Copy-Item "$Prime\payload\submission\1. Handover.md" "submission\" -Force
Copy-Item "$Prime\payload\submission\2. Reflection.md" "submission\" -Force
Copy-Item "$Prime\payload\submission\3. Appendix.md" "submission\" -Force
```

If `$env:USERPROFILE\cursor-prime` is missing, ask where cursor-prime lives, or use `C:\XW\cursor-prime` when that path exists.

3. Confirm the three files exist and report created vs overwritten.

## After scaffold

- Fill/update in **English**; headings **Title Case**.
- Grow during the rest of this task while submission is enabled (Coding Behavior → Submission docs, opt-in).
- Prefer inline why-comments in code regardless; submission docs are extra when required.

## Note

Default day-to-day work uses **inline comments** only. This command is the explicit on-switch for the Handover / Reflection / Appendix templates.
