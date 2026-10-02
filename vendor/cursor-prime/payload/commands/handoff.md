# Handoff-ready deliverable

Treat the request that follows (or the most recent request if none is given) as a **tier D** maintainability task: ship code a successor (human or AI) can run, verify, and extend without you.

If there is no active plan yet, enter the Plan Gate first (same fields as `/plan`), then wait for `GO`. If a plan already exists and the user already sent `GO`, audit and finish against this checklist without re-planning unless scope must expand.

## Mandatory Done when (in addition to feature + hard verify)

The task is incomplete until all of the following are true:

1. **Runs** — stated run path works (or is documented as N/A with reason).
2. **Hard verify** — plan verify commands were **run** with transcript (test/lint/build/typecheck when they exist).
3. **Public APIs** — every new public function/class/CLI/endpoint has an idiomatic docstring covering why, inputs/outputs when non-obvious, and errors.
4. **Modules** — every new source file that owns a concern has a short file header (responsibility / non-responsibility).
5. **Layout** — matches `AGENTS.md` conventions; if greenfield, conventions were written into `AGENTS.md` in this task.
6. **Entry docs** — `README.md` and `AGENTS.md` describe how to run and verify; `@project` verify commands filled if the stack is known.
7. **No doc rot** — you did not leave stubs that contradict what you built.

## Delta extras

In the Delta Report, add one line:

- Maintainability: PASS | FAIL — <missing docstring / header / AGENTS / README / project.mdc item if FAIL>

## Intensity reminder

Do not demand a novel for a one-line fix. This command means the user wants **handoff quality** for the current deliverable — apply full checklist to surfaces touched or created for that deliverable.
