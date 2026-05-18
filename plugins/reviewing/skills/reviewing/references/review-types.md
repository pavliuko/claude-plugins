# Review Types

Focus lists and exclusion lists for each review type. Pick one based on what the user asked for; combine with anything loaded from `.claude/reviewing-instructions/`.

## Table of Contents

- [General Code Review](#general-code-review)
- [Document Review](#document-review)
- [Custom Review](#custom-review)
- [Choosing a Type When the User Didn't](#choosing-a-type-when-the-user-didnt)

## General Code Review

The default for "review this PR / branch / file" when the content is source code. Security is part of this list — there is no separate "security review" type.

**Focus on:**

- **Bugs and logic errors** — off-by-one, wrong operator, inverted condition, unreachable branch, missed null/empty case.
- **Edge cases** — empty inputs, max/min values, concurrent access, retries, timeouts, network failures.
- **Concurrency / data races** — shared mutable state without synchronization, async/await misuse, deadlock risk, lost updates.
- **Resource management** — leaks (file handles, sockets, subscriptions, timers), unbounded growth, missing cleanup on error paths.
- **API misuse** — calling a function with wrong arguments, ignoring return values that signal failure, deprecated APIs.
- **Error handling** — swallowed errors, broad catches that hide bugs, error messages with no actionable information, retry loops with no backoff.
- **Performance footguns** — N+1 queries, accidentally quadratic loops, blocking calls on the hot path. Only flag when the impact is real, not theoretical.
- **Security** — injection (SQL / command / template / log), broken auth & IDOR, secrets in code/logs/URLs, weak or home-rolled crypto, missing input validation, unsafe deserialization, path traversal, session/token issues, XSS / CSRF / SSRF, TOCTOU around auth, PII leakage to telemetry.
- **Explicit project-rule violations** — anything cited by `.claude/reviewing-instructions/*.md`.

**Do NOT comment on:**

- Missing comments or docstrings (unless a `.claude/reviewing-instructions/` rule requires them).
- Test coverage as such — flag a *specific* untested risky branch instead of "needs more tests".
- Style preferences not encoded in a project rule (naming, spacing, brace placement).
- Refactoring opportunities that don't fix a bug or violation.
- Pre-existing code that wasn't touched by the scope.
- Generic "could be more secure" suggestions without a concrete attack; defense-in-depth ideas when the primary defense is correct (mention in Summary, not as findings).

## Document Review

Use when the scope is prose rather than code — READMEs, design docs, RFCs, specs, contributing guides, runbooks, any `.md` file under `docs/`, or any other document.

**Read the full file**, not just the diff. Ambiguities and contradictions span the whole document.

If the user tells you the intended audience (human-only, automation-only, mixed), apply it. Otherwise default to mixed — flag anything that would confuse either readership.

**Focus on:**

- **Ambiguous or vague instructions** a reader could plausibly misinterpret ("be careful with X" — careful how?).
- **Contradictions** within the same file or across related documents. Quote both sides.
- **Gaps** that would cause wrong behavior — missing edge cases, missing DO/DON'T pairs, unspecified fallback when a precondition fails.
- **Inconsistent terminology** — same concept named two ways without explanation. List both names.
- **Broken references** — links to files / anchors / sections that don't exist, or to deleted/renamed targets.
- **Stale content** — claims that contradict the current codebase or behavior. Cite the code or behavior that contradicts them.
- **Over-prescription** — rules so narrow they'll force the wrong choice in the common case. Rare but high-impact when it happens.

**Do NOT comment on:**

- Writing style, grammar, or prose quality unless it causes ambiguity.
- Personal preference on Oxford commas, sentence length, heading capitalization.
- Missing sections that aren't actually needed for the document's purpose.

## Custom Review

When the user defines their own focus ("review for accessibility", "review for API consistency", "review for translation completeness"):

1. Restate the focus back to the user in one line and have them confirm before starting.
2. Use that focus as the only filter — nothing else.
3. Apply project rules from `.claude/reviewing-instructions/` that match the focus (by filename or `## Applies to` glob).
4. Keep the confidence rubric, threshold, and output format the same as the other types.

## Choosing a Type When the User Didn't

If the user didn't specify a type, infer from the scope's content **and confirm** before starting:

| Content of scope | Likely type |
|---|---|
| Source files (`.ts`, `.py`, `.swift`, `.go`, `.rs`, `.java`, `.kt`, `.rb`, `.cpp`, etc.) | General Code |
| Auth / crypto / payment / user-data code | General Code with security priority raised (see [General Code Review](#general-code-review)) |
| `docs/**`, `README.md`, other `.md` / prose files | Document Review |
| Mixed — code + documents | Run both; emit two sections, one per type |

Confirm in one sentence: "This looks like a code change — running general code review unless you want something else."

**When to wait for acknowledgement:**

- **Proceed without waiting** when the scope is unambiguously code (only source files) or unambiguously prose (only `.md` / `docs/**`).
- **Wait** when the scope is mixed (code + documents), when the user's wording was vague ("look at this"), or when the inferred type might surprise them (e.g. a `.md` file inside a source directory).
