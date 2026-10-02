# Systematic Debug

Treat the request that follows (or the active bug in this conversation) as a debugging task. Follow **Systematic debugging** from Coding Behavior. Do **not** make broad speculative edits first.

## Steps (in order)

1. **Reproduce** — state the exact failing command, input, or symptom. If you cannot reproduce, say what is missing and ask once — or proceed only with an explicit hypothesis labeled unverified.
2. **Minimise** — shrink the failing case when cheap (smaller input, single module/path).
3. **Hypothesize** — one primary root-cause hypothesis (optional secondary). Prefer the smallest explanation that fits the evidence.
4. **Instrument / evidence** — run or propose the smallest check that confirms or rejects the hypothesis (failing test, log line, narrow read). Paste command + output when you run something.
5. **Fix** — only after evidence supports the hypothesis (or the user explicitly says to try a fix anyway). Smallest change.
6. **Regression check** — re-run the failing verify / repro. If the repo already has tests, add or extend a focused regression when the bug could return.

## Plan Gate

If the fix needs non-trivial file edits, output a short `<plan>` (Goal / Approach / Pre-flight / Verify) and wait for literal `GO` before editing — unless an already approved plan in this session covers this fix.

## After the fix

- Verify Receipt with transcript.
- If still failing and under max iterations, offer `/loop` (one failure per pass).
- Delta Report when the debugging task is done.

## Do not

- Spray unrelated refactors while “debugging”.
- Declare fixed without re-running the failing case (or stating why it cannot be re-run).
