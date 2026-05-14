# Skill Anatomy

Concrete layout of a project-level skill. Covers both the directory layout (`.claude/skills/<name>/SKILL.md`) and the single-file layout (`.claude/commands/<name>.md`). Same primitive, two file shapes.

## Table of Contents

- [The Two Layouts](#the-two-layouts)
- [Frontmatter Reference](#frontmatter-reference)
- [Body Conventions](#body-conventions)
- [The `references/` Directory](#the-references-directory)
- [The `templates/` Directory](#the-templates-directory)
- [The `scripts/` Directory (rare)](#the-scripts-directory-rare)
- [Single-File Layout — Body Shape](#single-file-layout--body-shape)
- [Invocation Mode (`disable-model-invocation`, `user-invocable`)](#invocation-mode-disable-model-invocation-user-invocable)
- [`$ARGUMENTS` and `argument-hint`](#arguments-and-argument-hint)
- [Calling Another Skill From a Skill](#calling-another-skill-from-a-skill)
- [Progressive Disclosure Patterns](#progressive-disclosure-patterns)
- [Naming Conventions](#naming-conventions)
- [Token Budget Rules of Thumb](#token-budget-rules-of-thumb)

## The Two Layouts

### Directory layout (preferred)

```
.claude/skills/<skill-name>/
└── SKILL.md
```

Or, typical:

```
.claude/skills/<skill-name>/
├── SKILL.md
├── references/
│   ├── <topic-a>.md
│   └── <topic-b>.md
└── templates/
    └── <thing>-template.md
```

The directory name **must equal** the `name:` field (or `name:` may be omitted — it defaults to the directory name). Use when the skill needs any supporting files.

### Single-file layout (legacy)

```
.claude/commands/<skill-name>.md
```

Filename (without `.md`) is the skill name. Identical fields and `$ARGUMENTS` semantics as the directory layout. Can't bundle supporting files — no `references/`, no `templates/`, no `scripts/`. The moment the workflow needs supporting material, switch to the directory layout.

## Frontmatter Reference

Same fields apply to both layouts. Only `description` is universally recommended; everything else is optional.

```yaml
---
name: <skill-name>                    # optional, defaults to dir/filename. Lowercase letters/digits/hyphens, ≤ 64 chars.
description: >                        # recommended. Drives auto-invocation. ≤ 1024 chars; cap of 1,536 chars in skill listing with `when_to_use`.
  One-sentence factual lead. ALWAYS invoke this skill when the user asks to
  X, Y, or Z. Do not <forbidden direct action> — use this skill first.
when_to_use: "Extra trigger phrases"  # optional, appended to description in the listing.
argument-hint: "[optional-arg]"       # optional, UI hint. Quote it if it contains brackets.
model: haiku                          # optional: haiku | sonnet | opus | inherit. Applies for the current turn.
effort: medium                        # optional: low | medium | high | xhigh | max.
allowed-tools: ["Bash(git *)"]        # optional, pre-approves these tools while skill is active.
disable-model-invocation: false       # optional. true ⇒ only the user can fire it via /name.
user-invocable: true                  # optional. false ⇒ hidden from the / menu (Claude-only).
context: fork                         # optional. fork ⇒ run in a subagent context.
agent: Explore                        # optional, with context: fork. Subagent type to use.
paths: ["**/*.md"]                    # optional. Globs that scope automatic activation.
shell: bash                           # optional: bash (default) | powershell.
hooks: {}                             # optional. Lifecycle hooks scoped to this skill.
arguments: [issue, branch]            # optional. Named positional arguments for $name substitution.
---
```

| Field | Notes |
|---|---|
| `name` | Display name. Defaults to directory name (directory layout) or filename without `.md` (single-file). Constraints: lowercase letters/digits/hyphens, ≤ 64 chars, no XML tags. Avoid vendor branding (`anthropic`, `claude`) inside the name. |
| `description` | Drives auto-invocation. Apply the directive-description pattern unless `disable-model-invocation: true`. Combined with `when_to_use`, truncated at 1,536 chars in the skill listing — put the key use case first. |
| `when_to_use` | Extra trigger phrases / example requests appended to `description` in the listing. |
| `argument-hint` | UI autocomplete hint for `$ARGUMENTS`. Quote it if it contains brackets (`"[from-tag]..[to-tag]"`) — unquoted YAML treats `[…]` as a list. |
| `arguments` | Names for positional arguments, used by `$name` substitution. Order-sensitive. |
| `model` | Pin a model when the skill is deterministic and cheap (`haiku`) or needs reasoning (`sonnet`). Override is one-turn; resumes on next prompt. |
| `effort` | Effort level override for the active model. |
| `allowed-tools` | Pre-approves these tools — doesn't restrict the broader tool set. Common shapes: `Bash(git *)`, `Bash(gh *)`, `["Bash", "Read", "Skill"]`. |
| `disable-model-invocation` | `true` ⇒ only the user invokes via `/name`. Description is **not** loaded into Claude's listing. |
| `user-invocable` | `false` ⇒ hidden from `/` menu; only Claude can invoke. Use for background-knowledge skills. |
| `context` | `fork` ⇒ run in an isolated subagent context; skill body becomes the subagent prompt. |
| `agent` | Subagent type for `context: fork`. Defaults to `general-purpose`. |
| `paths` | Globs that limit auto-activation to matching files. |
| `shell` | `powershell` opt-in for Windows inline `` !`…` `` blocks (requires `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`). |
| `hooks` | Lifecycle hooks scoped to this skill. |

## Body Conventions

Standard top-level sections, in order:

1. `# <Skill Title>` — human title, sentence case.
2. Optional one-liner describing the skill.
3. `## Table of Contents` — present in every skill > ~80 lines.
4. `## 🚨 CRITICAL RULES (NEVER VIOLATE)` — numbered, concrete, enforceable. Each rule names a real failure mode.
5. `## References` (or similar) — pointers to `references/` and `templates/`. Skip for single-file layout (nothing to reference).
6. Core content — the actual workflow / conventions / decision logic.
7. `## ⚠️ Common Mistakes` — table or list of antipatterns with fixes. Every skill has this section.

Style:

- Headers in sentence case, except acronyms (`PR`, `MCP`, `UI`).
- Use **bold lead-ins** for list items where the first phrase is the key.
- Tables for decision matrices and antipattern → fix pairs.
- Code fences with language hints (`swift`, `bash`, `yaml`).
- Backtick types, file paths, CLI flags, identifiers.
- No emoji except the `🚨` and `⚠️` section markers this codebase uses.

## The `references/` Directory

Directory layout only. Use for long-form material that doesn't need to be in the routing layer.

Extract into `references/<topic>.md` when:

- The section is > ~80 lines.
- It's only needed in a subset of invocations (advanced flow, lookup table, anti-pattern catalog).
- It's referenced by multiple sections inside SKILL.md.

Rules:

- **One level deep only.** A reference must not link to another reference for its real content. Cross-references between siblings are fine for navigation, but full content must be reachable directly from SKILL.md.
- **TOC required for files > 100 lines.** Claude may partial-read; the TOC ensures the full scope is visible.
- **Self-contained.** A reader should not need to re-open SKILL.md to follow it.

## The `templates/` Directory

Directory layout only. Use for **literal fill-in scaffolds** Claude should copy and edit, not paraphrase.

Conventions:

- Filename ends in `-template.md` (e.g. `<thing>-template.md`) — keeps markdown tooling working while making the role obvious.
- Use placeholders like `<feature-name>` or `{{description}}` — consistent within a file.
- Add a one-line comment at the top explaining what the template produces.

Example in this skill: `templates/skill-template.md`.

## The `scripts/` Directory (rare)

Directory layout only. Only add scripts when a step is fragile, deterministic, and repeated (validation, parsing, packing). Most workflows in this repo don't need them. If you add one:

- Forward slashes only in paths.
- Self-document non-obvious constants.
- Handle errors explicitly — don't punt to Claude.
- Document invocation in SKILL.md with the exact command (use `${CLAUDE_SKILL_DIR}/scripts/foo.py` to make the path resolve regardless of cwd).

## Single-File Layout — Body Shape

For skills at `.claude/commands/<name>.md`. Body is a self-contained inline workflow using the same shape as a directory-layout skill (Critical Rules → Workflow → Common Mistakes), minus the References section. Scaffold from `templates/skill-template.md` and delete the References section.

Cap at ~150 lines. If it grows, promote to the directory layout — move the body into a new `.claude/skills/<name>/SKILL.md` and delete the single-file entry.

## Invocation Mode (`disable-model-invocation`, `user-invocable`)

Two independent toggles, independent of layout.

| State | Frontmatter | User types `/name` | Claude auto-invokes | When loaded into context |
|---|---|---|---|---|
| Both (default) | (omit both) | Yes | Yes | Description always in context; full skill loads on invoke |
| User-only | `disable-model-invocation: true` | Yes | No | Description **not** in context; full skill loads when user invokes |
| Claude-only | `user-invocable: false` | No | Yes | Description always in context; full skill loads on invoke |

In this repo we've conventionally placed user-only skills under `.claude/commands/` and both-mode skills under `.claude/skills/`. That's a convention, not a rule — either layout supports either mode.

If a skill has side effects or unwanted timing implications (deploys, posts to Slack, sends messages), make it user-only. If it's background knowledge the user shouldn't see in the `/` menu, make it Claude-only.

## `$ARGUMENTS` and `argument-hint`

- `$ARGUMENTS` expands to everything the user typed after `/name`. If the skill content doesn't include `$ARGUMENTS`, the harness appends `ARGUMENTS: <value>` so Claude still sees it.
- `$ARGUMENTS[N]` or `$N` accesses positional arguments. Wrap multi-word values in quotes: `/skill "hello world" second` → `$0 = "hello world"`, `$1 = "second"`.
- `arguments: [name1, name2]` lets you reference args by name (`$name1` instead of `$0`). Order-sensitive.
- `argument-hint` is a UI autocomplete hint, not a parser. Quote it if it contains brackets/angle brackets.
- Guard against missing arguments inside the body — don't assume `$ARGUMENTS` is non-empty.

## Calling Another Skill From a Skill

When the body says "Invoke the `<other-skill>` skill", Claude calls the `Skill` tool. Requirements:

1. `"Skill"` must be in `allowed-tools` (or `allowed-tools` must be omitted so the broad default applies).
2. The target skill must exist and be discoverable.

## Progressive Disclosure Patterns

Three patterns. Pick one — don't mix. Available to directory-layout skills only.

### Pattern 1 — High-level guide with references (default)

SKILL.md has the critical rules, a numbered workflow, and links into `references/` for deep dives. Best for most management workflows.

### Pattern 2 — Domain-specific organization

SKILL.md is a navigation page. Each domain has its own reference file, listed in a table or bullet list. Best when a skill spans clearly separable sub-topics.

### Pattern 3 — Conditional details

Inline the common 80% case in SKILL.md. Link to advanced/edge-case material in references. Best when most invocations don't need the deep flow.

## Naming Conventions

Shared rules for both primitives: lowercase letters, digits, hyphens. ≤ 64 chars. No `claude` / `anthropic` as branding — a vendor word is only allowed when it literally names the thing the skill acts on.

| Primitive | Pattern | Examples | Anti-examples |
|---|---|---|---|
| Skill | `<gerund>-<object>` | `building-skills`, `managing-prs` | `skills-builder`, `prs-management` |
| Command | `<verb>-<object>` or short alias | `do-thing`, `gh`, `pr` | `doing-thing`, `skill-management` |

**Skills** use a gerund (verb + -ing) because the name describes what the skill does, not what the user types. **Commands** use an imperative verb or a short alias optimised for typing speed.

## Token Budget Rules of Thumb

- **Pre-loaded at startup:** `name` + `description` from every both-mode and Claude-only skill. User-only (`disable-model-invocation: true`) skills are **not** pre-loaded. This is the only context cost until a skill activates → keep descriptions tight.
- **Loaded when skill activates:** the entire SKILL.md body. → stay ≤ 500 lines.
- **Loaded on demand:** any file Claude explicitly reads (`references/`, `templates/`). → no startup cost, but each Read still consumes tokens, so split content along usage boundaries.
- **Auto-compaction:** invoked skills are kept across compactions within a 25,000-token budget (first 5,000 tokens of each, most recent first). Older skills can be dropped — re-invoke if they stop influencing behavior.
- If a paragraph would teach Claude something it already knows, delete it.
