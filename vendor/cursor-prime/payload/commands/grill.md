# Grill (alignment)

Run a short **grilling** session on the request that follows (or the active design in this conversation). Goal: close the communication gap before coding — not to write code yet.

Inspired by composable “grill” practice; keep it light and under credit guard. Does **not** replace Plan Gate.

## Loop

1. Ask focused questions about open decisions (prefer one cluster at a time).
2. Challenge assumptions, edge cases, and “what done looks like.”
3. Stop when important forks are resolved, or the user says skip / enough.
4. Output a short alignment summary:
   - **Aligned** — bullets the human confirmed
   - **Open** — anything still unresolved (or `none`)
   - **Terms** — any new domain words worth remembering

## Then

- If implementation is next: output a normal `<plan>` with `Design notes: grilled: <one-line>` and wait for literal `GO`.
- If the user only wanted alignment: stop after the summary (no edits).
- Optional docs: if new terms matter and the user agrees (or the project already uses it), plan an update to root `CONTEXT.md` (glossary) — list it on the pre-flight file list. Do not create `CONTEXT.md` by default for assessment / one-off pads.

## Do not

- Turn every tiny typo fix into a grill.
- Mandatory TDD, issue-tracker triage, or multi-hour autonomy.
- Edit files during the grill itself unless the user already sent `GO` on a plan that includes `CONTEXT.md` / ADR notes.
