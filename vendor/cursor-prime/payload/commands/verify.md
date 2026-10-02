# Verify Against Plan

Audit the work just completed (or in progress) against the active plan and pre-flight file list. Be adversarial — surface drift, not a clean bill of health.

Do NOT make new edits unless the user asks you to fix findings.

## Prerequisites

If there is no plan or pre-flight file list in this conversation, say so and stop:
> No plan to verify against. Run `/plan` or complete Plan Gate first.

## Checklist

1. **Pre-flight compliance** — list every file created, modified, deleted, or read in full. Flag any file outside the pre-flight list.
2. **Out of scope** — list any work that matches "Out of scope" from the plan.
3. **Done when** — PASS or FAIL against the stated stop condition; if FAIL, what remains.
4. **Hard verifier** — were verify commands actually **run** with transcript in Verify Receipt? FAIL if only claimed or self-graded.
5. **Surgical** — adjacent code, comments, or formatting touched without request? (New-file headers/docs required by maintainability do not count as surgical violations.)
6. **Protected paths** — if `@project` defines protected paths, were any edited without being on the pre-flight list?
7. **Maintainability** — for plan tier C/D (or any new public API / new module): public API docs present; new module headers present; `AGENTS.md` / `README.md` / `@project` updated if entry points or conventions changed; greenfield conventions written down. Tier A/B: N/A unless docs were made wrong.
8. **Step / spec compliance** — if the plan has a **Task breakdown**, for each step claimed done: was it finished, and did work stay inside that step’s paths/scope? FAIL on skipped steps presented as done, or drive-by edits outside the current/claimed steps.
9. **Shared language** — if root `CONTEXT.md` exists: do names/terms in the change obviously fight the glossary? N/A if absent.

## Output

```
Verify Report
- Pre-flight: PASS | FAIL — <files outside list, if any>
- Out of scope: PASS | FAIL — <items, if any>
- Done when: PASS | FAIL — <what remains, if FAIL>
- Hard verifier: PASS | FAIL — <missing transcript or self-grade only, if FAIL>
- Surgical: PASS | FAIL — <issues, if any>
- Protected paths: PASS | N/A | FAIL — <issues, if any>
- Maintainability: PASS | N/A | FAIL — <missing docs/headers/entry updates, if FAIL>
- Step / spec compliance: PASS | N/A | FAIL — <skipped or drifted steps, if FAIL>
- Shared language: PASS | N/A | FAIL — <glossary clashes, if FAIL>
```

Then one sentence: proceed to Delta, fix findings first, send `/loop` to iterate (if hard gate exists and under max iterations), send `/handoff` to raise the bar to tier D, or re-plan.
