---
name: building-skills
description: Creates and edits project-level Claude Code skills under `.claude/skills/` and `.claude/commands/`. ALWAYS invoke this skill when the user asks to create, add, scaffold, refactor, or edit a skill, a slash command, a `SKILL.md`, or anything under `.claude/skills/` or `.claude/commands/`. Do not write `SKILL.md` or `.claude/commands/*.md` files directly — use this skill first.
---

# Building Skills

Authoring guide for project-level Claude Code **skills**. In Claude Code, custom slash commands and skills are the same primitive: a markdown file with YAML frontmatter that produces a `/name` entry. Two layout flavors exist for historical reasons:

- **Directory layout** — `.claude/skills/<name>/SKILL.md` (+ optional `references/`, `templates/`, `scripts/`).
- **Single-file layout** — `.claude/commands/<name>.md`. Legacy. Works identically; only difference is it can't bundle supporting files.

Files in `.claude/commands/` keep working but the docs recommend skills for new work. We'll call everything a "skill" in this guide and call out the single-file layout where it matters.

## Table of Contents

- [🚨 CRITICAL RULES (NEVER VIOLATE)](#-critical-rules-never-violate)
- [References & Templates](#references--templates)
- [The Two Axes](#the-two-axes)
- [Ask the User](#ask-the-user)
- [Progressive Disclosure (the Whole Point)](#progressive-disclosure-the-whole-point)
- [The Directive-Description Pattern](#the-directive-description-pattern)
- [Frontmatter Cheat Sheet](#frontmatter-cheat-sheet)
- [Workflow: Create](#workflow-create)
- [Workflow: Edit](#workflow-edit)
- [⚠️ Common Mistakes](#️-common-mistakes)
- [Maintaining this skill](#maintaining-this-skill)

## 🚨 CRITICAL RULES (NEVER VIOLATE)

1. **Auto-invoked skills follow the directive-description pattern** — short factual lead + `ALWAYS invoke this skill when …` + `Do not … — use this skill first.` Skills set to manual-only (`disable-model-invocation: true`) are exempt. See `references/description-pattern.md`.
2. **SKILL.md body stays under ~500 lines.** Push deep material into `references/<topic>.md`. Keep reference links **one level deep from SKILL.md** — Claude may only partially read nested references.
3. **Don't invent new top-level directories.** Skills live in `.claude/skills/<name>/`. Single-file skills live in `.claude/commands/<name>.md`. Skill-specific reference and template material lives inside the skill's own folder. Don't put skill-specific helper docs in `docs/` or `agent-rules/` unless the user asks. (Truly cross-cutting content shared by multiple skills is the exception — see [Progressive Disclosure](#progressive-disclosure-the-whole-point).)
4. **Ask, don't infer.** The two real decisions (layout and invocation mode — see [The Two Axes](#the-two-axes)) belong to the user. If the user's request is ambiguous on either axis, on the name, on scope, or on overwrite-vs-new, **stop and ask** with concrete options.

## References & Templates

Load on demand — don't paste their content into SKILL.md.

- `references/skill-anatomy.md` — full skill layout, frontmatter fields (every one), file roles (`references/`, `templates/`, `scripts/`), single-file layout differences, progressive-disclosure patterns, when to extract files.
- `references/description-pattern.md` — the directive-description pattern (slot anatomy + scoping procedure).
- `templates/skill-template.md` — fill-in scaffold for a new skill (works for both layouts).

## The Two Axes

A skill is defined by two independent choices, both made by the user:

### Axis 1 — Layout

| Layout | Path | When to use |
|---|---|---|
| Directory (recommended) | `.claude/skills/<name>/SKILL.md` | Needs supporting files: `references/`, `templates/`, `scripts/`. Default for non-trivial workflows. |
| Single-file (legacy) | `.claude/commands/<name>.md` | Self-contained workflow that fits in one file. No supporting files possible. |

Same fields apply to both. Same `$ARGUMENTS` substitution. Same `/name` invocation.

### Axis 2 — Invocation mode

| Mode | Frontmatter | Behavior |
|---|---|---|
| Both (default) | (omit `disable-model-invocation`) | User can type `/name`; Claude can also auto-invoke when the description matches the prompt. |
| User-only | `disable-model-invocation: true` | Only the user can fire it with `/name`. Description doesn't compete for routing. |
| Claude-only | `user-invocable: false` | Hidden from the `/` menu. Claude auto-invokes when relevant. Rare; used for background-knowledge skills. |

In this repo we've conventionally put user-only skills under `.claude/commands/` and both-mode skills under `.claude/skills/`, but **that's a convention, not a rule** — either layout supports either mode.

### What used to be a "slash command"

Files in `.claude/commands/` are just **single-file skills, almost always user-only**. The body is a self-contained inline workflow — Critical Rules → Workflow → Common Mistakes, same shape as a directory-layout skill minus the References section. Cap at ~150 lines; if it grows, promote to a directory-layout skill.

## Ask the User

The layout and invocation choices are **the user's, not the agent's**. If the user already specified them, use what they said. Otherwise, stop and ask. Always combine the layout and invocation question into a single message:

> Two quick questions before I scaffold this:
> 1. **Layout** — directory at `.claude/skills/<name>/` (recommended; lets us add references and templates) or single-file at `.claude/commands/<name>.md` (simpler, no supporting files)?
> 2. **Invocation** — should Claude be able to auto-invoke this when the description matches a prompt, or only fire it when you type `/<name>`?

Same rule applies to: name choice, scope, overwrite vs new, anything else that's not explicit.

## Progressive Disclosure (the Whole Point)

SKILL.md is a router, not a manual. The token budget is shared with the entire conversation.

Three patterns, ranked by how often we use them in this repo:

1. **High-level guide + references** — SKILL.md has critical rules, a short workflow, and links to `references/<topic>.md` for deep dives. Default.
2. **Domain-specific organization** — SKILL.md is a navigation page; each domain has its own reference file. Use when a skill spans clearly separable sub-topics.
3. **Conditional details** — basic content inline, advanced flows linked. Use when 80% of invocations only need the basics.

Rules of the road:

- SKILL.md body **≤ 500 lines**. If approaching that, split.
- **One level deep** from SKILL.md to references — never `SKILL.md → advanced.md → details.md`. Claude may partial-read the inner file.
- Reference files **> 100 lines** get a Table of Contents at the top.
- Templates (fill-in scaffolds) go in `templates/`, narrative material in `references/`.
- If a section is referenced by multiple skills, extract it into the relevant cross-cutting place (`docs/`, `agent-rules/`) — not into a skill's `references/`.

Single-file skills can't use progressive disclosure (no supporting files). That's the main reason to pick the directory layout the moment a skill needs reference material or templates.

See `references/skill-anatomy.md` for concrete layouts.

## The Directive-Description Pattern

For skills that Claude can auto-invoke, discovery is driven entirely by the `description` field. Standard shape:

```
<short factual lead>. ALWAYS invoke this skill when <trigger clauses>. Do not <forbidden direct action> — use this skill first.
```

Three slots, in order:

1. **Lead** — one sentence, third person, says what the skill does. ("Commits changes following project conventions.")
2. **Trigger clauses** — `ALWAYS invoke this skill when the user asks to …` followed by 3–6 concrete user-intent phrases. Use phrases users actually say, including the obvious synonyms.
3. **Negative constraint** — `Do not <thing the model would otherwise do directly> — use this skill first.` Names the exact tool call or output the skill replaces (`git commit`, `gh pr create`, `vt` CLI, writing a SKILL.md by hand).

Skip the negative-constraint clause only when there's no obvious direct action to replace (rare). **Skip the whole pattern for user-only skills** (`disable-model-invocation: true`) — their description doesn't drive routing, so a short factual sentence is enough.

For per-slot details and the overlap-detection procedure, see `references/description-pattern.md`.

## Frontmatter Cheat Sheet

Same fields apply to directory-layout and single-file skills. `description` is the only one that's universally recommended.

| Field | Notes |
|---|---|
| `name` | Display name. Defaults to directory name (or filename for single-file). Lowercase letters/digits/hyphens, ≤ 64 chars. |
| `description` | Drives auto-invocation. Apply the directive-description pattern unless `disable-model-invocation: true`. ≤ 1024 chars; truncated at 1,536 chars in the skill listing alongside `when_to_use`. |
| `argument-hint` | UI hint for `$ARGUMENTS`. Quote it if it contains brackets. |
| `model` | `haiku` / `sonnet` / `opus` / `inherit`. Override applies for the current turn. |
| `allowed-tools` | Pre-approves these tools while the skill is active. Space-separated string or YAML list. |
| `disable-model-invocation` | `true` ⇒ only the user can fire it with `/name`. |
| `user-invocable` | `false` ⇒ hidden from the `/` menu (Claude-only). |
| `context` / `agent` | Set `context: fork` to run in a subagent; `agent` picks the subagent type. |
| `paths` | Glob patterns that scope automatic activation to matching files. |

Full field-by-field walkthrough in `references/skill-anatomy.md`.

## Workflow: Create

Copy this checklist and check items off as you go.

```
Create:
- [ ] 1. Ask the user: layout (directory vs single-file), invocation mode, name
- [ ] 2. Clarify scope: triggers, direct action being replaced, overlap with existing skills
- [ ] 3. Draft the description (directive-description pattern, unless user-only)
- [ ] 4. Decide what goes in SKILL.md vs references vs templates
- [ ] 5. Scaffold from templates/skill-template.md (save at the chosen path)
- [ ] 6. Write critical rules + workflow + common mistakes
- [ ] 7. Extract reference files and templates as needed
- [ ] 8. Self-review
```

### 1. Ask the user

Don't infer. Combine the questions into one message:

- **Layout** — directory at `.claude/skills/<name>/` or single-file at `.claude/commands/<name>.md`? Pick directory unless the workflow is genuinely a one-file thing.
- **Invocation mode** — both (auto + `/name`), user-only (`disable-model-invocation: true`), or Claude-only (`user-invocable: false`)?
- **Name** — propose one if the user didn't, but confirm before creating files. Naming rules depend on the primitive — see `references/skill-anatomy.md` → "Naming Conventions".
- **Overwrite vs new** — if the target path already exists, surface that and ask.

### 2. Clarify scope

Enough to write the description and the workflow body:

- What user prompts should fire it? → trigger clauses.
- What direct action does it replace? → negative-constraint clause.
- Does it overlap with an existing skill? Cross-check `references/description-pattern.md` → "Scoping to Avoid Overlap" and **stop and ask** if there's a collision.

If anything is unclear, stop and ask. Don't paper over ambiguity with a guess.

### 3. Draft the description

Apply the [Directive-Description Pattern](#the-directive-description-pattern). For user-only skills, write a short factual sentence instead.

### 4. Decide what goes where

- **SKILL.md** — critical rules, decision matrix, short workflow, pointers.
- **`references/<topic>.md`** — long-form prose, full conventions, lookup tables, anti-pattern catalogs.
- **`templates/<name>-template.md`** — fill-in skeletons the skill instructs Claude to copy from.
- **`scripts/<name>.<ext>`** — only for deterministic operations worth scripting; rare here.

Single-file skills have only SKILL.md-equivalent — no `references/`, no `templates/`. If the workflow needs supporting files, switch to directory layout.

### 5. Scaffold

Copy `templates/skill-template.md` to the path matching the chosen layout:

- **Directory layout:** `.claude/skills/<name>/SKILL.md`.
- **Single-file layout:** `.claude/commands/<name>.md`, then delete the References section (single-file skills have nothing to reference).

The template only includes `name` and `description`. Add other frontmatter fields (`argument-hint`, `model`, `allowed-tools`, `disable-model-invocation`, etc.) only if needed — see `references/skill-anatomy.md` → "Frontmatter Reference" for the full list with usage notes.

### 6. Write the body

Required sections, in order:

1. **🚨 Critical Rules** — write now.
2. **References** — write now (skip for single-file layout).
3. **Workflow / core content** — write now.
4. **⚠️ Common Mistakes** — header only; leave the table empty. Rows are added later, as real failures surface — don't invent antipatterns up front.

### 7. Extract references and templates

If a section grows past ~80 lines or stops being routinely needed, extract it. Cross-link with relative paths — never absolute.

### 8. Self-review

```
Self-review:
- [ ] Name matches directory / filename; gerund for skills, imperative or alias for commands
- [ ] Description follows the directive-description pattern (or skill has disable-model-invocation: true)
- [ ] SKILL.md ≤ 500 lines
- [ ] All reference links are one level deep
- [ ] Reference files > 100 lines have a TOC
- [ ] No nested references (refs don't point to other refs)
- [ ] No AI-attribution / time-sensitive wording
- [ ] Critical rules are concrete and enforceable
- [ ] Common Mistakes section is present but EMPTY at scaffold time (entries get added later from real failures, not invented)
```

## Workflow: Edit

1. **Read first.** Use `Read` on the SKILL.md (and any references being touched).
2. **Locate the change.** Rule update, description tweak, new reference, workflow rewrite?
3. **Use `Edit`** for surgical changes, `Write` only for full file rewrites.
4. **Re-check the description** if behavior or scope shifted — the directive-description pattern may need new trigger clauses.
5. **Re-check link depth** if you added a reference — never introduce a second hop.

### 8. Self-review

Run the same checklist as Create — see [step 8 above](#8-self-review).

## ⚠️ Common Mistakes

| Issue | Solution |
|---|---|
| Agent picked layout or invocation mode without asking | Stop. Present both choices to the user per [Ask the User](#ask-the-user). |
| Treating skills and slash commands as different things | They're the same primitive. Difference is layout (directory vs single-file) and `disable-model-invocation`. |
| Description is a single short sentence on an auto-invocable skill | Apply the directive-description pattern. The router relies on it. |
| Trigger clause is so broad it overlaps another skill | Scope clauses to the action that belongs here. See `references/description-pattern.md` → "Scoping to Avoid Overlap". |
| SKILL.md keeps growing | Extract sections into `references/<topic>.md`. Stay ≤ 500 lines. |
| Reference file points to another reference file | Flatten. All refs link from SKILL.md directly. |
| Long reference with no TOC | Add a Table of Contents to any reference > 100 lines. |
| Skill named with noun phrase (`foo-management`) or command named in gerund form (`doing-thing`) | Rename: gerund + category prefix for skills (e.g. `managing-foo`, `developing-foo`), imperative verb-led for commands (`do-thing`). |
| Name contains vendor word as branding (`claude-helper`, `anthropic-utils`) | Rename. The validator forbids `claude` / `anthropic` as branding. Object-of-management mentions are fine when the skill genuinely manages those things (e.g. `managing-<vendor>-config` where the vendor name is the thing being configured). |
| Single-file skill in `.claude/commands/` that should be user-only is missing `disable-model-invocation: true` | Add the field — otherwise its description competes for auto-routing. |
| Single-file skill grew past ~150 lines | Promote to directory layout — move the body into a new `.claude/skills/<name>/SKILL.md` and delete the single-file entry. |
| Skill scaffolded without `templates/`, then copy-pasted boilerplate every invocation | Put the scaffold in `templates/<thing>-template.md` and have SKILL.md tell Claude to read it. |
| Common Mistakes table filled with invented antipatterns at scaffold time | Leave the section empty at creation. Add rows only when a real failure happens — a misfire, a user correction, a reviewer catch. Speculative entries dilute the real ones. |

---

## Maintaining this skill

Specific to `building-skills` itself, not part of the general authoring guidance above.

When you edit this skill, append an entry to `CHANGELOG.md` (gitignored, local memory of the skill's evolution). Each bullet:

- **What** changed.
- **Why** — the reason or trigger.
- **Reference** if one exists: URL, doc section, PR, or a quoted user request.

The "what" is in git; the "why" is the changelog's only value.
