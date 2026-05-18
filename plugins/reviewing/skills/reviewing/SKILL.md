---
name: reviewing
description: Reviews a user-specified scope (a PR, a branch diff, the working tree, specific files, an entire directory, documents, etc.) and reports confidence-rated findings. ALWAYS invoke this skill when the user asks to review code, review a PR, review a diff, review a branch, review files, review a document, do a code review, or run a review. Do not start reviewing freehand — use this skill to clarify scope, load project-specific rules from `.claude/reviewing-instructions/`, and produce a filtered, scoped report.
---

# Reviewing

A general-purpose review skill. The user tells you **what** to review (the scope) and optionally **how** (extra instructions). You produce a confidence-rated finding list scoped to exactly what they asked for.

This skill replaces ad-hoc "please review this" responses with a predictable shape:

1. **Confirm scope** — exactly which lines / files / commits are in or out.
2. **Load extra instructions** — anything the project dropped under `.claude/reviewing-instructions/`.
3. **Review** — find issues, rate each one 0–100, drop low-confidence noise.
4. **Report** — one headered section, inline file:line references, never approve a partial scope.

## Table of Contents

- [🚨 CRITICAL RULES (NEVER VIOLATE)](#-critical-rules-never-violate)
- [References](#references)
- [Pinning the Scope](#pinning-the-scope)
- [Pluggable Instructions: `.claude/reviewing-instructions/`](#pluggable-instructions-claudereviewing-instructions)
- [Confidence Rubric](#confidence-rubric)
- [Workflow](#workflow)
- [Output Format](#output-format)
- [⚠️ Common Mistakes](#-common-mistakes)

## 🚨 CRITICAL RULES (NEVER VIOLATE)

1. **Scope is whatever the user said — nothing more.** If they said "review this PR", review the PR diff. If they said "review the auth module", review only files under that module. Do not expand into unrelated files because they look interesting.
2. **Never approve a partial scope.** Incremental reviews (e.g. new commits only, a single file out of a larger change) lack the full picture. End with "Not approving — partial scope" instead of a thumbs-up.
3. **Always load `.claude/reviewing-instructions/`** from the repo root if it exists. "Repo root" means the root of the user's current working repository — never this plugin's own repo. Every file in that directory is part of the review rubric. Treat them as project-authored rules with the same weight as this skill's defaults. If they conflict with this skill's defaults, project rules win.
4. **Filter by confidence.** Rate every finding 0–100 (see [Confidence Rubric](#confidence-rubric)) and drop anything below `< 65` by default (same threshold for code and documents). Reporting low-confidence noise trains the user to ignore the report.
5. **Ask, don't guess, about scope.** If the scope or confidence threshold is ambiguous, stop and ask. Do not guess that "review this" means "review HEAD" or "review the whole repo".

## References

Load on demand — don't paste their content here.

- `references/review-types.md` — focus lists and "do not comment on" lists for each review type (general code — security is included here, not split out — documents, custom). Read after the user picks the type.

## Pinning the Scope

Scope must be explicit before the review starts. If the user named a scope — a PR number, a diff range, paths, a directory — proceed. Project rules under `.claude/reviewing-instructions/` are auto-loaded if the folder exists; the review type follows from the scope's contents (see [Choosing a Review Type](#choosing-a-review-type)).

If scope is missing or ambiguous, ask one question:

> What should I review? (a PR number, a branch / diff range like `main..HEAD`, the working tree, specific files, a whole directory, or something else)

A path or list of paths passed as an argument (e.g. `/reviewing src/api/`) is an explicit scope — map it via the [Scope vocabulary](#scope-vocabulary) table and start.

### Scope vocabulary

| User says | What you review |
|---|---|
| "this PR" / "PR #123" | `gh pr diff <n>` — the PR's changed lines |
| "this branch" / "what I've been working on" | `git diff <base>...HEAD` against the merge base |
| "the new commits" / "what I just pushed" | The non-merge commits added since the last review point (ask for the range if unclear) |
| "this file" / a list of paths | The exact files named, full contents |
| "this directory" / "the auth module" | Every code file under that path |
| "everything" / "the whole repo" | Push back — that's almost never what they want. Ask for a tighter scope. |

## Pluggable Instructions: `.claude/reviewing-instructions/`

Project-specific review rules live under `.claude/reviewing-instructions/` at the repo root. Each file is a markdown document with rules, anti-patterns, or focus areas the project wants enforced.

**Discovery procedure:**

```
1. Check if .claude/reviewing-instructions/ exists at the repo root.
2. If it doesn't: proceed with just this skill's defaults.
3. If it does: list every *.md file in it recursively.
4. For each file, check for an `## Applies to` section containing a glob:
   - If present and no path in the current scope matches the glob, skip the file.
   - If absent, the file applies to every scope.
5. Read each remaining file fully before starting the review.
6. Treat each file's rules as part of the rubric — call them out by name in findings ("violates .claude/reviewing-instructions/api-layer.md rule 3").
```

**Convention for project authors** (mention this if the folder is empty or the user asks how to add rules):

- One file per concern, named for the concern: `swift-style.md`, `api-layer.md`, `security.md`, `naming.md`.
- Each file may also opt into a specific scope by adding `## Applies to` with a glob — e.g. `**/*.ts` or `src/api/**`. If a file's glob doesn't match anything in the current scope, skip it.

The skill does **not** create this folder. It only reads from it.

## Confidence Rubric

Rate every potential finding before reporting it:

| Score | Meaning |
|---|---|
| **0–25** | Likely false positive, pre-existing issue not introduced by this scope, or a misread of the code. **Drop.** |
| **26–50** | Minor nitpick — style preference, micro-optimization, taste. **Drop unless the user asked for nits.** |
| **51–64** | Borderline — under the default threshold. **Drop unless the user lowered the threshold.** |
| **65–75** | Valid but low-impact issue. Report. |
| **76–90** | Important issue requiring attention. Report. |
| **91–100** | Critical bug, security vulnerability, or explicit project-rule violation. Report and flag prominently. |

**Default threshold:**

- Drop anything `< 65` — same for code and document reviews.
- The user can override ("only critical issues" → 91+, "be picky" → 26+).

Do not include the score in the user-facing report unless they ask — it's an internal filter.

## Workflow

```
Review:
- [ ] 1. Pin the scope
- [ ] 2. Materialize the diff or file set for the scope
- [ ] 3. Load .claude/reviewing-instructions/ if present
- [ ] 4. Infer the review type from the scope's contents
- [ ] 5. Read each in-scope file or diff hunk
- [ ] 6. Generate findings; rate each 0–100
- [ ] 7. Filter by threshold; group by file
- [ ] 8. Emit the report (Output Format)
- [ ] 9. If scope is partial, append the no-approval note
```

### 1. Pin the scope

See [Pinning the Scope](#pinning-the-scope). Don't proceed until the scope is unambiguous.

### 2. Materialize the scope

| Scope | Command |
|---|---|
| GitHub PR | `gh pr diff <n>` (or `gh pr view <n> --json files`) |
| Branch vs. base | `git diff <base>...HEAD` |
| New commits since X | `git rev-list --no-merges X..HEAD` then `git diff` per commit |
| Working tree | `git diff` (unstaged) + `git diff --cached` (staged) |
| Specific files | Read them directly |
| Directory | List files then read each in-scope file |

For diff-based scopes, save the diff to a temp file if it's large; reference hunks by file:line, not by paraphrase.

### 3. Load project instructions

Per [Pluggable Instructions](#pluggable-instructions-claudereviewing-instructions). If the folder exists and is non-empty, run the discovery procedure (recursive listing, `## Applies to` glob filtering) and read every remaining file before generating any findings.

### 4. Infer the review type

Pick the type from the contents of the materialized scope, per [Choosing a Review Type](#choosing-a-review-type). Mixed scopes (code + prose) run both types; the report emits one section per type.

### 5. Read each in-scope file

For **code** reviews, the diff is usually enough context. Read full files only when the diff doesn't show enough surrounding code to judge the change.

For **document** reviews, always read the full file even if only a few lines changed — ambiguity and contradictions live in the whole document.

### 6. Generate findings

For each potential issue:

- Determine the focus area (load `references/review-types.md` if you need the focus list for the chosen type).
- Apply project rules from `.claude/reviewing-instructions/` — cite the file and rule when one matches.
- Rate 0–100 using the [Confidence Rubric](#confidence-rubric).

### 7. Filter and group

Drop everything below the threshold. Group remaining findings by file, ordered by severity within each file (91+ first).

### 8. Emit the report

Use [Output Format](#output-format) verbatim. One section, with the scope name in the header.

### 9. Partial-scope note

If the review covered only part of a logical change (e.g. new commits on a PR you didn't see from the start, one file out of a multi-file refactor), append:

> ⚠️ **Partial scope** — this review only covered <X>. Not approving; a full review is needed before merge.

## Output Format

Always emit exactly this structure. `{scope}` is a short label of what was reviewed ("PR #123", "branch `feat/auth`", "file `src/api/users.ts`", etc.). `{type}` is the review type label ("Code", "Document", or the custom label).

The report opens with an ASCII banner so the reader can spot the start of the review at a glance. Use the banner block below verbatim — do not redesign it per review. The fenced block below is for display only; emit the banner **unfenced** so the box characters render.

```
╔══════════════════════════════════════════════════════════════╗
║                  🔍  {type} REVIEW                            ║
║                  {scope}                                      ║
╚══════════════════════════════════════════════════════════════╝

**Reviewed:** <one-line description of exactly what was looked at>
**Project rules applied:** <comma-separated list of .claude/reviewing-instructions/* files used, or "none">

──────────────────────────────────────────────────────────────
 📋  FINDINGS
──────────────────────────────────────────────────────────────

#### 📄 `path/to/file.ext`
- 🔴 **L42** — <one-line problem statement>. <one-line fix or explanation>.
- 🟡 **L88–95** — <problem>. <fix>.

#### 📄 `path/to/other.ext`
- 🟢 **L7** — <problem>. <fix>.

──────────────────────────────────────────────────────────────
 📝  SUMMARY
──────────────────────────────────────────────────────────────

<2–4 sentences: overall impression, the most important issue, and what to do next.>
```

**Severity glyphs** (prepend to each finding bullet, derived from the internal confidence score — the score itself stays hidden):

| Glyph | Score band | Meaning |
|---|---|---|
| 🔴 | 91–100 | Critical — blocks merge / must fix |
| 🟠 | 76–90 | Important — should fix before merge |
| 🟡 | 65–75 | Worth addressing but non-blocking |
| 🟢 | n/a | Positive note (only when the user asked for them) |

**Rules for the body:**

- The banner is **64 columns wide** (top and bottom borders are `╔` + 62× `═` + `╗`). Each content line (`║ … ║`) must also be exactly 64 columns: after substituting `{type}` and `{scope}`, pad with trailing spaces so the right-hand `║` lands in column 64. Treat each emoji (🔍 etc.) as occupying 2 columns when computing padding. Truncate `{scope}` with `…` if it would overflow the inner width.
- One bullet per finding. No multi-paragraph essays.
- Always include the file path and line range. No "around line 50" hand-waving.
- If there are zero findings above threshold, replace the FINDINGS block body with a single line — `✅  None above threshold.` — and still write the SUMMARY block.
- Never include the confidence score unless the user asked for it. The severity glyph is the only visible signal.
- Never include AI / model attribution.

**If the scope is a PR and the user has authorized posting:** use `gh pr review` or `gh pr comment` with the same body. Default is to print the report in chat — only push to GitHub when explicitly told to.

## ⚠️ Common Mistakes

| Issue | Solution |
|---|---|
| Agent started reviewing without an explicit scope | Stop and ask the single scope question in [Pinning the Scope](#pinning-the-scope) before reading any files. |
| Report expanded beyond the scope the user asked for | Drop the out-of-scope findings. Stick to exactly what they named. |
| Reviewer approved a partial scope ("looks good!" on incremental commits) | Append the partial-scope note instead. A subset can't be approved. |
| `.claude/reviewing-instructions/` exists but was ignored | Re-do the review with those rules loaded. Cite each rule by filename in findings. |
| Findings include taste-level nits | Re-filter at `< 65`. Nits go in a separate bucket only if the user asked for them. |
| Confidence scores shown in the user-facing report | Strip them. They're for filtering, not for the reader. |
| Full files re-read when the diff was sufficient | For code reviews, read the diff first; only open the file if context is missing. |
| Document review only looked at the diff | Always read the full file for document reviews — ambiguities and contradictions span the whole document. |
