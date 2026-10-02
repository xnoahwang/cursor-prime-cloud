# Plan Gate

Treat the request that follows (or the most recent request if none is given) as a non-trivial task and enter the Plan Gate.

**Non-trivial includes any file edit** — code, docs, README, markdown, config, or multi-line comment changes. Only read-only Q&A or a single-line typo in one known location is trivial.

Do NOT call Write, StrReplace, Delete, or any state-changing tool yet. Instead output a single `<plan>` block containing:

- **Goal** — the task restated as one verifiable outcome.
- **Design notes** — optional: `skipped` | `grilled: <one-line>` | short design-check summary. Use when the request was ambiguous, greenfield, workflow-scale, or after `/grill`.
- **Approach** — the minimal steps; no speculative abstractions.
- **Out of scope** — what you will explicitly NOT do (even if related or "nice to have"). Explicitly keep out: mandatory TDD-always, default multi-hour subagent runs, per-task git worktrees, issue-tracker triage / wayfinder suites, and vendoring whole third-party skill packs unless the user asks.
- **Done when** — the verifiable stop condition; the task is incomplete until this is met. Must bind to executable verify command(s) when a hard gate exists (test, lint, build, typecheck). If the task adds new files or public APIs, also bind to the maintainability checklist in `maintainability.mdc` (tier C). If the user asked for handoff-quality delivery or ran `/handoff`, use tier D.
- **Max iterations** — default `8` for fix-and-retry loops after `GO`; lower if the task is small or credit-sensitive.
- **Scale** — `trivial` | `single-context` | `workflow-scale` (if workflow-scale, include phased steps and note token/credit cost).
- **Task breakdown** — **required when Scale is `workflow-scale`**: ordered list of small steps; each step lists target paths and a verify / Done-when check. Optional for smaller scales when it helps.
- **Pre-flight file list** — every file you will create, modify, delete, or **read in full** (full paths). If you later need a file not listed here, STOP and explain. Include `AGENTS.md` / `README.md` / `@project` when greenfield or when conventions/entry points will change.
- **Pattern grounding** — before finalizing the plan, search the codebase for conventions to mirror (one example each with path): naming, error handling, test location/style. **If conventions exist**, mirror them and cite paths. **If none exist (greenfield)**, say so, then state the conventions you will establish and which file will record them (`AGENTS.md` and/or `@project`) — do not invent an undocumented one-off style.
- **Verify** — the exact command(s) you will run to prove PASS/FAIL (prefer commands from `@project` when defined). These are **hard gates** — run them before declaring done; no self-grade without a transcript.
- **Loop worthiness** — for `workflow-scale` only: PASS/FAIL on all four — (1) repeats weekly+, (2) hard gate exists, (3) agent end-to-end, (4) done is objective. If any FAIL, do not propose iterate-until-green unless the user later sends `/loop`.
- **Edge cases** — empty/missing, malformed, and large-scale input behavior for any new function, CLI, or endpoint (one line each).
- **Maintainability tier** — `A` | `B` | `C` | `D` per `maintainability.mdc` (default C when creating new surfaces).

Then STOP and wait for the user to reply with the literal word `GO`. Do not proceed without it.
