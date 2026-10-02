# Delta Report

Produce a **Delta Report** for the work just completed, then a 2–3 line summary. Be honest — the point is to surface drift, not to look clean.

If the user ran `/verify` in this session, incorporate its outcome (especially any FAIL items).

  Delta Report
  - Files changed: <path>  (+N / -M)   one line per file
  - Outside plan: ⚠️ <path> — <one-line reason>   (omit section if none)
  - Signatures changed: <old> → <new>              (omit section if none)
  - Symbols deleted: <name> — <one-line reason>    (omit section if none)
  - Verify: <command>  →  <pass/fail + key output>

Use real line counts from the diff and paste the actual verify command and its real output (or relevant tail). If everything matches the plan, a single line is fine: "Delta: matches plan; verify passed."
