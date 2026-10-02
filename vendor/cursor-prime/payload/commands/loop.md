# Loop (fix until verify passes)

Run a **light loop** in this session: EXECUTE → VERIFY → ITERATE until the plan's hard gate passes or max iterations is reached.

Requires an active plan with verify command(s) and user `GO` already given. If not, say so and run `/plan` first.

Do NOT start unattended automation, cron, or overnight runs.

## Protocol

Read **Max iterations** from the plan (default **8**). Track current iteration in `progress.md` Loop State.

Each iteration:

1. **EXECUTE** — fix the **single highest-impact** failure from the last verify (smallest surgical change).
2. **VERIFY** — run **all** verify commands from the plan; paste full transcript per Verify Receipt.
3. **DECIDE** —
   - All PASS → print `LOOP DONE`, proceed to Delta Report.
   - Any FAIL and iteration < max → print `ITERATING (n/max)`, update Loop State, go to step 1.
   - Any FAIL and iteration ≥ max → print `LOOP CAP`, summarize changes, remaining failures, suggest re-plan or manual fix.

## Rules

- One failure per iteration unless the plan explicitly allows batch fixes.
- Do not expand pre-flight file list without STOP and explain.
- No soft self-grade (1–10 rubrics) as sole proof when a hard gate exists.
- Credit guard: context grows each pass — stay surgical.

## Loop worthiness

If the plan marked loop worthiness FAIL on any of the four checks, warn once before iterating unless the user explicitly sent `/loop`.
